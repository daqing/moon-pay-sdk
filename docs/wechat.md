# WeChat Pay Guide

Everything implemented in moon-pay-sdk for WeChat Pay (API v3): the modules,
how to use them, and the `WXPAY_*` environment variables the bundled webdemo
reads. The Chinese edition of this document is [`docs/wechat.zh-CN.md`](wechat.zh-CN.md).

## Feature matrix

| Capability | Where | Status |
| --- | --- | --- |
| Native payment (QR checkout) | `wechat` | implemented — `Client::native_order` |
| H5 payment (mobile browser) | `wechat` | implemented — `Client::h5_order` |
| JSAPI payment (in-WeChat page) | `wechat` | implemented — `Client::jsapi_order` + `Client::jsapi_pay_params` |
| Mini-program payment (one call) | `miniprogram` | implemented — `Client::pay` (login code → openid → order → pay params) |
| Order query | `wechat` | implemented — by out-trade number or transaction id |
| Callback handling | `wechat` | implemented — signature verification, replay window, AES-256-GCM decryption |
| Signature verification modes | `wechat` | platform certificates (auto download) **and** public-key mode (`PUB_KEY_ID_...`) |
| Integration-test web app | `cmd/webdemo` | bundled — real-gateway manual testing |

Not implemented yet: refunds, bill download, combined orders, payment-code
(offline) payment, APP payment. See the root README's roadmap.

## Modules

| Module | Role |
| --- | --- |
| `daqing/moon-pay-sdk/wechat` | The WeChat Pay v3 client: orders (Native / H5 / JSAPI), order query, callback verification and decryption, platform-certificate / public-key management, request signing and response verification |
| `daqing/moon-pay-sdk/miniprogram` | The Mini-Program server flow: `wx.login` code exchange (`code2session`) composed with a JSAPI order into one call |
| `daqing/moon-pay-sdk/crypto` | RSA-SHA256 sign/verify, X.509 parsing, AES-256-GCM (pure MoonBit) |
| `daqing/moon-pay-sdk/transport` | HTTPS over moonbitlang/async (epoll on Linux, kqueue on macOS); a `MockTransport` for tests |
| `cmd/webdemo` | A local web app for manual integration testing against the real gateway — the source of the `WXPAY_*` variables below |

Install and import:

```bash
moon add daqing/moon-pay-sdk
```

```text
// moon.pkg
import {
  "daqing/moon-pay-sdk/wechat",
  "daqing/moon-pay-sdk/miniprogram", // mini-program flow only
}
```

## Getting started

Build the client once at startup; credentials never travel per-request:

```moonbit nocheck
///|
async fn main {
  let wechat = @wechat.Client::new(
    config=@wechat.Config::new(
      appid="wx8888888888888888",
      mchid="1900000000",
      serial_no="YOUR-CERT-SERIAL",
      private_key_pem~, // application private key, PEM text
      api_v3_key="YOUR-32-CHARACTER-APIV3-KEY",
    ),
    transport=@transport.HttpClient::new(),
  )
}
```

### Signature-verification modes

WeChat's responses and callbacks are verified with either of two key sets,
configured on `Config`:

- **Public-key mode (公钥模式)** — set `platform_public_key_pem` (the WeChat
  Pay public key downloaded from the console, `pub_key.pem`) together with
  `platform_public_key_id` (the `PUB_KEY_ID_...` serial shown next to it —
  set both or neither). Nothing is downloaded at runtime; this is the default
  for new merchant accounts.
- **Certificate mode** — leave both unset; platform certificates are fetched
  from `/v3/certificates` (APIv3-key decrypted) and refreshed automatically
  on an unknown `Wechatpay-Serial`.

## Payment methods

### Native (QR checkout)

Desktop websites: render the returned `code_url` as a QR code the customer
scans with WeChat.

```moonbit nocheck
///|
async fn native_checkout(wechat : @wechat.Client) -> Unit raise {
  let order = wechat.native_order(
    out_trade_no="order-20261007-0001",
    total=100, // integer fen: 100 = CNY 1.00
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
  )
  println("QR content: \{order.code_url()}")
}
```

### H5 (mobile browser)

Outside-WeChat mobile pages: redirect the browser to the returned URL; the
customer's IP is required by WeChat.

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
  println("Redirect to: \{order.h5_url()}")
}
```

### JSAPI (in-WeChat page)

Mini-programs and official-account pages: order with the payer's openid,
then hand the signed parameter set to `wx.requestPayment`
(mini-program) or `WeixinJSBridge` (official-account page).

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
    openid~, // the payer's openid under this appid
  )
  let params = wechat.jsapi_pay_params(prepay_id=order.prepay_id())
  // Return params to the client for wx.requestPayment:
  //   timeStamp / nonceStr / package ("prepay_id=...") / signType "RSA" / paySign
}
```

The `paySign` is the merchant private key's RSA-SHA256 signature over the
four-line canonical form `appId\ntimeStamp\nnonceStr\npackage\n`.

### Mini-program (one call)

The `miniprogram` package wraps the whole server flow: exchange a fresh
`wx.login` code for the payer's openid, place the JSAPI order and sign the
pay parameters. Codes are single-use and expire in five minutes, so exchange
at order time.

```moonbit nocheck
///|
async fn miniapp_checkout(miniapp : @miniprogram.Client) -> Unit raise {
  let result = miniapp.pay(
    out_trade_no="order-20261007-0004",
    total=100,
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
    js_code~, // fresh from wx.login
  )
  println("openid \{result.openid()}, prepay \{result.prepay_id()}")
  // result.pay_params() feeds wx.requestPayment.
}
```

Build the client from the same pay client plus the mini-program secret
(`app_id` must equal the pay client's appid — enforced at construction):

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

`Client::code2session(js_code~)` is also public for exchanges you drive
yourself; `Client::pay_with_openid(openid~)` skips the exchange when you
already keep openids.

## Order query

Callbacks can get lost — query to reconcile, by out-trade number or WeChat
transaction id:

```moonbit nocheck
///|
async fn reconcile(wechat : @wechat.Client) -> Unit raise {
  let paid = wechat.query_order(out_trade_no="order-20261007-0001")
  if paid.trade_state() is @wechat.Success {
    println("paid \{paid.total_fen()} fen")
  }
  let by_id = wechat.query_order_by_id(transaction_id="4200001234202610")
}
```

`TradeState` covers all documented states plus `Unknown(String)` for future
ones.

## Callback handling

WeChat POSTs a signed, AES-256-GCM-encrypted notification to your
`notify_url`. Verify and acknowledge:

```moonbit nocheck
///|
async fn handle_wechat_callback(
  wechat : @wechat.Client,
  headers : Array[(String, String)],
  body : Bytes,
) -> (Int, String) {
  // Verifies the signature (replay window included), decrypts the payload
  // and returns the parsed payment result; raises on any mismatch.
  let notification = wechat.verify_callback(headers, body)
  if notification.trade_state() is wechat.Success {
    // notification.out_trade_no() is paid — reconcile the amount, then
    // update your order storage.
  }
  @wechat.ack_success() // -> (200, '{"code":"SUCCESS",...}')
}
```

Acknowledge failures with `@wechat.ack_failure(message~)` so WeChat retries.
Never mark an order paid without verifying the amount against the local
order.

## Environment variables (`WXPAY_*`)

These configure `cmd/webdemo`, the bundled integration-test web app. The SDK
itself takes credentials through `Config` constructors — no environment
involved. Nothing secret lives in the repository: copy
`cmd/webdemo/env.example.sh` to `cmd/webdemo/env.sh` (gitignored), fill it
in, then `source cmd/webdemo/env.sh && moon run cmd/webdemo`.

| Variable | Required | Meaning |
| --- | --- | --- |
| `WXPAY_APPID` | yes | Merchant app id, e.g. `wx…`. A mini-program appid works for Native/JSAPI as long as it is bound to the mchid (商户平台 → 产品中心 → AppID账号管理) |
| `WXPAY_MCHID` | yes | Merchant id |
| `WXPAY_SERIAL_NO` | yes | Merchant **API certificate** serial — 40 hex chars, from `apiclient_cert.pem` in the certificate zip or 商户平台 → API安全 → API证书 |
| `WXPAY_PRIVATE_KEY` | yes | API-certificate private key (`apiclient_key.pem`): PEM text, or a path to the PEM file |
| `WXPAY_API_V3_KEY` | yes | The 32-char APIv3 key set under 商户平台 → API安全, used for callback decryption |
| `WXPAY_BASE_URL` | no | Gateway, default `https://api.mch.weixin.qq.com` |
| `WXPAY_PUBLIC_KEY` | no | Public-key mode: the WeChat Pay public key (`pub_key.pem`) from the console; PEM text or file path |
| `WXPAY_PUBLIC_KEY_ID` | no | Public-key mode: the `PUB_KEY_ID_…` serial shown next to it — set both or neither |
| `WXPAY_NOTIFY_URL` | no | Callback URL sent with every order; defaults to a placeholder |
| `WXPAY_APP_SECRET` | no | Mini-program AppSecret (小程序 → 开发管理 → 开发设置); enables the mini-program pay panel, where the server exchanges `wx.login` codes for openids |

### What each value must be

Wrong values here are the most common cause of gateway rejections —
`SIGN_ERROR (http 401)` in particular. Run `bash cmd/webdemo/diagnose.sh`
to mechanically check the whole configuration without printing key material.

| Variable | Must be | Must not be |
| --- | --- | --- |
| `WXPAY_SERIAL_NO` | The **API certificate** serial, 40 hex chars | A `PUB_KEY_ID_…` **public-key** serial |
| `WXPAY_PRIVATE_KEY` | `apiclient_key.pem` from the **same** certificate-zip request as that serial | `pub_key.pem` (that is the public key) or a self-generated key — WeChat looks the certificate up by the request's serial, so the private key must pair with it |
| `WXPAY_API_V3_KEY` | The 32-char APIv3 key | The login password or the APIv2 key |
| `WXPAY_PUBLIC_KEY` | The console's **微信支付公钥** `pub_key.pem` | Your own certificate's public key |
| `WXPAY_PUBLIC_KEY_ID` | The `PUB_KEY_ID_…` serial displayed next to `pub_key.pem` | The API certificate serial |
| `WXPAY_APP_SECRET` | The mini-program's AppSecret, server-side only | Committed to git or sent to clients |

### The webdemo

The server listens on **1943** and serves one page per gateway:

- **`http://127.0.0.1:1943/`** — the WeChat page: Native QR checkout with
  2-second polling, a JSAPI section (openid in, `wx.requestPayment` params
  out) and, with `WXPAY_APP_SECRET` set, a mini-program section (login code
  in, params out). Callbacks land on `POST /api/wechat/notify`.
- **`http://127.0.0.1:1943/alipay`** — the Alipay page (see the Alipay docs).

The page asks `GET /api/config` at load which panels are enabled; a gateway
whose variables are incomplete is never contacted. Every order is a real
charge — keep the ¥0.01 default; test orders carry the `IT` prefix for easy
spotting and refunding.

## Troubleshooting

- **`SIGN_ERROR (http 401)`** — a signature-layer rejection that happens
  before appid/product permission checks: the private key, the serial in the
  request, or the clock is wrong. Run `bash cmd/webdemo/diagnose.sh` (clock,
  serial format, private key ↔ certificate pairing). It is not a permissions
  problem.
- **`PARAM_ERROR: 无效的openid`** on a JSAPI order — the request signature
  was accepted; the openid does not belong to this appid. Use the openid
  from this appid's own `wx.login` flow (the miniapp client enforces the
  matching appid for exactly this reason).
- **Missing credentials at startup** — the app prints which variables are
  missing or set-but-empty. Variables must be exported (`export WXPAY_...`);
  a sourced file must be re-sourced after editing.
