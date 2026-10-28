# WeChat Pay JSAPI (Official-Account Payment) Testing Guide

This document records the current testing status of JSAPI payment
(official-account web pages, and mini-program pages — both are JSAPI) in
moon-pay-sdk, and the concrete steps to take the testing further. Like the
rest of the SDK, every JSAPI code path is already covered by offline tests;
what remains is completing the integration test against the real gateway.

## 1. Current Status

As of this writing (v0.10.0, `develop` branch), `moon test` is fully green
(131/131).

### Covered (offline, mock transport)

Three test cases in `wechat/jsapi_test.mbt`:

1. **Order request and response parsing** — `jsapi_order` correctly POSTs to
   `/v3/pay/transactions/jsapi` with `payer.openid` in the body, and parses
   the `prepay_id` out of the response.
2. **Pay params and paySign** — in the parameter set produced by
   `jsapi_pay_params` (`appId` / `timeStamp` / `nonceStr` / `package` /
   `signType=RSA` / `paySign`), the `paySign` verifies against the four-line
   canonical string `appId\ntimeStamp\nnonceStr\npackage\n` with the test
   merchant public key (RSA-SHA256).
3. **Local rejection** — an empty `openid` or empty `prepay_id` is rejected
   locally with a `Config` error; no HTTP request is sent.

`cmd/webdemo` (the integration-test web app) already ships a JSAPI block:
enter an openid → place the order → get the signed `wx.requestPayment`
parameter set back; orders are polled through the same query endpoint as
Native orders.

### Not Covered Yet

1. **Real-gateway integration** — everything above ran against a mock
   transport; the WeChat gateway has not yet accepted a real JSAPI order
   followed by a real payment.
2. **The e2e loopback test has no JSAPI case** — `e2e/` only covers the
   Native flow (order → callback → verify & decrypt → ack); there is no
   JSAPI scenario.
3. **Official-account web authorization (OAuth2 → openid) is not
   implemented** — the `miniprogram` package only wraps mini-program
   code2session; the openid for an official-account page has to be obtained
   by other means. This is the main blocker for end-to-end JSAPI testing.

## 2. Steps to Continue Testing

### Step 1 — Prepare credentials and verify them

JSAPI is stricter than Native on two prerequisites:

- The **appid must be a verified service account** (official account), or a
  mini-program appid bound to the merchant account.
- The **openid must belong to that appid** (openids are namespaced per
  appid).

```bash
cd ~/mzevo/open-source/moonbit/month10/moon-pay-sdk
cp cmd/webdemo/env.example.sh cmd/webdemo/env.sh
$EDITOR cmd/webdemo/env.sh      # fill in WXPAY_APPID / MCHID / SERIAL_NO / PRIVATE_KEY / API_V3_KEY
bash cmd/webdemo/diagnose.sh    # mechanical checks: clock, serial format, key↔cert pairing
```

For what each variable means and the usual mistakes, see the
"Environment variables" section of `docs/wechat.md`.

### Step 2 — Obtain an openid under that appid

Pick one of three ways:

1. **Official-account web authorization** (the proper path). Open this in
   WeChat:

   ```text
   https://open.weixin.qq.com/connect/oauth2/authorize?appid=<APPID>&redirect_uri=<YOUR PAGE>&response_type=code&scope=snsapi_base#wechat_redirect
   ```

   Exchange the resulting `code` for the openid:

   ```text
   https://api.weixin.qq.com/sns/oauth2/access_token?appid=<APPID>&secret=<SECRET>&code=<CODE>&grant_type=authorization_code
   ```

   The `openid` field of the response is what you need. Note: the callback
   domain must be configured under Official Account Settings → Feature
   Settings → Web Authorization Domain in the WeChat Official Account
   Platform.

2. **Borrow the mini-program path**. Configure `WXPAY_APP_SECRET` for
   webdemo and use the mini-program block on the page to exchange a
   `wx.login` code for an openid — this only works if the payment client's
   appid *is* that mini-program appid (openids are per-appid; an openid
   from a different appid is invalid).

3. **A historical openid**. The payer openid of any past transaction under
   the same appid (visible in the merchant platform's order details).

### Step 3 — Place a real order, confirm the gateway accepts it

```bash
source cmd/webdemo/env.sh && moon run cmd/webdemo   # listens on port 1943
```

Open <http://127.0.0.1:1943>, fill in the openid in the JSAPI block, keep
the amount at the default ¥0.01, and click "Create JSAPI order". How to
read the outcome:

| Symptom | Meaning | Action |
| --- | --- | --- |
| Server log shows `jsapi order IT… prepay_id=…` | Gateway accepted the signature and the openid — order created | Go to step 4 |
| `PARAM_ERROR: invalid openid` | The request signature was accepted; the openid does not belong to this appid | Re-obtain the openid via step 2, method 1/2 |
| `SIGN_ERROR (http 401)` | Rejected at the signature layer, before appid/permission checks | Back to `diagnose.sh` — check key pairing and clock |

### Step 4 — Invoke the payment inside WeChat

The returned parameter set must be used from inside WeChat:
`WeixinJSBridge.invoke('getBrandWCPayRequest', params)` on an
official-account page, or `wx.requestPayment(params)` in a mini-program.
Workable environments:

- **WeChat DevTools** — open the webdemo URL with the "Official Account web
  page" project type (works when the phone and computer share a LAN, with
  debugging enabled).
- **Real phone inside WeChat**. Note: official-account JSAPI requires the
  page URL to live under the **payment authorization directory** configured
  in the merchant platform, otherwise WeChat reports "the URL of the current
  page is not registered". webdemo serves the page at the root path, so
  configure the directory accordingly at Merchant Platform → Product Center
  → Development Configuration (including the trailing `/`).

After paying ¥0.01, the page polls every 2 seconds and should show
`trade_state: SUCCESS`.

### Step 5 — Verify the callback and reconcile

- **Query**: the page polls `GET /api/orders/<out_trade_no>`; confirm the
  `Success` state and the correct amount.
- **Callback**: WeChat POSTs the signed notification to `WXPAY_NOTIFY_URL`,
  which lands on webdemo's `POST /api/wechat/notify`; after signature
  verification + AES-256-GCM decryption, `notify_seen` flips to true.
  **Not receiving the callback on a machine without a public IP is
  expected** — the polling query alone proves the payment succeeded; to
  exercise the callback path the notify URL must be publicly reachable
  (tunnel or public server).
- **Cleanup afterwards**: all test order numbers carry the `IT` prefix so
  they can be identified in the merchant platform and refunded.

## 3. Known Gaps and Recommendations

1. **Add a JSAPI case to the e2e loopback test** (following the TASKS.md
   T7.3 pattern): add a `/v3/pay/transactions/jsapi` route to the mock
   WeChat server, reuse the existing signed-callback fixtures, and run the
   full "JSAPI order → callback verify & decrypt → ack" flow — locks in the
   regression for free.
2. **TASKS.md T9.3 is outdated** — JSAPI and mini-program payment are
   actually implemented and merged (commits `c6449ea`, `d1680ba`), but the
   task list still shows them unchecked; update it.
3. **(Optional) an official-account OAuth helper** — silent `snsapi_base`
   authorization for the openid is a prerequisite of the official-account
   flow; the SDK could provide it (the way `miniprogram` provides
   code2session) so the official-account flow becomes one call like the
   mini-program one.

## 4. Troubleshooting Quick Reference

| Error | Layer | Cause & Fix |
| --- | --- | --- |
| `SIGN_ERROR (http 401)` | Request signature | Wrong private key, serial, or clock; run `diagnose.sh`. The serial must be the API certificate serial (40 hex chars), not a `PUB_KEY_ID_…` |
| `PARAM_ERROR: invalid openid` | Business parameters | Signature was fine; the openid does not match the ordering appid |
| "URL of the current page is not registered" | Merchant platform config | Page URL is outside the payment authorization directory |
| Callback never arrives | Network | The notify URL must be publicly reachable; on a local machine, rely on the polling query |
| JSAPI block disabled on the page | webdemo | `WXPAY_*` variables not exported or env.sh not re-sourced; restart the app and read the startup log for missing variables |

## Related Docs

- `docs/wechat.md` — the general WeChat Pay guide (credentials, variables,
  troubleshooting)
- `docs/wechat.zh-CN.md` — the same, in Chinese
- `cmd/webdemo/README.md` — how to run the webdemo integration app
- `wechat/jsapi_test.mbt` — the offline JSAPI test cases
