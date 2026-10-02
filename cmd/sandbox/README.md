# cmd/sandbox — Alipay sandbox smoke check

Builds a signed sandbox checkout URL with real credentials. It never moves
money: the URL is printed for a manual visit, which is enough to confirm the
signature pipeline end to end.

Run it with environment variables set (all three are required; without them
the command prints what to set and exits):

```bash
ALIPAY_APP_ID=2021... \
ALIPAY_PRIVATE_KEY="$(cat app_private_key.pem)" \
ALIPAY_PUBLIC_KEY="$(cat alipay_public_key.pem)" \
moon run cmd/sandbox
```

Then open the printed URL in a browser — the Alipay sandbox cashier should
render. Sandbox gateway and credentials come from the Alipay open platform
(<https://open.alipay.com> → 沙箱环境).
