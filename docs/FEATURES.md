# Feature Matrix

Everything `moon-pay-sdk` implements today, per provider and per package.
This page is the authoritative list of what is **implemented**; the
“Not implemented” section at the end lists what is deliberately out of scope.

- **Version:** 0.10.0
- **Target:** MoonBit native (no JavaScript bridge, no interpreter)
- **Scope:** server-side acquiring — ordering, order query, asynchronous
  notification handling
- **Companion guides:** [WeChat Pay](wechat.md), [Alipay](alipay.md)

## Packages

| Package | Responsibility |
| --- | --- |
| `daqing/moon-pay-sdk` | Shared types: `SdkError` / `ApiError`, JSON helpers, amount and out-trade-number validation |
| `daqing/moon-pay-sdk/wechat` | WeChat Pay API v3 client: Native / H5 / JSAPI ordering, order query, callback verification and decryption, request signing, platform certificate / public-key management |
| `daqing/moon-pay-sdk/miniprogram` | Mini-Program server flow: `wx.login` code → openid exchange, plus one-call ordering with `wx.requestPayment` parameters |
| `daqing/moon-pay-sdk/alipay` | Alipay OpenAPI client: page / wap checkout URLs, order query, async notification and return-redirect verification, RSA2 request signing |
| `daqing/moon-pay-sdk/crypto` | RSA-SHA256 sign/verify, PEM key loading, X.509 parsing, AES-256-GCM decryption, secure random |
| `daqing/moon-pay-sdk/transport` | `Transport` trait over `moonbitlang/async` HTTPS, plus a scriptable `MockTransport` for offline tests |

## WeChat Pay (API v3)

| Capability | Public API | Gateway endpoint | Source |
| --- | --- | --- | --- |
| Native (QR) order | `Client::native_order` | `POST /v3/pay/transactions/native` | `wechat/native.mbt` |
| H5 order (mobile browser) | `Client::h5_order` | `POST /v3/pay/transactions/h5` | `wechat/h5.mbt` |
| JSAPI order (inside WeChat) | `Client::jsapi_order` | `POST /v3/pay/transactions/jsapi` | `wechat/jsapi.mbt` |
| `wx.requestPayment` parameter set | `Client::jsapi_pay_params` | local signing | `wechat/jsapi.mbt` |
| Query by merchant order number | `Client::query_order` | `GET /v3/pay/transactions/out-trade-no/{no}?mchid=…` | `wechat/query.mbt` |
| Query by WeChat transaction id | `Client::query_order_by_id` | `GET /v3/pay/transactions/id/{id}?mchid=…` | `wechat/query.mbt` |
| Callback verify + decrypt + parse | `Client::verify_callback`, `Client::parse_notification` | local | `wechat/callback.mbt`, `wechat/notification.mbt` |
| Standalone callback signature check | `Client::verify_callback_signature` | local | `wechat/callback_sig.mbt` |
| Request signing / `Authorization` header | `build_sign_message`, `sign_request`, `authorization_header` | local | `wechat/auth.mbt` |
| Platform certificate download / decrypt / cache | `Client::refresh_platform_certs`, `Client::platform_public_key` | `GET /v3/certificates` | `wechat/certs.mbt` |
| Callback acknowledgement | `ack_success()`, `ack_failure(message~)` | local | `wechat/ack.mbt` |

### Ordering

All three order types return typed results and share the same request path:

- **Native** returns `NativeOrder::code_url()` — render it as a QR code.
- **H5** returns `H5Order::h5_url()` — redirect the mobile browser. It requires
  `payer_client_ip` and sends `scene_info` with `scene_type="H5"`.
- **JSAPI** returns `JsapiOrder::prepay_id()`. `jsapi_pay_params` then produces
  `JsapiPayParams` with `app_id`, `timestamp`, `nonce_str`, `pay_package`
  (`prepay_id=…`), `sign_type="RSA"` and `pay_sign`.

The `paySign` is RSA-SHA256 over the canonical four-line form:

```text
appId
timeStamp
nonceStr
package
```

The trailing newline is part of the signed message.

Amounts are integer fen (`total`), and order numbers are validated before any
request is sent.

### Order query

`OrderStatus` carries `out_trade_no`, `transaction_id` (present only after
the payment succeeded — unpaid orders answer without it), `trade_state`,
`total_fen`, optional `payer_fen` and optional `success_time`.

`TradeState` covers every documented state — `SUCCESS`, `REFUND`, `NOTPAY`,
`CLOSED`, `REVOKED`, `USERPAYING`, `PAYERROR` — plus `Unknown(String)` so a new
provider state never breaks an upgrade.

### Callback handling

`verify_callback(headers, body)` performs, in order:

1. Case-insensitive extraction of `Wechatpay-Serial`, `Wechatpay-Timestamp`,
   `Wechatpay-Nonce`, `Wechatpay-Signature`; all four are required.
2. Replay-window check on the timestamp (default ±300 seconds, configurable via
   `verify_callback_signature(window_seconds=…)`).
3. RSA-SHA256 verification of `timestamp\nnonce\nbody\n` under the platform key
   named by the serial.
4. AES-256-GCM decryption of `resource` with the APIv3 key and its
   `associated_data` as AAD.
5. Typed `Notification` extraction: `event_type`, `summary`, `out_trade_no`,
   `transaction_id`, `trade_state`, `total_fen`, `payer_fen`, plus the whole
   decrypted JSON in `resource()`.

Reply with `ack_success()` (HTTP 200, `{"code":"SUCCESS",…}`) or
`ack_failure(message~)` (HTTP 500, `{"code":"FAIL",…}`) so WeChat retries when
processing failed.

### Signature modes

Two modes are supported and configured on `wechat.Config`:

- **Public-key mode** — set `platform_public_key_pem` and
  `platform_public_key_id` (`PUB_KEY_ID_...`). Nothing is downloaded at
  runtime. Setting only one of the two is rejected by `Config::validate`.
- **Certificate mode** — leave both empty. Platform certificates are fetched
  from `/v3/certificates`, decrypted with the APIv3 key, and cached by
  lowercase serial. An unknown `Wechatpay-Serial` triggers one automatic
  refresh.

Successful API responses are signature-verified by default; pass
`verify_responses=false` to `Client::new` to disable it. The certificate
download itself is always exempt, because the key it would verify against is
only arriving in that response.

### Configuration validation

`wechat.Config::validate` rejects, before any network call:

- empty `appid`, `mchid`, `serial_no`, `private_key_pem`;
- an `api_v3_key` that is not exactly 32 characters;
- a `base_url` that is neither `https://` nor `http://`;
- `platform_public_key_pem` / `platform_public_key_id` set without each other;
- unparsable platform public-key PEM;
- stray leading/trailing whitespace in `appid`, `mchid`, `serial_no`.

## Mini-Program (`miniprogram`)

| Capability | API | Endpoint / behaviour |
| --- | --- | --- |
| Exchange a login code | `Client::code2session` | `GET /sns/jscode2session`, returns `Session` (`openid`, `session_key`, optional `unionid`) |
| One-call payment | `Client::pay` | code → openid → JSAPI order → pay params |
| Order with a known openid | `Client::pay_with_openid` | skips the exchange |
| Result type | `PayResult` | `openid`, `out_trade_no`, `prepay_id`, `pay_params` |

`Client::new` requires `miniprogram.Config.app_id` to equal the pay client's
`appid`; a mismatch is rejected because an openid is only valid under the appid
that issued it. Business `errcode`s from the login API become `SdkError::Api`.
Transport failures do not echo the underlying error text, because the request
URL contains the app secret.

## Alipay (OpenAPI)

| Capability | Public API | API method / behaviour | Source |
| --- | --- | --- | --- |
| Desktop website payment | `Client::page_pay_url` | `alipay.trade.page.pay`, `FAST_INSTANT_TRADE_PAY` | `alipay/pay.mbt` |
| Mobile website payment | `Client::wap_pay_url` | `alipay.trade.wap.pay`, `QUICK_WAP_WAY` | `alipay/pay.mbt` |
| Order query | `Client::query_order` | `alipay.trade.query`, form POST | `alipay/query.mbt` |
| Async notification verification | `Client::verify_notify` | local RSA2 verification + `app_id` ownership | `alipay/notify.mbt` |
| Return-redirect verification | `Client::verify_return_params` | local, same canonical rules | `alipay/notify.mbt` |
| Amount reconciliation | `NotifyResult::amount_matches` | local | `alipay/notify.mbt` |
| Notification acknowledgement | `ack_success()` → `"success"` | local | `alipay/ack.mbt` |
| Parameter / signing engine | `system_params`, `sign_params`, `sign_content`, `build_request_sign_content`, `build_sign_content` | local | `alipay/params.mbt` |
| URL encoding / form parsing | `build_pay_url`, `percent_encode`, `percent_decode`, `parse_form_params` | local | `alipay/url.mbt` |
| Beijing timestamp formatting | `format_beijing` | local | `alipay/params.mbt` |

### Checkout links

Both checkout helpers are **local** — no gateway call is made while creating the
order; the transaction is created when the customer's browser reaches the
cashier.

- `page_pay_url(out_trade_no~, total_fen~, subject~, notify_url~, return_url~)`
  returns the signed desktop checkout URL and always carries `return_url`.
- `wap_pay_url(out_trade_no~, total_fen~, subject~, notify_url~)` returns the
  signed mobile checkout URL and carries no `return_url`.

Amounts enter as integer fen and leave as two-decimal yuan strings (`88.00`).

### Order query

`OrderStatus` carries `out_trade_no`, `trade_no`, `trade_status`,
`total_amount`, `total_fen` and optional `send_pay_date`.

`TradeStatus` covers `WAIT_BUYER_PAY`, `TRADE_CLOSED`, `TRADE_SUCCESS`,
`TRADE_FINISHED`, plus `Unknown(String)` with `is_unknown()`.

The response is only trusted after the `alipay_trade_query_response` member has
been verified **verbatim** against the Alipay public key. Error responses are
GBK regardless of the request charset; the body is decoded lossily so the ASCII
`code` / `sub_code` stay readable.

### Notifications and return redirects

`verify_notify(form)`:

1. Percent-decodes every key and value.
2. Requires a `sign` parameter.
3. Verifies the RSA2 signature over the canonical form (all parameters except
   `sign` and `sign_type`, sorted by key, joined as `k=v&…`).
4. Requires `app_id` to equal this client's `app_id`.
5. Returns `NotifyResult` with `trade_status`, `out_trade_no`, `trade_no`,
   `total_amount`, `total_fen`, `app_id`, optional `seller_id` and the decoded
   raw parameters.

Call `amount_matches(expected_fen)` before marking an order paid — the
signature proves the sender, not that the notification belongs to this order.
`verify_return_params(query)` applies the same signature and ownership checks
to the `return_url` GET parameters.

### Signing rules

The two directions use different canonical strings, matching production gateway
behaviour:

- **Outgoing requests:** every parameter except `sign` is sorted and joined,
  and **`sign_type` is included** (`build_request_sign_content`, used by
  `sign_params`).
- **Incoming notifications / return redirects:** every parameter except `sign`
  and `sign_type` is sorted and joined (`build_sign_content`).
- **Synchronous responses:** the `alipay_xxx_response` member is verified
  **verbatim**, never re-serialized (`Client::verify_content`).

Sorting is byte-order ASCII, implemented locally rather than relying on a
generic string comparison that orders by length first.

Only **public-key mode** is supported. There are no `app_cert_sn` /
`alipay_root_sn` fields, so the public-key certificate signing mode cannot be
used.

## Shared foundation

| Area | Capability |
| --- | --- |
| `crypto` | PEM private/public key loading, SPKI DER parsing, X.509 certificate parsing and serial extraction, RSA-SHA256 sign/verify, AES-256-GCM decryption, secure random bytes / hex |
| `transport` | `Transport` trait; `HttpClient` on `moonbitlang/async` HTTPS; `MockTransport` that records requests and replays scripted responses |
| Errors | `SdkError` with `Api(ApiError)`, `Network(String)`, `Crypto(CryptoError)`, `Config(String)`; readable rendering |
| JSON | `parse_json`, `try_parse_json`, `encode_json`, typed field readers (`string_field`, `int_field`, `object_field`, `array_field`, `bool_field`) |
| Money | `format_yuan`, `parse_yuan_fen`, `validate_amount_fen` |
| Order numbers | `validate_wechat_out_trade_no`, `validate_alipay_out_trade_no` |

Validation rules:

- WeChat `out_trade_no`: 6–32 characters, letters, digits and `-_|*`.
- Alipay `out_trade_no`: 1–64 characters, letters, digits, `_` and `-`.
- Amounts must be a positive integer number of fen.
- Yuan strings must have exactly two decimals; anything else is rejected rather
  than silently rounded.

## Testing and tooling

- **131 test blocks** across unit, white-box and end-to-end suites, including
  `openssl`-generated golden signature vectors.
- **Loopback end-to-end tests** (`e2e/`): WeChat “order → signed callback →
  verify + decrypt → acknowledge” and Alipay “signed redirect → signed
  notification → verify → acknowledge”, plus security negative cases (replay,
  unknown serial, tampered signature/body, wrong APIv3 key, amount mismatch).
- **`cmd/webdemo`** — a local integration web app on port 1943 with WeChat
  Native / JSAPI / Mini-Program panels, an Alipay panel, notification endpoints
  `/api/wechat/notify` and `/api/alipay/notify`, and `GET /api/config`. It is
  driven by `WXPAY_*` / `ALIPAY_*` environment variables and ships
  `diagnose.sh`.
- **`cmd/sandbox`** — environment-guarded Alipay sandbox smoke check that only
  builds a signed redirect URL for manual visiting.
- **`examples/payment_demo`** — runnable demo against a local mock provider; no
  real money can move.

## Not implemented

The following are intentionally out of scope for the current version:

- **Refunds** — WeChat `/v3/refund/domestic/refunds`, Alipay
  `alipay.trade.refund`, refund query, and refund notifications.
- **Order closing** — WeChat close-order and `alipay.trade.close`.
- **Bill / statement download** for both providers.
- **Transfers**, **profit sharing**, **coupons / red packets**.
- **WeChat APP pay, micropay (offline barcode), combined orders, and
  service-provider / sub-merchant mode.**
- **Alipay APP pay** and products other than page / wap pay.
- **Alipay public-key certificate signing mode** (`app_cert_sn` /
  `alipay_root_sn`).
- **Scheduled platform-certificate rotation** — certificates are refreshed only
  when an unknown serial is seen.
- Helper APIs such as query-by-refund-id or trade close.

## Documentation accuracy

`docs/wechat.md`, `docs/wechat.zh-CN.md`, `docs/alipay.md` and
`docs/alipay.zh-CN.md` track the shipped API. The examples in the root
`README.md` / `README.zh-CN.md` still use some `v0.1.0`-era names
(`private_key_path`, string `total_amount`); prefer the guides and this matrix
when in doubt.
