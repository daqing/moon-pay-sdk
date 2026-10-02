# Changelog

## v0.1.1

- Documentation release: both READMEs now compile their code samples against
  the shipped API, and the runnable payment demo lives in
  `examples/payment_demo` (`moon run examples/payment_demo`).
- Adds a bilingual 5-minute demo script, the v0.1.0 release notes and the
  guarded Alipay sandbox smoke check (`cmd/sandbox`).
- v0.1.0 itself was already taken on mooncakes.io, hence this version bump.

## v0.1.0 — hackathon release

The first release of moon-pay-sdk: a native MoonBit SDK covering the core
acquiring flow of WeChat Pay (API v3) and Alipay, built for the MoonBit
native backend.

### WeChat Pay (API v3)

- Native (QR) and H5 orders, amounts in integer fen
- Order query by out-trade number or transaction id, with a typed
  `TradeState` covering all documented states plus `Unknown` for future ones
- Platform certificate manager: download, APIv3-key decryption and caching,
  with automatic refresh on unknown `Wechatpay-Serial`
- Callback verification (signature, replay window) and AES-256-GCM payload
  decryption into a typed `Notification`
- API response signature verification on successful calls
- `ack_success` / `ack_failure` acknowledgement helpers

### Alipay (OpenAPI)

- `alipay.trade.page.pay` and `alipay.trade.wap.pay` signed redirect URLs,
  amounts as two-decimal yuan strings
- `alipay.trade.query` with response signature verification over the
  verbatim response member and a typed `TradeStatus`
- Async notification verification (signature plus app_id ownership) with
  amount reconciliation against the local order, and `return_url` parameter
  verification
- Plain-text `success` acknowledgement helper

### Shared foundation

- RSA-SHA256 signing and verification, X.509 parsing and AES-256-GCM
  decryption via the pure-MoonBit crypto stack (mooncrypt, mooncred,
  moonbase) — no hand-rolled crypto, no custom C FFI
- `Transport` interface over `moonbitlang/async` HTTP(S) with a scriptable
  mock, so every client behaviour is testable offline
- Typed `SdkError` hierarchy (api / network / crypto / config) with readable
  rendering
- 117 tests including openssl cross-validated golden vectors, end-to-end
  loopback tests over real HTTP and consolidated security negative cases
