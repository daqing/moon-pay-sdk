# Shell environment template for `moon run cmd/webdemo`.
#
# Copy this file to `cmd/webdemo/env.sh` (gitignored), fill in the real
# merchant values, then run the webdemo from the repository root:
#
#     cp cmd/webdemo/env.example.sh cmd/webdemo/env.sh
#     $EDITOR cmd/webdemo/env.sh
#     source cmd/webdemo/env.sh && moon run cmd/webdemo
#
# `env.sh` never enters git; keep real credentials out of the repository.

# Merchant app id from the WeChat Pay merchant console, e.g. wx1a2b3c4d5e6f7g8h
export WXPAY_APPID=""

# Merchant id
export WXPAY_MCHID=""

# Serial number of the merchant API certificate
export WXPAY_SERIAL_NO=""

# The API-certificate private key: PEM text, or a path to the PEM file
export WXPAY_PRIVATE_KEY=""

# The APIv3 key used for callback payload decryption
export WXPAY_API_V3_KEY=""

# Optional: gateway base URL (default: https://api.mch.weixin.qq.com).
# export WXPAY_BASE_URL="https://api.mch.weixin.qq.com"

# Optional, public-key mode (公钥模式): the WeChat Pay public key downloaded
# from the merchant console (API安全 → 微信支付公钥, usually pub_key.pem) and
# its serial shown next to it (PUB_KEY_ID_...). Set BOTH or NEITHER — with
# them set, signatures from WeChat are verified against this key and no
# platform certificates are downloaded; without them, certificate mode
# (/v3/certificates) is used.
# export WXPAY_PUBLIC_KEY="/path/to/pub_key.pem"
# export WXPAY_PUBLIC_KEY_ID="PUB_KEY_ID_25566888"

# Optional: callback URL sent with every order. WeChat Pay must be able to
# reach it for the notify path to fire; the page also polls, so a placeholder
# still works for the QR + query flow.
# export WXPAY_NOTIFY_URL="https://your.example.com/api/wechat/notify"
