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
and the pure-MoonBit cryptography of
[`moonbitstack/mooncrypt`](https://mooncakes.io/docs/#/moonbitstack/mooncrypt).

> **Status**: v0.1.0 implements everything under [Features](#features); the
> code samples compile against the shipped API.

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
- OpenSSL — loaded at runtime by moonbitlang/async for TLS transport
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

```moonbit nocheck
///|
async fn main {
  let wechat = @wechat.Client::new(
    config=@wechat.Config::new(
      appid="wx8888888888888888",
      mchid="1900000000",
      serial_no="YOUR-CERT-SERIAL",
      private_key_pem~, // PEM text, loaded once at startup
      api_v3_key="YOUR-32-CHARACTER-APIV3-KEY",
    ),
    transport=@transport.HttpClient::new(),
  )

  // Native payment: render order.code_url() as a QR code.
  let order = wechat.native_order(
    out_trade_no="hackathon-20261001-0001",
    total=100, // in fen: 100 = CNY 1.00
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
  )
  println("QR content: \{order.code_url()}")

  // Callbacks can get lost — query to reconcile.
  let paid = wechat.query_order(out_trade_no="hackathon-20261001-0001")
  if paid.trade_state() is @wechat.Success {
    println("paid \{paid.total_fen()} fen")
  }
}
```

### WeChat Pay: callback

```moonbit nocheck
///|
async fn handle_wechat_callback(
  wechat : @wechat.Client,
  headers : Array[(String, String)],
  body : Bytes,
) -> (Int, String) {
  // Verifies the WeChat Pay signature (replay window included), decrypts the
  // AES-256-GCM resource and returns the parsed payment result.
  let notification = wechat.verify_callback(headers, body)
  if notification.trade_state() is wechat.Success {
    // notification.out_trade_no() is paid — update your own order storage.
    @wechat.ack_success()
  } else {
    @wechat.ack_failure(message="processing failed")
  }
}
```

### Alipay: page / wap checkout

```moonbit nocheck
///|
async fn main {
  let alipay = @alipay.Client::new(
    config=@alipay.Config::new(
      app_id="2021000000000000",
      private_key_pem~, // your application private key, PEM
      alipay_public_key_pem~, // for verifying notifications
    ),
    transport=@transport.HttpClient::new(),
  )

  // Desktop website checkout: redirect the customer to this URL.
  let url = alipay.page_pay_url(
    out_trade_no="hackathon-20261001-0002",
    total_fen=8800, // 8800 fen = CNY 88.00
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
    return_url="https://example.com/thanks",
  )
  println("Checkout URL: \{url}")

  // Mobile website checkout works the same way.
  let wap_url = alipay.wap_pay_url(
    out_trade_no="hackathon-20261001-0003",
    total_fen=8800,
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
  )
}
```

### Alipay: async notification

```moonbit nocheck
///|
async fn handle_alipay_notify(
  alipay : @alipay.Client,
  form : Array[(String, String)], // the urlencoded body of the POST
) -> String {
  // Verifies the RSA2 signature, then the app_id ownership.
  let notify = alipay.verify_notify(form)
  if notify.trade_status() is @alipay.TradeSuccess
    && notify.amount_matches(8800) {
    // Signed, from Alipay, and the amount matches — mark the order paid.
  }
  // Respond with the plain text "success" so Alipay stops retrying.
  @alipay.ack_success()
}
```

## Architecture

```
your MoonBit application
          │
moon-pay-sdk
├── wechat      Native / H5 payment, order query, callback verify & decrypt
├── alipay      page / wap payment, order query, async notification verify
├── crypto      RSA-SHA256 sign & verify, X.509 parsing, AES-256-GCM (mooncrypt)
└── transport   HTTPS over moonbitlang/async (epoll on Linux, kqueue on macOS)
          │
system dependencies
├── moonbitlang/async runtime
└── OpenSSL (TLS transport, loaded at runtime by moonbitlang/async)
```

Design notes:

- **Async runtime and transport** — HTTP/HTTPS requests go through
  [`moonbitlang/async`](https://mooncakes.io/docs/#/moonbitlang/async), whose
  TLS support is based on OpenSSL. The library is experimental; the SDK pins a
  known-good version.
- **Crypto via mooncrypt** — request signing (RSA-SHA256), signature
  verification and callback decryption (AES-256-GCM) use the pure-MoonBit
  crypto stack [`moonbitstack/mooncrypt`](https://mooncakes.io/docs/#/moonbitstack/mooncrypt)
  (algorithms), `moonbitstack/mooncred` (X.509 certificates) and
  `moonbitstack/moonbase` (base16/base64), all tested against specification
  vectors. No hand-rolled crypto and no OpenSSL C FFI of our own; the test
  suite additionally cross-checks signature outputs against
  `openssl`-generated reference signatures.
- **Native only** — merchant private keys belong on servers, so the SDK
  targets the native backend and produces a self-contained binary.

## Roadmap

- **Hackathon release** — the feature set listed under [Features](#features)
- **Next** — refunds (WeChat v3, `alipay.trade.refund`), bill download, JSAPI
  / mini-program payments, platform-certificate auto refresh, integration
  tests against provider sandboxes

## License

[MIT](LICENSE)
