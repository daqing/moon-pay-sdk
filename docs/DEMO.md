# moon-pay-sdk — 5-minute demo script

A walk-through for judges and contributors: build, test, run, then read the
code. Everything runs offline; no real credentials or money are involved.

## 1. Build and test (about 2 minutes)

```bash
git clone https://github.com/daqing/moon-pay-sdk
cd moon-pay-sdk
moon test
```

117 tests, 0 warnings. The suite includes openssl cross-validated golden
vectors for signatures, end-to-end loopback tests over real HTTP, and
consolidated security negatives (replay, unknown serial, tampering, wrong
keys, amount mismatch).

## 2. Run the payment demo

```bash
moon run examples/payment_demo
```

The demo stands up a local mock provider and walks both flows with the
test-only keys:

- **WeChat Pay**: a Native (QR) order over real HTTP, a signed and encrypted
  callback that the SDK verifies and decrypts, and the `SUCCESS` ack.
- **Alipay**: the signed desktop-checkout redirect, a signed notification
  reconciled against the local order amount, and the `success` ack.

## 3. Where to look in the code

| Path | What it is |
| --- | --- |
| `crypto/` | RSA-SHA256, X.509 and AES-256-GCM via the pure-MoonBit crypto stack, cross-checked against `openssl` reference signatures |
| `transport/` | The `Transport` interface over `moonbitlang/async` HTTP(S), plus the scriptable mock that keeps every client test offline |
| `wechat/` | The API v3 client: request signing, Native/H5 orders, query, platform certificates, callback verification and decryption |
| `alipay/` | The OpenAPI client: canonical parameter signing, page/wap redirects, query, notification and `return_url` verification |
| `e2e/` | The loopback end-to-end tests and the consolidated security negatives |

## 4. Optional: Alipay sandbox

With real sandbox credentials, `cmd/sandbox` builds a signed sandbox
checkout URL — see `cmd/sandbox/README.md`.
