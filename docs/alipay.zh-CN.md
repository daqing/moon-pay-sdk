# 支付宝指南

moon-pay-sdk 已实现的支付宝（OpenAPI）全部内容：模块、使用方式，以及配套
webdemo 读取的 `ALIPAY_*` 环境变量。英文版见
[`docs/alipay.md`](alipay.md)。

## 功能矩阵

| 能力 | 所在模块 | 状态 |
| --- | --- | --- |
| 电脑网站支付 | `alipay` | 已实现 — `Client::page_pay_url`（`alipay.trade.page.pay`） |
| 手机网站支付 | `alipay` | 已实现 — `Client::wap_pay_url`（`alipay.trade.wap.pay`） |
| 查单 | `alipay` | 已实现 — `Client::query_order`（`alipay.trade.query`） |
| 异步通知处理 | `alipay` | 已实现 — `Client::verify_notify`（RSA2 验签 + app_id 归属校验） |
| 同步回跳验签 | `alipay` | 已实现 — `Client::verify_return_params` |
| 加签集成模式 | — | **仅公钥模式**；不支持证书模式（`app_cert_sn`/`alipay_root_sn`） |
| 集成测试 Web 应用 | `cmd/webdemo` | 内置 — 真实网关人工测试 |

尚未实现：退款（`alipay.trade.refund`）、对账单下载、转账。见根 README 的
Roadmap。

## 模块

| 模块 | 职责 |
| --- | --- |
| `daqing/moon-pay-sdk/alipay` | 支付宝 OpenAPI 客户端：page/wap 下单地址、查单、异步通知与回跳验签、RSA2 请求签名 |
| `daqing/moon-pay-sdk/crypto` | RSA-SHA256 签名/验签（纯 MoonBit） |
| `daqing/moon-pay-sdk/transport` | 基于 moonbitlang/async 的 HTTPS（Linux epoll / macOS kqueue）；测试用 `MockTransport` |
| `cmd/webdemo` | 本地集成测试 Web 应用，打真实网关人工验证 — 下文 `ALIPAY_*` 变量的来源 |

安装与导入：

```bash
moon add daqing/moon-pay-sdk
```

```text
// moon.pkg
import {
  "daqing/moon-pay-sdk/alipay",
}
```

## 快速开始

客户端在启动时构造一次：

```moonbit nocheck
///|
async fn main {
  let alipay = @alipay.Client::new(
    config=@alipay.Config::new(
      app_id="2021000000000000",
      private_key_pem~, // 你的应用私钥，PEM 文本
      alipay_public_key_pem~, // 支付宝公钥，PEM 文本
    ),
    transport=@transport.HttpClient::new(),
  )
}
```

三个值、三个不同的主人——填混是支付宝侧最常见的错误：

- `app_id` — 开放平台**网页应用**的 APPID（`2021…` 开头 16 位）。
- `private_key_pem` — 你用支付宝密钥工具生成的**应用私钥**，其公半已上传
  到控制台。
- `alipay_public_key_pem` — 上传应用公钥后控制台显示的**支付宝公钥**。这是
  支付宝自己的钥匙，**不是**你密钥对的公半。

两个 PEM 参数都是文本、不是文件路径——先自己读文件（如
`@fs.read_to_string`）再构造。PEM 必须带 `-----BEGIN/END-----` 头；控制台
复制按钮给的裸 base64 解析不了（见[裸密钥转换](#裸密钥转-pem)）。

控制台的接口加签方式必须是**公钥模式**——SDK 没有
`app_cert_sn`/`alipay_root_sn` 字段，公钥证书模式无法工作。正式收款还需
签约电脑网站支付/手机网站支付产品（需企业/个体工商户资质）且应用已上线。

## 支付方式

两种方式都返回**签名好的跳转地址**——下单时不打网关；用户浏览器到达收银
台时才创建交易。

### 电脑网站支付

```moonbit nocheck
///|
fn page_checkout(alipay : @alipay.Client) -> Unit raise {
  let url = alipay.page_pay_url(
    out_trade_no="order-20261007-0001",
    total_fen=8800, // 单位是分：8800 = 人民币 88.00 元
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
    return_url="https://example.com/thanks",
  )
  // 把用户的浏览器重定向到 `url`。
}
```

SDK 会携带 `product_code=FAST_INSTANT_TRADE_PAY`（与官方 demo 一致）。
付款后支付宝把浏览器带回 `return_url` 并追加带签名的 GET 参数——仅供展示，
见[同步回跳验签](#同步回跳验签)。

### 手机网站支付

```moonbit nocheck
///|
fn wap_checkout(alipay : @alipay.Client) -> Unit raise {
  let url = alipay.wap_pay_url(
    out_trade_no="order-20261007-0002",
    total_fen=8800,
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
  )
  // 把用户的手机浏览器重定向到 `url`。
}
```

携带 `product_code=QUICK_WAP_WAY`。

## 查单

页面轮询，或对账没到达的通知：

```moonbit nocheck
///|
async fn reconcile(alipay : @alipay.Client) -> Unit raise {
  let status = alipay.query_order(out_trade_no="order-20261007-0001")
  if status.trade_status() is @alipay.TradeSuccess {
    println("已支付 \{status.total_fen()} 分")
  }
}
```

`TradeStatus` 覆盖 `WaitBuyerPay` / `TradeClosed` / `TradeSuccess` /
`TradeFinished`，另有 `Unknown(String)` 兜底未来状态。查询从未在支付宝创建
过的订单会抛 `Api` 错误（`40004` / 交易不存在）——未支付的跳转单这是正常
现象，不是签名问题。

同步响应先经支付宝公钥对 `alipay_trade_query_response` 成员**原文**验签，
字段才被采信。

## 异步通知处理

交易落定后，支付宝向你的 `notify_url` POST 一份 urlencoded 表单。验 RSA2
签名和 app_id 归属、核对金额，然后应答纯文本 `success`，支付宝才会停止
重试：

```moonbit nocheck
///|
fn handle_alipay_notify(
  alipay : @alipay.Client,
  form : Array[(String, String)], // 解析后的 urlencoded body
) -> String {
  // 先验签名，再校验 app_id 归属；任何不匹配都会 raise。
  let notify = alipay.verify_notify(form)
  if notify.trade_status() is @alipay.TradeSuccess
    && notify.amount_matches(8800) {
    // 签名对、来自支付宝、归属本应用、金额一致——标记订单已支付。
  }
  @alipay.ack_success() // -> "success"
}
```

应答其他内容（如 `failure`）支付宝会按其节奏重试。需要自行拆原始 body 时
可用公开的 `parse_form_params`。

## 同步回跳验签

支付宝追加到 `return_url` 的带签名 GET 参数用同一套机制验签：

```moonbit nocheck
///|
fn handle_return(alipay : @alipay.Client, query : StringView) -> Unit raise {
  // 例如 query = "charset=utf-8&out_trade_no=...&total_amount=88.00&sign=..."
  let params = alipay.verify_return_params(query)
  // 读取 out_trade_no / trade_no 等用于结果展示页。
}
```

仅凭回跳永远不能证明已支付——只有验签过的通知和查单结果才算数。

## 签名规则（生产网关实证）

面向维护者的说明；调用方不需要，但它解释了公开 helper 的分工：

- **出站请求**对除 `sign` 外全部参数按键排序后 `k=v&…` 签名——
  **包含 `sign_type`**（`build_request_sign_content`；`sign_params` 使用
  它）。生产网关 invalid-signature 错误页打印的验签字符串里带
  `sign_type=RSA2`。
- **入站通知与回跳**对除 `sign` 和 `sign_type` 外的参数验签
  （`build_sign_content`）。
- **同步响应**对 `alipay_xxx_response` 成员**原文**验签
  （`Client::verify_content`）。
- 错误响应是 **GBK** 编码（与请求 charset 无关）；body 做 lossy 解码，
  保证 ASCII 的 `code`/`sub_code` 可读。

## 环境变量（`ALIPAY_*`）

这些变量配置的是 `cmd/webdemo`（内置集成测试 Web 应用的支付宝页
`http://127.0.0.1:1943/alipay`）。SDK 本身通过 `Config` 接收凭证——与
环境无关。把 `cmd/webdemo/env.example.sh` 复制为 `cmd/webdemo/env.sh`
（已 gitignore），填好后 `source cmd/webdemo/env.sh && moon run
cmd/webdemo`。

| 变量 | 必填 | 说明 |
| --- | --- | --- |
| `ALIPAY_APPID` | 是 | 开放平台网页应用 APPID，例如 `2021…` |
| `ALIPAY_PRIVATE_KEY` | 是 | 应用私钥（密钥工具生成的 RSA2）：PEM 文本或 PEM 文件路径 |
| `ALIPAY_PUBLIC_KEY` | 是 | 控制台「接口加签方式 → 公钥模式」显示的**支付宝公钥**：PEM 文本或文件路径 |
| `ALIPAY_GATEWAY_URL` | 否 | 网关，默认 `https://openapi.alipay.com/gateway.do`；沙箱凭证测试时指向沙箱网关 |
| `ALIPAY_NOTIFY_URL` | 否 | 支付宝异步通知 POST 的地址，默认为占位符 |

### 每个值必须填什么

| 变量 | 必须是 | 不能是 |
| --- | --- | --- |
| `ALIPAY_PRIVATE_KEY` | 支付宝密钥工具生成的应用私钥，与上传控制台的应用公钥配对 | 支付宝公钥 |
| `ALIPAY_PUBLIC_KEY` | 上传应用公钥后控制台显示的**支付宝公钥** | 自己的应用公钥或应用私钥——支付宝侧最常见的错误 |

`bash cmd/webdemo/diagnose.sh` 机械化核对可读性、可解析性、密钥位数和
「填反/填成自己的钥匙」等错误，且不打印密钥内容。

### 裸密钥转 PEM

控制台和密钥工具的复制按钮给的是**没有 `-----BEGIN/END-----` 头的裸
base64**——OpenSSL 和本 SDK 都解析不了。包一层（macOS）：

```bash
fold -w 64 private_key.txt | awk '{print}' | {
  printf -- '-----BEGIN PRIVATE KEY-----\n'; cat; printf -- '-----END PRIVATE KEY-----\n'
} > private_key.pem
```

`awk` 保证 `-----END…-----` 前有换行（裸密钥没有结尾换行，只用 `fold` 会
把头粘到最后一段 base64 上）。支付宝公钥同样方式包
`-----BEGIN/END PUBLIC KEY-----`。

## 排错

- **首个真实请求返回 `40002 invalid-signature`** — 网关找到了这个应用，
  但控制台登记的应用公钥与 `ALIPAY_PRIVATE_KEY` 不配对。重新上传由该私钥
  导出的应用公钥（`openssl pkey -in <private_key.pem> -pubout`），并确认
  控制台「接口加签方式」是公钥模式——证书模式同样报 invalid-signature 且
  本 SDK 不支持。
- **收银台页 `订单信息无法识别 / INVALID_PARAMETER` 或
  `errorCode=FISHING_RISK`** — 签名已通过但该应用无法创建交易：应用必须
  **已上线**（不能是「开发中」），且已签约电脑网站支付（商家平台 →
  产品中心 → 我的产品；需企业资质）。未签约时想跑通流程可用沙箱：沙箱
  凭证 + `ALIPAY_GATEWAY_URL=https://openapi-sandbox.dl.alipaydev.com/gateway.do`。
- **查单返回 `40004 交易不存在`** — 收银台地址从未被打开/支付的正常表现；
  签名没问题。
- **服务端日志里错误信息是乱码** — 支付宝错误响应是 GBK；SDK 做 lossy
  解码，可读部分是 ASCII 的 `code`/`sub_code`。
