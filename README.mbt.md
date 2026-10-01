# moon-pay-sdk

Native MoonBit SDK for WeChat Pay and Alipay.

`moon-pay-sdk` is a server-side payment SDK written in native MoonBit. It lets
MoonBit applications integrate with **WeChat Pay** and **Alipay**: create
orders, query their status, and handle the asynchronous payment notifications
both providers push to your server.

The project is being developed for the MoonBit Hackathon. It targets the
MoonBit native backend — no JavaScript bridge, no interpreter in the loop. The
whole payment flow, from RSA request signing to TLS transport, runs as native
code built on [`moonbitlang/async`](https://mooncakes.io/docs/#/moonbitlang/async)
and thin OpenSSL C bindings.

> **Status**: work in progress for the hackathon. The examples below show the
> target API; see [Roadmap](#roadmap) for scope and progress.

## Features

### WeChat Pay (API v3)

- **Native payment** — create an order and get a `code_url` to render as a QR
  code on your website
- **H5 payment** — create an order and get a URL that opens WeChat Pay in a
  mobile browser
- **Order query** — look up an order by out-trade number or transaction ID, to
  reconcile missed callbacks
- **Callback handling** — verify the callback signature against platform
  certificates, decrypt the AES-256-GCM payload, and parse the payment result

### Alipay (OpenAPI)

- **Page payment** — `alipay.trade.page.pay`, redirect URL for desktop website
  checkout
- **Wap payment** — `alipay.trade.wap.pay`, for mobile website checkout
- **Order query** — `alipay.trade.query`
- **Async notification handling** — verify RSA2 signatures on the form
  parameters Alipay posts to your `notify_url`

### Not in scope (yet)

Refunds, transfers, bill download and sub-merchant APIs are left for later
releases — see [Roadmap](#roadmap).

## Requirements

- MoonBit toolchain (`moon`) with the native backend
- Linux (epoll) or macOS (kqueue)
- OpenSSL — used for TLS transport and RSA/AES-GCM crypto
- A WeChat Pay merchant account (API v3 certificates and keys) and/or an
  Alipay open-platform application, to actually move money

## Installation

```bash
moon add daqing/moon-pay-sdk
```

Then import the packages you need in your `moon.pkg`:

```
import {
  "daqing/moon-pay-sdk/wechat",
  "daqing/moon-pay-sdk/alipay",
}
```

## Usage

### WeChat Pay: QR checkout and order query

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

  // Native payment: render order.code_url as a QR code.
  let order = wechat.native_order(
    out_trade_no="hackathon-20261001-0001",
    total=100, // in fen: 100 = CNY 1.00
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
  )
  println("QR content: \{order.code_url}")

  // Callbacks can get lost — query to reconcile.
  let paid = wechat.query_order(out_trade_no="hackathon-20261001-0001")
  println(paid.trade_state) // "SUCCESS", "NOTPAY", ...
}
```

### WeChat Pay: callback

```moonbit
///|
async fn handle_wechat_callback(
  wechat : @wechat.Client,
  headers : Map[String, String],
  body : Bytes,
) {
  // Verifies the WeChat Pay signature, decrypts the AES-256-GCM resource
  // and returns the parsed payment result.
  let notification = wechat.verify_callback(headers, body)
  if notification.trade_state == "SUCCESS" {
    // notification.out_trade_no is paid — update your own order storage here.
  }
  // Respond 200 to acknowledge; respond 4xx/5xx to make WeChat retry.
}
```

### Alipay: page / wap checkout

```moonbit
///|
async fn main {
  let alipay = @alipay.Client::new(
    app_id="2021000000000000",
    private_key_path="app_private_key.pem", // your application private key
    alipay_public_key_path="alipay_public_key.pem", // for verifying notifications
  )

  // Desktop website checkout: redirect the customer to this URL.
  let url = alipay.page_pay_url(
    out_trade_no="hackathon-20261001-0002",
    total_amount="88.00", // CNY, two decimal places
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
    return_url="https://example.com/thanks",
  )
  println("Checkout URL: \{url}")

  // Mobile website checkout works the same way.
  let wap_url = alipay.wap_pay_url(
    out_trade_no="hackathon-20261001-0003",
    total_amount="88.00",
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
  )
}
```

### Alipay: async notification

```moonbit
///|
async fn handle_alipay_notify(
  alipay : @alipay.Client,
  params : Map[String, String], // the parsed form body of the POST
) {
  // Verifies the RSA2 signature over the notification parameters.
  let notify = alipay.verify_notify(params)
  if notify.trade_status == "TRADE_SUCCESS" {
    // Payment confirmed — update your own order storage here.
  }
  // Respond with the plain text "success" so Alipay stops retrying.
}
```

## Architecture

```
your MoonBit application
          │
moon-pay-sdk
├── wechat      Native / H5 payment, order query, callback verify & decrypt
├── alipay      page / wap payment, order query, async notification verify
├── crypto      thin OpenSSL FFI: RSA-SHA256 sign & verify, AES-256-GCM decrypt
└── transport   HTTPS over moonbitlang/async (epoll on Linux, kqueue on macOS)
          │
system dependencies
├── moonbitlang/async runtime
└── OpenSSL (TLS, RSA, AES)
```

Design notes:

- **Async runtime and transport** — HTTP/HTTPS requests go through
  [`moonbitlang/async`](https://mooncakes.io/docs/#/moonbitlang/async), whose
  TLS support is based on OpenSSL. The library is experimental; the SDK pins a
  known-good version.
- **Crypto via OpenSSL FFI** — request signing (RSA-SHA256), signature
  verification and callback decryption (AES-256-GCM) call OpenSSL through thin
  C bindings. Reusing the one C dependency the async runtime already links
  keeps the native build simple, and leaves payment-grade correctness to a
  battle-tested implementation instead of hand-rolled crypto.
- **Native only** — merchant private keys belong on servers, so the SDK
  targets the native backend and produces a self-contained binary.

## Roadmap

- **Hackathon release** — the feature set listed under [Features](#features)
- **Next** — refunds (WeChat v3, `alipay.trade.refund`), bill download, JSAPI
  / mini-program payments, platform-certificate auto refresh, integration
  tests against provider sandboxes

## License

[MIT](LICENSE)
