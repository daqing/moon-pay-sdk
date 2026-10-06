# webdemo — WeChat Pay integration-check web app

A minimal web app that exercises `daqing/moon-pay-sdk`'s WeChat Pay Native
(QR) checkout against the **real** gateway. It exists for manual integration
testing: open the page, scan the QR code with WeChat, and watch the order go
from `NOTPAY` to `SUCCESS` through the SDK's real signing, query and callback
verification paths.

The server listens on port **1943** and serves a single page that:

1. creates a Native order (`POST /api/orders`) through
   `Client::native_order`, and renders the returned `code_url` as a QR code;
2. polls the order (`GET /api/orders/<out_trade_no>`) through
   `Client::query_order` every two seconds;
3. accepts WeChat Pay's signed callback (`POST /api/wechat/notify`) through
   `Client::verify_callback`, reconciles the amount, and acknowledges it.

Polling works from a laptop without a public hostname; the notify endpoint
exercises the full callback path whenever WeChat Pay can reach the configured
`WXPAY_NOTIFY_URL`.

## Configuration

All credentials come from the environment, so nothing secret lives in the
repository. The app reads `WXPAY_*` variables from the shell it is launched
from — export them directly, or source a filled-in copy of the bundled
template (recommended; `cmd/webdemo/env.sh` is gitignored):

```bash
cp cmd/webdemo/env.example.sh cmd/webdemo/env.sh
$EDITOR cmd/webdemo/env.sh          # fill in the real merchant values
source cmd/webdemo/env.sh && moon run cmd/webdemo
```

| Variable | Required | Meaning |
| --- | --- | --- |
| `WXPAY_APPID` | yes | Merchant app id, e.g. `wx…` |
| `WXPAY_MCHID` | yes | Merchant id |
| `WXPAY_SERIAL_NO` | yes | Serial number of the merchant API certificate |
| `WXPAY_PRIVATE_KEY` | yes | The API-certificate private key, either as PEM text or as a path to a PEM file |
| `WXPAY_API_V3_KEY` | yes | The APIv3 key used for callback decryption |
| `WXPAY_BASE_URL` | no | Gateway base URL; defaults to `https://api.mch.weixin.qq.com` |
| `WXPAY_PUBLIC_KEY` | no | Public-key mode (公钥模式): the WeChat Pay public key from the merchant console (`pub_key.pem`), as PEM text or a file path |
| `WXPAY_PUBLIC_KEY_ID` | no | Public-key mode: the serial shown next to it, e.g. `PUB_KEY_ID_25566888` — set both or neither |
| `WXPAY_NOTIFY_URL` | no | Callback URL passed when placing orders; defaults to a placeholder |

With `WXPAY_PUBLIC_KEY`/`WXPAY_PUBLIC_KEY_ID` set, WeChat's signatures are
verified against that key and no platform certificates are downloaded
(public-key mode, the default for newer merchant accounts). Without them, the
SDK uses certificate mode (`/v3/certificates`).

### What each value must be

Filling these with the wrong kind of value is by far the most common reason
the gateway answers `SIGN_ERROR (http 401)`. Run
`bash cmd/webdemo/diagnose.sh` to check all of them mechanically.

| Variable | Must be | Must NOT be |
| --- | --- | --- |
| `WXPAY_SERIAL_NO` | The serial of the merchant **API certificate** — 40 hex chars, from `apiclient_cert.pem` in the certificate zip or 商户平台 → API安全 → **API证书** | The `PUB_KEY_ID_...` **public-key** serial |
| `WXPAY_PRIVATE_KEY` | `apiclient_key.pem` from the **same certificate zip** as the serial above | `pub_key.pem` (that is a public key), or any key you generated yourself — WeChat verifies the signature against the certificate the serial names, so key and certificate must be a pair |
| `WXPAY_API_V3_KEY` | The 32-character APIv3 key set under 商户平台 → API安全 | The login password or the APIv2 key |
| `WXPAY_PUBLIC_KEY` | The console's **WeChat Pay public key** `pub_key.pem` (公钥模式) | Your own certificate's public key |
| `WXPAY_PUBLIC_KEY_ID` | The `PUB_KEY_ID_...` serial shown next to `pub_key.pem` | The API certificate serial |

Notes:

- A mini-program appid works for Native (QR) checkout — no openid is
  involved — as long as it is bound to the merchant account (商户平台 →
  产品中心 → AppID账号管理). For payments *inside* a mini-program you need
  JSAPI orders instead, which this SDK does not implement yet.
- `SIGN_ERROR` is a signature-layer rejection that happens before appid or
  product checks: it means the private key, the certificate serial named in
  the request, or the clock is wrong — not a permission problem.

## Run

From the repository root (the app reads `cmd/webdemo/assets/` at startup),
with the `WXPAY_*` variables present in the shell — either exported directly:

```bash
WXPAY_APPID=wx… WXPAY_MCHID=1900… WXPAY_SERIAL_NO=… \
WXPAY_PRIVATE_KEY=./apiclient_key.pem WXPAY_API_V3_KEY=… \
moon run cmd/webdemo
```

or via a sourced `cmd/webdemo/env.sh` as shown under
[Configuration](#configuration).

Then open <http://127.0.0.1:1943>, pick an amount, and scan the QR code with
WeChat. The page keeps a debug log of every query response.

If the gateway answers `SIGN_ERROR (http 401)`, run
`bash cmd/webdemo/diagnose.sh` — it checks the clock, the serial format and
the private key ↔ certificate pairing without printing any key material.

Without credentials the app prints what to set and exits — nothing touches the
gateway until every variable is present.

## Handling real money

Every order is a real charge. The amount selector defaults to ¥0.01; keep it
there unless you specifically mean to test a larger amount. Order numbers are
prefixed `IT` so test orders are easy to spot in the merchant console and to
refund afterwards.

The bundled `assets/qrcode.js` is [qrcode-generator] by Kazuhiko Arase
(MIT license), vendored so the page works offline.

[qrcode-generator]: https://github.com/kazuhikoarase/qrcode-generator
