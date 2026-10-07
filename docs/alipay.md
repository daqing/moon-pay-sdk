# Alipay Guide

Everything implemented in moon-pay-sdk for Alipay (OpenAPI): the modules,
how to use them, and the `ALIPAY_*` environment variables the bundled
webdemo reads. The Chinese edition of this document is
[`docs/alipay.zh-CN.md`](alipay.zh-CN.md).

## Feature matrix

| Capability | Where | Status |
| --- | --- | --- |
| Page payment (desktop website) | `alipay` | implemented — `Client::page_pay_url` (`alipay.trade.page.pay`) |
| Wap payment (mobile website) | `alipay` | implemented — `Client::wap_pay_url` (`alipay.trade.wap.pay`) |
| Order query | `alipay` | implemented — `Client::query_order` (`alipay.trade.query`) |
| Async notification handling | `alipay` | implemented — `Client::verify_notify` (RSA2 signature + app_id ownership) |
| Return-redirect verification | `alipay` | implemented — `Client::verify_return_params` |
| Signing integration mode | — | **public-key mode (公钥模式) only**; certificate mode (`app_cert_sn`/`alipay_root_sn`) is not supported |
| Integration-test web app | `cmd/webdemo` | bundled — real-gateway manual testing |

Not implemented yet: refunds (`alipay.trade.refund`), bill download,
transfers. See the root README's roadmap.

## Modules

| Module | Role |
| --- | --- |
| `daqing/moon-pay-sdk/alipay` | The Alipay OpenAPI client: page/wap order URLs, order query, async-notification and return-redirect verification, RSA2 request signing |
| `daqing/moon-pay-sdk/crypto` | RSA-SHA256 sign/verify (pure MoonBit) |
| `daqing/moon-pay-sdk/transport` | HTTPS over moonbitlang/async (epoll on Linux, kqueue on macOS); a `MockTransport` for tests |
| `cmd/webdemo` | A local web app for manual integration testing against the real gateway — the source of the `ALIPAY_*` variables below |

Install and import:

```bash
moon add daqing/moon-pay-sdk
```

```text
// moon.pkg
import {
  "daqing/moon-pay-sdk/alipay",
}
```

## Getting started

Build the client once at startup:

```moonbit nocheck
///|
async fn main {
  let alipay = @alipay.Client::new(
    config=@alipay.Config::new(
      app_id="2021000000000000",
      private_key_pem~, // YOUR application private key, PEM text
      alipay_public_key_pem~, // the Alipay public key, PEM text
    ),
    transport=@transport.HttpClient::new(),
  )
}
```

Three values, three different owners — mixing them up is the single most
common Alipay mistake:

- `app_id` — the open-platform **web application** id (`2021…`, 16 digits).
- `private_key_pem` — the **application private key** you generated with the
  Alipay key tool (密钥工具), whose public half you uploaded to the console.
- `alipay_public_key_pem` — the **Alipay public key** (支付宝公钥) the console
  displays once your application public key is uploaded. This is Alipay's
  own key, **not** the public half of your key pair.

Both PEM arguments are text, not file paths — read files yourself (e.g.
`@fs.read_to_string`) before constructing. PEM inputs must carry the
`-----BEGIN/END-----` headers; the raw headerless base64 the console's copy
button yields does not parse (see
[Converting raw keys](#converting-raw-console-keys-to-pem)).

The console's 接口加签方式 must be **公钥模式** — the SDK has no
`app_cert_sn`/`alipay_root_sn` fields, so 公钥证书 (certificate mode) cannot
work. For production charges the 电脑网站支付 / 手机网站支付 product must be
signed (需企业/个体工商户资质) and the application released (已上线).

## Payment methods

Both methods produce a **signed redirect URL** — no gateway call happens at
order time; the trade is created when the customer's browser reaches the
cashier.

### Page payment (desktop website)

```moonbit nocheck
///|
fn page_checkout(alipay : @alipay.Client) -> Unit raise {
  let url = alipay.page_pay_url(
    out_trade_no="order-20261007-0001",
    total_fen=8800, // integer fen: 8800 = CNY 88.00
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
    return_url="https://example.com/thanks",
  )
  // Redirect the customer's browser to `url`.
}
```

The SDK sends `product_code=FAST_INSTANT_TRADE_PAY` (the official demo
form). After paying, Alipay redirects the browser back to `return_url`,
appending signed GET parameters — display only; see
[Return-redirect verification](#return-redirect-verification).

### Wap payment (mobile website)

```moonbit nocheck
///|
fn wap_checkout(alipay : @alipay.Client) -> Unit raise {
  let url = alipay.wap_pay_url(
    out_trade_no="order-20261007-0002",
    total_fen=8800,
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
  )
  // Redirect the customer's mobile browser to `url`.
}
```

`product_code=QUICK_WAP_WAY` is sent.

## Order query

Poll from the page, or reconcile a notify that never arrived:

```moonbit nocheck
///|
async fn reconcile(alipay : @alipay.Client) -> Unit raise {
  let status = alipay.query_order(out_trade_no="order-20261007-0001")
  if status.trade_status() is @alipay.TradeSuccess {
    println("paid \{status.total_fen()} fen")
  }
}
```

`TradeStatus` covers `WaitBuyerPay` / `TradeClosed` / `TradeSuccess` /
`TradeFinished`, plus `Unknown(String)` for future ones. A query for an
order that was never created at Alipay raises an `Api` error
(`40004` / 交易不存在) — expected for unpaid redirect URLs, not a signing
problem.

The sync response is verified against the Alipay public key over the
verbatim `alipay_trade_query_response` member before its fields are
trusted.

## Async notification handling

Alipay POSTs a urlencoded form to your `notify_url` after the trade settles.
Verify the RSA2 signature and the app_id ownership, reconcile the amount,
and answer the plain text `success` so Alipay stops retrying:

```moonbit nocheck
///|
fn handle_alipay_notify(
  alipay : @alipay.Client,
  form : Array[(String, String)], // the urlencoded body, parsed
) -> String {
  // Signature first, then the app_id this client answers for; raises on
  // any mismatch.
  let notify = alipay.verify_notify(form)
  if notify.trade_status() is @alipay.TradeSuccess
    && notify.amount_matches(8800) {
    // Signed, from Alipay, for this app, amount reconciled — mark the
    // order paid.
  }
  @alipay.ack_success() // -> "success"
}
```

Answer anything else (e.g. `failure`) and Alipay retries per its schedule.
`parse_form_params` is public if you need to split a raw body yourself.

## Return-redirect verification

The signed GET parameters Alipay appends to `return_url` verify with the
same machinery:

```moonbit nocheck
///|
fn handle_return(alipay : @alipay.Client, query : StringView) -> Unit raise {
  // e.g. query = "charset=utf-8&out_trade_no=...&total_amount=88.00&sign=..."
  let params = alipay.verify_return_params(query)
  // Read e.g. out_trade_no / trade_no for the thank-you page.
}
```

A redirect alone never proves payment — only the verified notify and the
query result do.

## Signing rules (as verified against production)

Maintainer-facing notes; callers don't need these, but they explain the
public helpers:

- **Outgoing requests** are signed over all parameters except `sign`,
  sorted by key, `k=v&…` — `sign_type` **included**
  (`build_request_sign_content`; `sign_params` uses it). The production
  gateway's invalid-signature error page prints its verification string,
  which carries `sign_type=RSA2`.
- **Incoming notifications and return redirects** verify over all
  parameters except `sign` and `sign_type` (`build_sign_content`).
- **Sync responses** verify over the verbatim `alipay_xxx_response` member
  text (`Client::verify_content`).
- Error responses arrive in **GBK** regardless of the request charset;
  bodies decode lossily so the ASCII `code`/`sub_code` stay readable.

## Environment variables (`ALIPAY_*`)

These configure `cmd/webdemo`, the bundled integration-test web app (the
Alipay page, `http://127.0.0.1:1943/alipay`). The SDK itself takes
credentials through `Config` — no environment involved. Copy
`cmd/webdemo/env.example.sh` to `cmd/webdemo/env.sh` (gitignored), fill it
in, then `source cmd/webdemo/env.sh && moon run cmd/webdemo`.

| Variable | Required | Meaning |
| --- | --- | --- |
| `ALIPAY_APPID` | yes | Open-platform web-application id, e.g. `2021…` |
| `ALIPAY_PRIVATE_KEY` | yes | Application private key (RSA2 from the key tool): PEM text, or a path to the PEM file |
| `ALIPAY_PUBLIC_KEY` | yes | The **Alipay public key** shown in the console under 接口加签方式 → 公钥模式 — PEM text, or a path to the PEM file |
| `ALIPAY_GATEWAY_URL` | no | Gateway, default `https://openapi.alipay.com/gateway.do`; point it at the sandbox gateway when using sandbox credentials |
| `ALIPAY_NOTIFY_URL` | no | Notify URL Alipay POSTs to; defaults to a placeholder |

### What each value must be

| Variable | Must be | Must not be |
| --- | --- | --- |
| `ALIPAY_PRIVATE_KEY` | The application private key from the Alipay key tool, pairing with the public key uploaded to the console | The Alipay public key |
| `ALIPAY_PUBLIC_KEY` | The **Alipay public key** the console displays once your application public key is uploaded | Your own application public key, or the application private key — the most common Alipay mistake |

`bash cmd/webdemo/diagnose.sh` mechanically checks readability, parsing,
key size and the swapped/own-key mistakes, without printing key material.

### Converting raw console keys to PEM

The console's and the key tool's copy buttons yield **raw base64 without
`-----BEGIN/END-----` headers** — neither OpenSSL nor this SDK parses that.
Wrap it (macOS):

```bash
fold -w 64 private_key.txt | awk '{print}' | {
  printf -- '-----BEGIN PRIVATE KEY-----\n'; cat; printf -- '-----END PRIVATE KEY-----\n'
} > private_key.pem
```

The `awk` guarantees the trailing newline before `-----END…-----` (the raw
copy has none, so a bare `fold` glues the header onto the last base64
line). The Alipay public key wraps the same way with
`-----BEGIN/END PUBLIC KEY-----`.

## Troubleshooting

- **`40002 invalid-signature`** on the first real request — the gateway
  found the app but the application public key registered in the console
  does not pair with `ALIPAY_PRIVATE_KEY`. Re-upload the application public
  key derived from that private key
  (`openssl pkey -in <private_key.pem> -pubout`), and confirm the console's
  接口加签方式 is 公钥模式 — certificate mode answers invalid-signature too
  and is unsupported.
- **Cashier page `订单信息无法识别 / INVALID_PARAMETER` or
  `errorCode=FISHING_RISK`** — the signature was accepted but the trade
  cannot be created for this app: the application must be released
  (已上线, not 开发中) and 电脑网站支付 signed (商家平台 → 产品中心 →
  我的产品; requires business qualification). For flow testing without a
  signed product, use the sandbox: sandbox credentials plus
  `ALIPAY_GATEWAY_URL=https://openapi-sandbox.dl.alipaydev.com/gateway.do`.
- **`40004 交易不存在`** on query — normal for an order whose cashier URL
  was never opened/paid; the signature is fine.
- **Server log shows mojibake in error messages** — Alipay answers error
  bodies in GBK; the SDK decodes lossily and the readable part is the ASCII
  `code`/`sub_code`.
