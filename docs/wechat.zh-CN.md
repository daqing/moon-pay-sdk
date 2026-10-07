# 微信支付指南

moon-pay-sdk 已实现的微信支付（API v3）全部内容：模块、使用方式，以及配套
webdemo 读取的 `WXPAY_*` 环境变量。英文版见
[`docs/wechat.md`](wechat.md)。

## 功能矩阵

| 能力 | 所在模块 | 状态 |
| --- | --- | --- |
| Native 支付（扫码） | `wechat` | 已实现 — `Client::native_order` |
| H5 支付（移动端浏览器） | `wechat` | 已实现 — `Client::h5_order` |
| JSAPI 支付（微信内网页） | `wechat` | 已实现 — `Client::jsapi_order` + `Client::jsapi_pay_params` |
| 小程序支付（一步下单） | `miniprogram` | 已实现 — `Client::pay`（code 换 openid → 下单 → 支付参数） |
| 查单 | `wechat` | 已实现 — 按商户订单号或微信交易单号 |
| 回调处理 | `wechat` | 已实现 — 验签（含防重放）、AES-256-GCM 解密 |
| 验签模式 | `wechat` | 平台证书（自动下载）**和**公钥模式（`PUB_KEY_ID_...`） |
| 集成测试 Web 应用 | `cmd/webdemo` | 内置 — 真实网关人工测试 |

尚未实现：退款、对账单下载、合单支付、付款码（线下）支付、APP 支付。见根
README 的 Roadmap。

## 模块

| 模块 | 职责 |
| --- | --- |
| `daqing/moon-pay-sdk/wechat` | 微信支付 v3 客户端：下单（Native / H5 / JSAPI）、查单、回调验签与解密、平台证书/公钥管理、请求签名与响应验签 |
| `daqing/moon-pay-sdk/miniprogram` | 小程序服务端流程：`wx.login` code 换取 openid（code2session），并与 JSAPI 下单组合为一步 |
| `daqing/moon-pay-sdk/crypto` | RSA-SHA256 签名/验签、X.509 解析、AES-256-GCM（纯 MoonBit） |
| `daqing/moon-pay-sdk/transport` | 基于 moonbitlang/async 的 HTTPS（Linux epoll / macOS kqueue）；测试用 `MockTransport` |
| `cmd/webdemo` | 本地集成测试 Web 应用，打真实网关人工验证 — 下文 `WXPAY_*` 变量的来源 |

安装与导入：

```bash
moon add daqing/moon-pay-sdk
```

```text
// moon.pkg
import {
  "daqing/moon-pay-sdk/wechat",
  "daqing/moon-pay-sdk/miniprogram", // 仅小程序流程需要
}
```

## 快速开始

客户端在启动时构造一次；凭证不随请求传递：

```moonbit nocheck
///|
async fn main {
  let wechat = @wechat.Client::new(
    config=@wechat.Config::new(
      appid="wx8888888888888888",
      mchid="1900000000",
      serial_no="YOUR-CERT-SERIAL",
      private_key_pem~, // 应用私钥，PEM 文本
      api_v3_key="YOUR-32-CHARACTER-APIV3-KEY",
    ),
    transport=@transport.HttpClient::new(),
  )
}
```

### 验签模式

微信的响应与回调用以下两种密钥之一验签，在 `Config` 上配置：

- **公钥模式** — 设置 `platform_public_key_pem`（控制台下载的微信支付
  公钥 `pub_key.pem`）和 `platform_public_key_id`（旁边显示的
  `PUB_KEY_ID_...` 序列号——两个都填或都不填）。运行时不下载任何东西；
  新商户账号默认此模式。
- **证书模式** — 两者都不设置；平台证书从 `/v3/certificates` 下载（用
  APIv3 密钥解密），遇到未知 `Wechatpay-Serial` 自动刷新。

## 支付方式

### Native（扫码）

桌面网站：把返回的 `code_url` 渲染成二维码，用户用微信扫码。

```moonbit nocheck
///|
async fn native_checkout(wechat : @wechat.Client) -> Unit raise {
  let order = wechat.native_order(
    out_trade_no="order-20261007-0001",
    total=100, // 单位是分：100 = 人民币 1.00 元
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
  )
  println("二维码内容: \{order.code_url()}")
}
```

### H5（移动端浏览器）

微信外的手机网页：把浏览器重定向到返回的链接；微信要求传客户 IP。

```moonbit nocheck
///|
async fn h5_checkout(wechat : @wechat.Client, client_ip : String) -> Unit raise {
  let order = wechat.h5_order(
    out_trade_no="order-20261007-0002",
    total=100,
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
    payer_client_ip=client_ip,
  )
  println("重定向到: \{order.h5_url()}")
}
```

### JSAPI（微信内网页）

小程序和公众号网页：用付款人 openid 下单，再把签名好的参数集交给小程序的
`wx.requestPayment` 或公众号的 `WeixinJSBridge`。

```moonbit nocheck
///|
async fn jsapi_checkout(
  wechat : @wechat.Client,
  openid : String,
) -> Unit raise {
  let order = wechat.jsapi_order(
    out_trade_no="order-20261007-0003",
    total=100,
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
    openid~, // 该 appid 下的付款人 openid
  )
  let params = wechat.jsapi_pay_params(prepay_id=order.prepay_id())
  // 把 params 返回给前端调 wx.requestPayment：
  //   timeStamp / nonceStr / package（"prepay_id=..."）/ signType "RSA" / paySign
}
```

`paySign` 是商户私钥对四行规范串
`appId\ntimeStamp\nnonceStr\npackage\n` 的 RSA-SHA256 签名。

### 小程序（一步下单）

`miniprogram` 包封装了完整的服务端流程：用新鲜的 `wx.login` code 换付款人
openid、下 JSAPI 订单、签支付参数。code 一次性且五分钟内有效，应下单时换取。

```moonbit nocheck
///|
async fn miniapp_checkout(miniapp : @miniprogram.Client) -> Unit raise {
  let result = miniapp.pay(
    out_trade_no="order-20261007-0004",
    total=100,
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
    js_code~, // wx.login 刚返回的 code
  )
  println("openid \{result.openid()}, prepay \{result.prepay_id()}")
  // result.pay_params() 交给 wx.requestPayment。
}
```

客户端由同一个支付客户端加小程序密钥构造（`app_id` 必须与支付客户端的
appid 一致——构造时强制校验）：

```moonbit nocheck
///|
async fn build_miniapp(wechat : @wechat.Client) -> @miniprogram.Client raise {
  @miniprogram.Client::new(
    config=@miniprogram.Config::new(
      app_id="wx8888888888888888",
      app_secret="YOUR-MINI-PROGRAM-APP-SECRET",
    ),
    pay=wechat,
    transport=@transport.HttpClient::new(),
  )
}
```

`Client::code2session(js_code~)` 也公开可用，供自行管理换取时机；
`Client::pay_with_openid(openid~)` 在已保存 openid 时跳过换取。

## 查单

回调可能丢失——用查单对账，可按商户订单号或微信交易单号：

```moonbit nocheck
///|
async fn reconcile(wechat : @wechat.Client) -> Unit raise {
  let paid = wechat.query_order(out_trade_no="order-20261007-0001")
  if paid.trade_state() is @wechat.Success {
    println("已支付 \{paid.total_fen()} 分")
  }
  let by_id = wechat.query_order_by_id(transaction_id="4200001234202610")
}
```

`TradeState` 覆盖全部已文档状态，另有 `Unknown(String)` 兜底未来状态。

## 回调处理

微信向你的 `notify_url` POST 带签名、AES-256-GCM 加密的通知。验签并应答：

```moonbit nocheck
///|
async fn handle_wechat_callback(
  wechat : @wechat.Client,
  headers : Array[(String, String)],
  body : Bytes,
) -> (Int, String) {
  // 验证签名（含防重放时间窗）、解密报文并返回解析后的支付结果；
  // 任何不匹配都会 raise。
  let notification = wechat.verify_callback(headers, body)
  if notification.trade_state() is wechat.Success {
    // notification.out_trade_no() 已支付——核对金额后更新订单存储。
  }
  @wechat.ack_success() // -> (200, '{"code":"SUCCESS",...}')
}
```

失败用 `@wechat.ack_failure(message~)` 应答，微信会重试。未核对本地订单
金额前，绝不要把订单标记为已支付。

## 环境变量（`WXPAY_*`）

这些变量配置的是 `cmd/webdemo`（内置的集成测试 Web 应用）。SDK 本身通过
`Config` 构造函数接收凭证——与环境无关。仓库不保存任何机密：把
`cmd/webdemo/env.example.sh` 复制为 `cmd/webdemo/env.sh`（已 gitignore），
填好后 `source cmd/webdemo/env.sh && moon run cmd/webdemo`。

| 变量 | 必填 | 说明 |
| --- | --- | --- |
| `WXPAY_APPID` | 是 | 商户 appid，例如 `wx…`。小程序 appid 也可做 Native/JSAPI，前提是与商户号绑定（商户平台 → 产品中心 → AppID账号管理） |
| `WXPAY_MCHID` | 是 | 商户号 |
| `WXPAY_SERIAL_NO` | 是 | 商户 **API 证书**序列号——40 位十六进制，来自证书 zip 里的 `apiclient_cert.pem` 或 商户平台 → API安全 → API证书 |
| `WXPAY_PRIVATE_KEY` | 是 | API 证书私钥（`apiclient_key.pem`）：PEM 文本或 PEM 文件路径 |
| `WXPAY_API_V3_KEY` | 是 | 商户平台 → API安全 里设置的 32 位 APIv3 密钥，用于回调解密 |
| `WXPAY_BASE_URL` | 否 | 网关地址，默认 `https://api.mch.weixin.qq.com` |
| `WXPAY_PUBLIC_KEY` | 否 | 公钥模式：控制台下载的微信支付公钥（`pub_key.pem`），PEM 文本或文件路径 |
| `WXPAY_PUBLIC_KEY_ID` | 否 | 公钥模式：旁边显示的 `PUB_KEY_ID_…` 序列号——两个都填或都不填 |
| `WXPAY_NOTIFY_URL` | 否 | 下单时传入的回调地址，默认为占位符 |
| `WXPAY_APP_SECRET` | 否 | 小程序 AppSecret（小程序 → 开发管理 → 开发设置）；启用小程序支付区块，服务端用它换取 `wx.login` code 对应的 openid |

### 每个值必须填什么

这些值填错是网关拒单（尤其是 `SIGN_ERROR (http 401)`）的最常见原因。运行
`bash cmd/webdemo/diagnose.sh` 可机械化核对全部配置，且不打印任何密钥内容。

| 变量 | 必须是 | 不能是 |
| --- | --- | --- |
| `WXPAY_SERIAL_NO` | **API 证书**序列号，40 位十六进制 | `PUB_KEY_ID_…` 开头的**公钥**序列号 |
| `WXPAY_PRIVATE_KEY` | 与该序列号**同一次申请**的证书 zip 里的 `apiclient_key.pem` | `pub_key.pem`（那是公钥）、自己生成的密钥——微信按请求里的序列号找到证书验签，私钥必须与该证书配套 |
| `WXPAY_API_V3_KEY` | 32 位 APIv3 密钥 | 登录密码或 APIv2 密钥 |
| `WXPAY_PUBLIC_KEY` | 控制台「**微信支付公钥**」的 `pub_key.pem` | 自己证书的公钥 |
| `WXPAY_PUBLIC_KEY_ID` | `pub_key.pem` 旁边显示的 `PUB_KEY_ID_...` 序列号 | API 证书序列号 |
| `WXPAY_APP_SECRET` | 小程序的 AppSecret，仅服务端使用 | 提交进 git 或下发到客户端 |

### webdemo

服务监听 **1943** 端口，每个网关一个页面：

- **`http://127.0.0.1:1943/`** — 微信页：Native 扫码支付（2 秒轮询）、
  JSAPI 区块（输入 openid，输出 `wx.requestPayment` 参数）以及配置了
  `WXPAY_APP_SECRET` 后的小程序区块（输入登录 code，输出参数）。回调落在
  `POST /api/wechat/notify`。
- **`http://127.0.0.1:1943/alipay`** — 支付宝页（见支付宝文档）。

页面加载时查询 `GET /api/config` 得知哪些面板可用；变量不齐的网关不会被
访问。每笔订单都是真实扣款——保持 ¥0.01 默认值；测试单号带 `IT` 前缀，
便于辨认与退款。

## 排错

- **`SIGN_ERROR (http 401)`** — 签名层拒绝，发生在 appid/产品权限校验
  之前：私钥、请求里的序列号或时钟有问题。运行
  `bash cmd/webdemo/diagnose.sh`（时钟、序列号格式、私钥 ↔ 证书配对）。
  这不是权限问题。
- **JSAPI 下单报 `PARAM_ERROR: 无效的openid`** — 请求签名已被接受；
  openid 不属于这个 appid。用该 appid 自己的 `wx.login` 流程取得的
  openid（miniapp 客户端强制 appid 一致正是为此）。
- **启动时报缺凭证** — 应用会打印哪些变量缺失或导出了但为空。变量必须
  export（`export WXPAY_...`）；改过 env.sh 要重新 source。
