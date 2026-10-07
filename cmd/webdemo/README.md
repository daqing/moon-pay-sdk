# webdemo — WeChat Pay & Alipay integration-check web app

A minimal web app that exercises `daqing/moon-pay-sdk`'s WeChat Pay Native
(QR) checkout and Alipay page (desktop website) checkout against the **real**
gateways. It exists for manual integration testing: open the page, pay, and
watch an order travel the SDK's real signing, query and callback-verification
paths.

The server listens on port **1943** and serves one page per gateway; a page
is enabled only when its gateway's credentials are configured (each page asks
`GET /api/config` at load):

1. **`/` — WeChat · Native (QR)** — creates a Native order
   (`POST /api/orders`) through `Client::native_order`, renders the returned
   `code_url` as a QR code, polls the order
   (`GET /api/orders/<out_trade_no>`) through `Client::query_order` every two
   seconds, and accepts WeChat Pay's signed callback
   (`POST /api/wechat/notify`) through `Client::verify_callback`, reconciling
   the amount and acknowledging it. The page also has a JSAPI section:
   `POST /api/wechat/jsapi/orders?amount_yuan=…&openid=…` places an in-WeChat
   order through `Client::jsapi_order` and returns the signed
   `wx.requestPayment` parameter set (`Client::jsapi_pay_params`) — paste it
   into the WeChat devtools or drive it from a mini-program backend; the
   order polls through the same endpoint. With `WXPAY_APP_SECRET` set the
   page also gains a mini-program section:
   `POST /api/wechat/miniapp/orders?amount_yuan=…&js_code=…` exchanges the
   `wx.login` code for the payer's openid and places the order in one call
   (`miniprogram.Client::pay`), returning the same signed parameter set.
2. **`/alipay` — Alipay · page pay** — builds the signed cashier URL
   (`POST /api/alipay/orders`, `alipay.trade.page.pay`) through
   `Client::page_pay_url` and redirects the browser to it; when Alipay sends
   the customer back to `/alipay?alipay_order=<out_trade_no>` the page
   resumes polling through `GET /api/alipay/orders/<out_trade_no>`; and
   accepts Alipay's async notification (`POST /api/alipay/notify`) through
   `Client::verify_notify`, answering the plain-text `success` that stops
   Alipay's retries.

Polling works from a laptop without a public hostname; the notify endpoints
exercise the full callback path whenever the gateways can reach the
configured notify URLs.

## Configuration

All credentials come from the environment, so nothing secret lives in the
repository. The app reads `WXPAY_*` and `ALIPAY_*` variables from the shell
it is launched from — export them directly, or source a filled-in copy of the
bundled template (recommended; `cmd/webdemo/env.sh` is gitignored):

```bash
cp cmd/webdemo/env.example.sh cmd/webdemo/env.sh
$EDITOR cmd/webdemo/env.sh          # fill in real gateway credentials
source cmd/webdemo/env.sh && moon run cmd/webdemo
```

The app starts when **at least one** gateway's required variables are
complete and disables the other page. Each incomplete configuration is
printed at startup, and no request is ever sent to a gateway whose
configuration is incomplete.

### WeChat Pay (`WXPAY_*`)

| Environment variable | Required | Meaning |
| --- | --- | --- |
| `WXPAY_APPID` | yes | Merchant app id, e.g. `wx1a2b3c4d5e6f7g8h` |
| `WXPAY_MCHID` | yes | Merchant id |
| `WXPAY_SERIAL_NO` | yes | Serial number of the merchant API certificate |
| `WXPAY_PRIVATE_KEY` | yes | The API-certificate private key: PEM text, or a path to the PEM file |
| `WXPAY_API_V3_KEY` | yes | The APIv3 key used for callback payload decryption |
| `WXPAY_BASE_URL` | no | Gateway base URL (default: `https://api.mch.weixin.qq.com`) |
| `WXPAY_PUBLIC_KEY` | no | Public-key mode: the WeChat Pay public key downloaded from the merchant console (`pub_key.pem`), PEM text or file path |
| `WXPAY_PUBLIC_KEY_ID` | no | Public-key mode: the `PUB_KEY_ID_…` serial shown next to it — set both or neither |
| `WXPAY_NOTIFY_URL` | no | Callback URL sent with every order; defaults to a placeholder |
| `WXPAY_APP_SECRET` | no | Mini-program AppSecret (小程序 → 开发管理 → 开发设置); enables the mini-program pay panel, where the server exchanges `wx.login` codes for openids |

With `WXPAY_PUBLIC_KEY`/`WXPAY_PUBLIC_KEY_ID` set, signatures from WeChat are
verified against that key and no platform certificates are downloaded
(public-key mode, the default for new merchant accounts); without them,
certificate mode (`/v3/certificates`) is used.

### Alipay (`ALIPAY_*`)

| Environment variable | Required | Meaning |
| --- | --- | --- |
| `ALIPAY_APPID` | yes | Open-platform web-application id, e.g. `2021000000000000` |
| `ALIPAY_PRIVATE_KEY` | yes | The application private key (RSA2, created with the Alipay key tool): PEM text, or a path to the PEM file |
| `ALIPAY_PUBLIC_KEY` | yes | The **Alipay public key** (支付宝公钥) displayed in the open-platform console under 接口加签方式 → 公钥模式 — **not** your own application public key; PEM text, or a path to the PEM file |
| `ALIPAY_GATEWAY_URL` | no | Gateway base URL (default: `https://openapi.alipay.com/gateway.do`; point it at the sandbox gateway when using sandbox credentials) |
| `ALIPAY_NOTIFY_URL` | no | Notify URL Alipay POSTs to; defaults to a placeholder |

The SDK integrates in public-key mode (公钥模式) only: it has no
`app_cert_sn`/`alipay_root_sn` fields, so the console's signing method must
be 公钥模式, not 公钥证书. The 电脑网站支付 capability must be added to the
application, and charging for real requires business qualification plus a
reviewed, released application.

### What each value must be

Wrong values here are the most common cause of gateway rejections. Run
`bash cmd/webdemo/diagnose.sh` to mechanically check the whole configuration.

| Environment variable | Must be | Must not be |
| --- | --- | --- |
| `WXPAY_SERIAL_NO` | The merchant **API certificate** serial — 40 hex chars, from `apiclient_cert.pem` in the certificate zip, or 商户平台 → API安全 → **API证书** | A `PUB_KEY_ID_…` **public-key** serial |
| `WXPAY_PRIVATE_KEY` | `apiclient_key.pem` from the **same** certificate-zip request as that serial | `pub_key.pem` (that is the public key) or a self-generated key — WeChat looks the certificate up by the request's serial, so the private key must pair with it |
| `WXPAY_API_V3_KEY` | The 32-char APIv3 key set under 商户平台 → API安全 | The login password or the APIv2 key |
| `WXPAY_PUBLIC_KEY` | The console's **微信支付公钥** `pub_key.pem` (public-key mode) | Your own certificate's public key |
| `WXPAY_PUBLIC_KEY_ID` | The `PUB_KEY_ID_…` serial displayed next to `pub_key.pem` | The API certificate serial |
| `ALIPAY_PRIVATE_KEY` | The application private key from the Alipay key tool, pairing with the application public key uploaded to the console | The Alipay public key |
| `ALIPAY_PUBLIC_KEY` | The **Alipay public key** the console displays once the application public key is uploaded | Your own application public key, or the application private key — the most common Alipay mistake |

Notes:

- A mini-program appid also works for Native QR payment (no openid involved)
  as long as it is bound to the merchant id (商户平台 → 产品中心 → AppID账号管理).
  Starting payment *inside* a mini-program is JSAPI ordering, which the SDK
  does not implement yet.
- `SIGN_ERROR` is a signature-layer rejection that happens before the appid /
  product permission checks: the private key, the serial in the request, or
  the clock is wrong — it is not a permissions problem.
- An Alipay `40002 invalid-signature` on the first real request means the
  gateway found the app but the **application public key registered in the
  console** does not pair with `ALIPAY_PRIVATE_KEY`. Re-upload the
  application public key derived from that private key
  (`openssl pkey -in <private_key.pem> -pubout`), and check the console's
  接口加签方式 is 公钥模式 — 公钥证书 (certificate mode) also answers
  invalid-signature and is not supported by this SDK.
- A cashier page answering `订单信息无法识别 / INVALID_PARAMETER` (or
  redirecting to `errorCode=FISHING_RISK`) means the signature was accepted
  but the trade cannot be created for this app: the app must be released
  (已上线, not 开发中) and 电脑网站支付 must be signed (商家平台 → 产品中心 →
  我的产品; requires business qualification). For flow testing without a
  signed product, use the sandbox: sandbox credentials plus
  `ALIPAY_GATEWAY_URL=https://openapi-sandbox.dl.alipaydev.com/gateway.do`.

### Alipay return URL

`page_pay_url` requires a `return_url`. The webdemo derives it from the
request's `Host` header as `http://<host>/alipay?alipay_order=<out_trade_no>`,
so after paying, the browser lands back on the Alipay page and resumes polling
that order. Alipay appends its signed GET parameters to this URL; the demo
ignores them and trusts only `query_order` and the verified `notify` — which
is what production code should do too (a `return_url` redirect alone never
proves payment).

## Running

From the repository root (the app reads `cmd/webdemo/assets/` at startup),
with the `WXPAY_*` / `ALIPAY_*` variables in the shell — inline works too:

```bash
WXPAY_APPID=wx… WXPAY_MCHID=1900… WXPAY_SERIAL_NO=… \
WXPAY_PRIVATE_KEY=./apiclient_key.pem WXPAY_API_V3_KEY=… \
moon run cmd/webdemo
```

or source a filled-in `cmd/webdemo/env.sh` as shown under
[Configuration](#configuration).

Then open <http://127.0.0.1:1943> (WeChat) or <http://127.0.0.1:1943/alipay>
(Alipay), pick an amount, and pay with the gateway you want to test: scan the
WeChat QR code, or click through to the Alipay cashier. The debug log on each
page records every query response.

If a gateway answers `SIGN_ERROR (http 401)`, run
`bash cmd/webdemo/diagnose.sh` — it checks the clock, the serial/key formats,
the private key ↔ certificate pairing, and the Alipay key variables
(including the "the public key is actually your own key" mistake) without
printing any private key material.

Missing credentials are printed at startup, and the app exits when neither
gateway is configured — it never talks to a gateway whose variables are
incomplete.

## Real charges

Every order is a real charge. The amount selector defaults to ¥0.01; do not
raise it unless you really mean to. Out-trade numbers start with `IT` so test
orders are easy to spot in the merchant consoles and refund afterwards.

The `assets/qrcode.js` bundled with the page is Kazuhiko Arase's
[qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator)
(MIT license), vendored into the repository so the page works offline.
