# 功能清单

`moon-pay-sdk` 当前已实现的全部能力，按支付平台和包划分。本文是「已实现」的
权威清单；文末的「尚未实现」一节列出明确排除在外的部分。

- **版本：** 0.10.0
- **目标平台：** MoonBit native（无 JavaScript 桥接、无解释器）
- **范围：** 服务端收单 —— 下单、查单、异步通知处理
- **配套指南：** [微信支付](wechat.zh-CN.md)、[支付宝](alipay.zh-CN.md)

## 包结构

| 包 | 职责 |
| --- | --- |
| `daqing/moon-pay-sdk` | 共享类型：`SdkError` / `ApiError`、JSON 辅助、金额与订单号校验 |
| `daqing/moon-pay-sdk/wechat` | 微信支付 API v3 客户端：Native / H5 / JSAPI 下单、查单、回调验签与解密、请求签名、平台证书/公钥管理 |
| `daqing/moon-pay-sdk/miniprogram` | 小程序服务端流程：`wx.login` code 换 openid，并与 JSAPI 下单组合为一步 |
| `daqing/moon-pay-sdk/alipay` | 支付宝 OpenAPI 客户端：电脑/手机网站支付地址、查单、异步通知与回跳验签、RSA2 请求签名 |
| `daqing/moon-pay-sdk/crypto` | RSA-SHA256 签名/验签、PEM 密钥加载、X.509 解析、AES-256-GCM 解密、安全随机数 |
| `daqing/moon-pay-sdk/transport` | 基于 `moonbitlang/async` HTTPS 的 `Transport` trait，以及可离线测试的 `MockTransport` |

## 微信支付（API v3）

| 能力 | 公开 API | 网关接口 | 实现文件 |
| --- | --- | --- | --- |
| Native 扫码下单 | `Client::native_order` | `POST /v3/pay/transactions/native` | `wechat/native.mbt` |
| H5 下单（移动端浏览器） | `Client::h5_order` | `POST /v3/pay/transactions/h5` | `wechat/h5.mbt` |
| JSAPI 下单（微信内） | `Client::jsapi_order` | `POST /v3/pay/transactions/jsapi` | `wechat/jsapi.mbt` |
| `wx.requestPayment` 参数集 | `Client::jsapi_pay_params` | 本地签名 | `wechat/jsapi.mbt` |
| 按商户订单号查单 | `Client::query_order` | `GET /v3/pay/transactions/out-trade-no/{no}?mchid=…` | `wechat/query.mbt` |
| 按微信交易号查单 | `Client::query_order_by_id` | `GET /v3/pay/transactions/id/{id}?mchid=…` | `wechat/query.mbt` |
| 回调验签 + 解密 + 解析 | `Client::verify_callback`、`Client::parse_notification` | 本地 | `wechat/callback.mbt`、`wechat/notification.mbt` |
| 单独回调验签 | `Client::verify_callback_signature` | 本地 | `wechat/callback_sig.mbt` |
| 请求签名 / `Authorization` 头 | `build_sign_message`、`sign_request`、`authorization_header` | 本地 | `wechat/auth.mbt` |
| 平台证书下载 / 解密 / 缓存 | `Client::refresh_platform_certs`、`Client::platform_public_key` | `GET /v3/certificates` | `wechat/certs.mbt` |
| 回调应答辅助 | `ack_success()`、`ack_failure(message~)` | 本地 | `wechat/ack.mbt` |

### 下单

三种下单方式都返回类型化结果，并共享同一条请求路径：

- **Native** 返回 `NativeOrder::code_url()` —— 渲染成二维码供用户扫码。
- **H5** 返回 `H5Order::h5_url()` —— 让移动端浏览器重定向过去。必须传
  `payer_client_ip`，请求体会带 `scene_info`（`scene_type="H5"`）。
- **JSAPI** 返回 `JsapiOrder::prepay_id()`。随后 `jsapi_pay_params` 生成
  `JsapiPayParams`：`app_id`、`timestamp`、`nonce_str`、`pay_package`
  （`prepay_id=…`）、`sign_type="RSA"`、`pay_sign`。

`paySign` 是商户私钥对四行规范串的 RSA-SHA256 签名：

```text
appId
timeStamp
nonceStr
package
```

末尾换行也属于被签名的内容。

金额统一为整数分（`total`）；订单号在发请求前完成本地校验。

### 查单

`OrderStatus` 包含 `out_trade_no`、`transaction_id`、`trade_state`、
`total_fen`、可选 `payer_fen` 和可选 `success_time`。

`TradeState` 覆盖全部已文档状态 —— `SUCCESS`、`REFUND`、`NOTPAY`、
`CLOSED`、`REVOKED`、`USERPAYING`、`PAYERROR` —— 另有 `Unknown(String)`
兜底，平台新增状态不会破坏已有版本。

### 回调处理

`verify_callback(headers, body)` 按顺序执行：

1. 大小写不敏感地提取 `Wechatpay-Serial`、`Wechatpay-Timestamp`、
   `Wechatpay-Nonce`、`Wechatpay-Signature`，四个都必须存在。
2. 时间戳防重放检查（默认 ±300 秒，可通过
   `verify_callback_signature(window_seconds=…)` 调整）。
3. 用序列号对应的平台公钥验证 `timestamp\nnonce\nbody\n` 的
   RSA-SHA256 签名。
4. 用 APIv3 密钥对 `resource` 做 AES-256-GCM 解密，`associated_data`
   作为 AAD。
5. 提取类型化 `Notification`：`event_type`、`summary`、`out_trade_no`、
   `transaction_id`、`trade_state`、`total_fen`、`payer_fen`，并通过
   `resource()` 保留完整解密 JSON。

处理成功用 `ack_success()`（HTTP 200，`{"code":"SUCCESS",…}`）；处理失败用
`ack_failure(message~)`（HTTP 500，`{"code":"FAIL",…}`），微信会按重试策略
重新投递。

### 验签密钥模式

`wechat.Config` 支持两种模式：

- **公钥模式** —— 设置 `platform_public_key_pem` 和
  `platform_public_key_id`（`PUB_KEY_ID_...`），运行时不下载任何东西。
  只设置其中一个会被 `Config::validate` 拒绝。
- **证书模式** —— 两者都留空。平台证书从 `/v3/certificates` 下载，用
  APIv3 密钥解密，并按小写序列号缓存；遇到未知 `Wechatpay-Serial` 会自动
  刷新一次。

成功的 API 响应默认会验签；构造 `Client::new` 时传
`verify_responses=false` 可关闭。证书下载接口本身始终跳过验签，因为用于
验签的密钥正来自该响应。

### 配置校验

`wechat.Config::validate` 会在任何网络调用之前拒绝：

- 空的 `appid`、`mchid`、`serial_no`、`private_key_pem`；
- 长度不是 32 的 `api_v3_key`；
- 既不是 `https://` 也不是 `http://` 的 `base_url`；
- 只设置 `platform_public_key_pem` 或 `platform_public_key_id` 其中一个；
- 无法解析的平台公钥 PEM；
- `appid`、`mchid`、`serial_no` 首尾带多余空白。

## 小程序（`miniprogram`）

| 能力 | API | 接口 / 行为 |
| --- | --- | --- |
| code 换 openid | `Client::code2session` | `GET /sns/jscode2session`，返回 `Session`（`openid`、`session_key`、可选 `unionid`） |
| 一步下单 | `Client::pay` | code → openid → JSAPI 下单 → 支付参数 |
| 已知 openid 下单 | `Client::pay_with_openid` | 跳过 code 换取 |
| 结果类型 | `PayResult` | `openid`、`out_trade_no`、`prepay_id`、`pay_params` |

`Client::new` 强制要求 `miniprogram.Config.app_id` 与支付客户端的 `appid`
一致 —— openid 只在签发它的 appid 下有效。登录 API 的业务 `errcode` 会转成
`SdkError::Api`；传输失败时不回传底层错误文本，因为请求 URL 里含 app secret。

## 支付宝（OpenAPI）

| 能力 | 公开 API | 接口 / 行为 | 实现文件 |
| --- | --- | --- | --- |
| 电脑网站支付 | `Client::page_pay_url` | `alipay.trade.page.pay`，`FAST_INSTANT_TRADE_PAY` | `alipay/pay.mbt` |
| 手机网站支付 | `Client::wap_pay_url` | `alipay.trade.wap.pay`，`QUICK_WAP_WAY` | `alipay/pay.mbt` |
| 查单 | `Client::query_order` | `alipay.trade.query`，表单 POST | `alipay/query.mbt` |
| 异步通知验签 | `Client::verify_notify` | 本地 RSA2 验签 + `app_id` 归属校验 | `alipay/notify.mbt` |
| 同步回跳验签 | `Client::verify_return_params` | 本地，复用同一套规范串规则 | `alipay/notify.mbt` |
| 金额核对 | `NotifyResult::amount_matches` | 本地 | `alipay/notify.mbt` |
| 通知应答辅助 | `ack_success()` → `"success"` | 本地 | `alipay/ack.mbt` |
| 参数 / 签名引擎 | `system_params`、`sign_params`、`sign_content`、`build_request_sign_content`、`build_sign_content` | 本地 | `alipay/params.mbt` |
| URL 编解码 / 表单解析 | `build_pay_url`、`percent_encode`、`percent_decode`、`parse_form_params` | 本地 | `alipay/url.mbt` |
| 北京时间格式化 | `format_beijing` | 本地 | `alipay/params.mbt` |

### 收银台链接

两个下单辅助函数都是**本地**行为 —— 下单时不请求网关，交易在用户浏览器
到达收银台时才创建。

- `page_pay_url(out_trade_no~, total_fen~, subject~, notify_url~, return_url~)`
  返回已签名的电脑网站收银台 URL，始终携带 `return_url`。
- `wap_pay_url(out_trade_no~, total_fen~, subject~, notify_url~)` 返回已签名
  的手机网站收银台 URL，不携带 `return_url`。

金额入参为整数分，落盘为两位小数的元字符串（`88.00`）。

### 查单

`OrderStatus` 包含 `out_trade_no`、`trade_no`、`trade_status`、
`total_amount`、`total_fen` 和可选 `send_pay_date`。

`TradeStatus` 覆盖 `WAIT_BUYER_PAY`、`TRADE_CLOSED`、`TRADE_SUCCESS`、
`TRADE_FINISHED`，另有 `Unknown(String)` 和 `is_unknown()`。

只有当 `alipay_trade_query_response` 成员**原文**通过支付宝公钥验签后，
响应字段才会被采信。错误响应与请求 charset 无关，固定为 GBK；SDK 做 lossy
解码，保证 ASCII 的 `code` / `sub_code` 可读。

### 异步通知与回跳

`verify_notify(form)`：

1. 对每个键和值做百分号解码。
2. 必须存在 `sign` 参数。
3. 对规范串（除 `sign` 与 `sign_type` 外的全部参数，按 key 排序后以
   `k=v&…` 拼接）做 RSA2 验签。
4. 要求 `app_id` 等于本客户端配置的 `app_id`。
5. 返回 `NotifyResult`：`trade_status`、`out_trade_no`、`trade_no`、
   `total_amount`、`total_fen`、`app_id`、可选 `seller_id`，以及解码后的
   原始参数。

标记订单已支付前必须调用 `amount_matches(expected_fen)` —— 签名只能证明
发送方是支付宝，不能证明这条通知属于当前订单。`verify_return_params(query)`
对 `return_url` 的 GET 参数执行相同的验签与归属检查。

### 签名规则

出站与入站使用不同的规范串，与生产网关行为一致：

- **出站请求：** 除 `sign` 外的全部参数排序拼接，**包含 `sign_type`**
  （`build_request_sign_content`，`sign_params` 使用它）。
- **入站通知 / 回跳：** 除 `sign` 和 `sign_type` 外的参数排序拼接
  （`build_sign_content`）。
- **同步响应：** 对 `alipay_xxx_response` 成员**原文**验签，绝不重新序列化
  （`Client::verify_content`）。

排序按 ASCII 字节序在本地实现，不使用「先比长度」的通用字符串比较。

仅支持**公钥模式**。SDK 没有 `app_cert_sn` / `alipay_root_sn` 字段，因此
公钥证书模式无法使用。

## 公共基础能力

| 领域 | 能力 |
| --- | --- |
| `crypto` | PEM 私钥/公钥加载、SPKI DER 解析、X.509 证书解析与序列号提取、RSA-SHA256 签名/验签、AES-256-GCM 解密、安全随机字节/十六进制 |
| `transport` | `Transport` trait；基于 `moonbitlang/async` HTTPS 的 `HttpClient`；记录请求并回放脚本响应的 `MockTransport` |
| 错误 | `SdkError`：`Api(ApiError)`、`Network(String)`、`Crypto(CryptoError)`、`Config(String)`，可读渲染 |
| JSON | `parse_json`、`try_parse_json`、`encode_json`，以及类型化字段读取（`string_field`、`int_field`、`object_field`、`array_field`、`bool_field`） |
| 金额 | `format_yuan`、`parse_yuan_fen`、`validate_amount_fen` |
| 订单号 | `validate_wechat_out_trade_no`、`validate_alipay_out_trade_no` |

校验规则：

- 微信 `out_trade_no`：6–32 字符，字母、数字及 `-_|*`。
- 支付宝 `out_trade_no`：1–64 字符，字母、数字、`_`、`-`。
- 金额必须为正整数分。
- 元字符串必须恰好两位小数；其他形式一律拒绝，不做静默舍入。

## 测试与配套工具

- **131 个测试块**，覆盖单元测试、白盒测试和端到端测试，包含
  `openssl` 生成的参考签名向量。
- **回环端到端测试**（`e2e/`）：微信「下单 → 签名回调 → 验签解密 → 应答」
  与支付宝「签名跳转 → 签名通知 → 验签 → 应答」，另有安全负面用例
  （重放、未知序列号、篡改签名/报文、错误 APIv3 密钥、金额不一致）。
- **`cmd/webdemo`** —— 端口 1943 的本地联调 Web 应用，含微信 Native /
  JSAPI / 小程序面板、支付宝面板、通知端点 `/api/wechat/notify` 与
  `/api/alipay/notify`，以及 `GET /api/config`；由 `WXPAY_*` / `ALIPAY_*`
  环境变量驱动，并附带 `diagnose.sh`。
- **`cmd/sandbox`** —— 环境变量守护的支付宝沙箱冒烟检查，只生成签名跳转
  URL 供人工访问，不会真实扣款。
- **`examples/payment_demo`** —— 面向本地 mock 平台的可运行示例，不会产生
  真实资金流动。

## 尚未实现

以下能力有意排除在当前版本之外：

- **退款** —— 微信 `/v3/refund/domestic/refunds`、支付宝
  `alipay.trade.refund`、退款查询、退款通知。
- **关单** —— 微信关单接口与 `alipay.trade.close`。
- **对账单下载**（两家均无）。
- **转账**、**分账**、**红包 / 代金券**。
- **微信 APP 支付、付款码（线下）支付、合单支付、服务商 / 子商户模式**。
- **支付宝 APP 支付**，以及电脑/手机网站支付之外的产品。
- **支付宝公钥证书模式**（`app_cert_sn` / `alipay_root_sn`）。
- **平台证书定时轮换** —— 仅在遇到未知序列号时刷新。
- 退款单号查询、交易关闭等辅助 API。

## 文档准确性说明

`docs/wechat.zh-CN.md`、`docs/wechat.md`、`docs/alipay.zh-CN.md`、
`docs/alipay.md` 与当前发布 API 一致。根目录 `README.md` / `README.zh-CN.md`
的示例仍保留少量 `v0.1.0` 时期的写法（`private_key_path`、字符串
`total_amount`）；有疑问时以两份指南和本文为准。
