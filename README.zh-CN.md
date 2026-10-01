# moon-pay-sdk

微信支付与支付宝的原生 MoonBit SDK。

`moon-pay-sdk` 是一个用原生 MoonBit 编写的服务端支付 SDK，让 MoonBit 应用能够对接**微信支付**和**支付宝**：创建订单、查询订单状态，并处理两家支付平台主动推送到你服务器的异步支付通知。

项目为 MoonBit 黑客松而开发，面向 MoonBit native 后端——没有 JavaScript 桥接，也没有解释器参与运行。从 RSA 请求签名、回调解密到 TLS 传输，全部以原生代码运行，底层依赖 [`moonbitlang/async`](https://mooncakes.io/docs/#/moonbitlang/async) 和轻量的 OpenSSL C 绑定。

> **状态**：黑客松开发中的项目。下面的示例展示目标 API；范围与进度见 [Roadmap](#roadmap)。

## 功能

### 微信支付（API v3）

- **Native 支付** — 创建订单并返回 `code_url`，在网站上渲染成二维码供用户扫码
- **H5 支付** — 创建订单并返回支付链接，在移动端浏览器中拉起微信支付
- **查单** — 按商户订单号或交易单号查询订单，用于回调丢失时对账
- **回调处理** — 使用平台证书验签，解密 AES-256-GCM 报文并解析支付结果

### 支付宝（开放平台）

- **电脑网站支付** — `alipay.trade.page.pay`，生成桌面网站收银台跳转链接
- **手机网站支付** — `alipay.trade.wap.pay`，面向移动端网页
- **查单** — `alipay.trade.query`
- **异步通知处理** — 对支付宝 POST 到 `notify_url` 的表单参数做 RSA2 验签

### 暂不支持（后续版本）

退款、转账、对账单下载、服务商（子商户）接口留待后续版本——见 [Roadmap](#roadmap)。

## 环境要求

- MoonBit 工具链（`moon`），native 后端
- Linux（epoll）或 macOS（kqueue）
- OpenSSL — 用于 TLS 传输和 RSA/AES-GCM 加解密
- 微信支付商户号（API v3 证书与密钥）和/或支付宝开放平台应用，用于真实收款

## 安装

```bash
moon add daqing/moon-pay-sdk
```

然后在 `moon.pkg` 中引入所需的包：

```
import {
  "daqing/moon-pay-sdk/wechat",
  "daqing/moon-pay-sdk/alipay",
}
```

## 使用

### 微信支付：扫码支付与查单

```moonbit
///|
async fn main {
  let wechat = @wechat.Client::new(
    appid="wx8888888888888888",
    mchid="1900000000",
    serial_no="YOUR-CERT-SERIAL",
    private_key_path="apiclient_key.pem",
    api_v3_key="YOUR-API-V3-KEY",
  )

  // Native 支付：将 order.code_url 渲染成二维码。
  let order = wechat.native_order(
    out_trade_no="hackathon-20261001-0001",
    total=100, // 单位为分：100 = 人民币 1.00 元
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
  )
  println("QR content: \{order.code_url}")

  // 回调可能丢失——主动查单对账。
  let paid = wechat.query_order(out_trade_no="hackathon-20261001-0001")
  println(paid.trade_state) // "SUCCESS"、"NOTPAY" 等
}
```

### 微信支付：回调处理

```moonbit
///|
async fn handle_wechat_callback(
  wechat : @wechat.Client,
  headers : Map[String, String],
  body : Bytes,
) {
  // 验证微信支付签名，解密 AES-256-GCM 报文，返回解析后的支付结果。
  let notification = wechat.verify_callback(headers, body)
  if notification.trade_state == "SUCCESS" {
    // notification.out_trade_no 已支付——在这里更新你自己的订单存储。
  }
  // 返回 200 表示确认；返回 4xx/5xx 让微信重试。
}
```

### 支付宝：电脑 / 手机网站支付

```moonbit
///|
async fn main {
  let alipay = @alipay.Client::new(
    app_id="2021000000000000",
    private_key_path="app_private_key.pem", // 你的应用私钥
    alipay_public_key_path="alipay_public_key.pem", // 用于验签的支付宝公钥
  )

  // 电脑网站支付：让用户跳转到这个 URL。
  let url = alipay.page_pay_url(
    out_trade_no="hackathon-20261001-0002",
    total_amount="88.00", // 人民币，保留两位小数
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
    return_url="https://example.com/thanks",
  )
  println("Checkout URL: \{url}")

  // 手机网站支付用法相同。
  let wap_url = alipay.wap_pay_url(
    out_trade_no="hackathon-20261001-0003",
    total_amount="88.00",
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
  )
}
```

### 支付宝：异步通知

```moonbit
///|
async fn handle_alipay_notify(
  alipay : @alipay.Client,
  params : Map[String, String], // 解析后的 POST 表单参数
) {
  // 对通知参数做 RSA2 验签。
  let notify = alipay.verify_notify(params)
  if notify.trade_status == "TRADE_SUCCESS" {
    // 支付确认——在这里更新你自己的订单存储。
  }
  // 返回纯文本 "success"，支付宝才会停止重试。
}
```

## 架构

```
你的 MoonBit 应用
          │
moon-pay-sdk
├── wechat      Native / H5 支付、查单、回调验签与解密
├── alipay      电脑 / 手机网站支付、查单、异步通知验签
├── crypto      轻量 OpenSSL FFI：RSA-SHA256 签名与验签、AES-256-GCM 解密
└── transport   基于 moonbitlang/async 的 HTTPS（Linux epoll / macOS kqueue）
          │
系统依赖
├── moonbitlang/async 运行时
└── OpenSSL（TLS、RSA、AES）
```

设计说明：

- **异步运行时与传输** — HTTP/HTTPS 请求基于 [`moonbitlang/async`](https://mooncakes.io/docs/#/moonbitlang/async)，其 TLS 能力构建在 OpenSSL 之上。该库仍处于实验阶段，SDK 固定使用经过验证的版本。
- **通过 OpenSSL FFI 做加解密** — 请求签名（RSA-SHA256）、验签与回调解密（AES-256-GCM）通过薄 C 绑定调用 OpenSSL。复用异步运行时本就链接的同一个 C 依赖，让原生构建保持简单，也把支付级安全正确性交给久经考验的实现，而不是手写密码学。
- **仅支持 native** — 商户私钥只应出现在服务端，因此 SDK 面向 native 后端，产出自包含的原生二进制。

## Roadmap

- **黑客松版本** — 见[功能](#功能)所列范围
- **后续** — 退款（微信 v3、`alipay.trade.refund`）、对账单下载、JSAPI / 小程序支付、平台证书自动更新、对接沙箱的集成测试

## 许可证

[MIT](LICENSE)
