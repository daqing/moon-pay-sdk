#!/usr/bin/env bash
# diagnose.sh — sanity-check the WXPAY_* configuration cmd/webdemo uses for
# request signing, without printing any private key material.
#
# Run from the repository root after filling in cmd/webdemo/env.sh:
#
#     bash cmd/webdemo/diagnose.sh
#
# WeChat answers SIGN_ERROR (http 401) when the Authorization signature does
# not verify. In practice that means one of: stray characters inside
# WXPAY_SERIAL_NO, a private key that does not belong to that certificate
# serial, a skewed clock, or a revoked/expired certificate.

set -u
cd "$(dirname "$0")/../.."
if [ -f cmd/webdemo/env.sh ]; then
  # shellcheck disable=SC1091
  source cmd/webdemo/env.sh
fi

fails=0

check() { # check <label> <0|1>
  if [ "$2" -eq 1 ]; then
    printf '  ok    %s\n' "$1"
  else
    printf '  FAIL  %s\n' "$1"
    fails=$((fails + 1))
  fi
}

echo "== clock =="
printf '  system time (UTC): %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S')"
echo '  (must be within ±5 minutes of real time, or signatures are rejected)'

echo
echo "== WXPAY_SERIAL_NO =="
if [ -z "${WXPAY_SERIAL_NO:-}" ]; then
  check "serial_no is set" 0
elif [[ "$WXPAY_SERIAL_NO" == PUB_KEY_ID* ]]; then
  echo "  FAIL  this is the WeChat Pay PUBLIC key serial (公钥序列号)."
  echo '        WXPAY_SERIAL_NO needs the API certificate serial (40 hex chars)'
  echo '        from 商户平台 → API安全 → API证书, or the certificate file itself.'
  fails=$((fails + 1))
else
  printf '  value: %s (length %s)\n' "$WXPAY_SERIAL_NO" "${#WXPAY_SERIAL_NO}"
  case "$WXPAY_SERIAL_NO" in
  *[!0-9A-Fa-f]*)
    echo '  FAIL  value contains characters outside 0-9A-Fa-f — re-copy it'
    fails=$((fails + 1))
    ;;
  *)
    check "value is pure hex" 1
    ;;
  esac
fi

echo
echo "== WXPAY_PRIVATE_KEY =="
key_pub=""
key_text=""
if [ -z "${WXPAY_PRIVATE_KEY:-}" ]; then
  check "private_key is set" 0
elif [[ "$WXPAY_PRIVATE_KEY" == -----BEGIN* ]]; then
  echo '  source: inline PEM'
  key_pub=$(printf '%s\n' "$WXPAY_PRIVATE_KEY" | openssl pkey -in /dev/stdin -pubout 2>/dev/null)
  key_text=$(printf '%s\n' "$WXPAY_PRIVATE_KEY" | openssl pkey -in /dev/stdin -text -noout 2>/dev/null | head -1)
else
  echo "  source: file $WXPAY_PRIVATE_KEY"
  if [ ! -r "$WXPAY_PRIVATE_KEY" ]; then
    check "file is readable" 0
  else
    check "file is readable" 1
    key_pub=$(openssl pkey -in "$WXPAY_PRIVATE_KEY" -pubout 2>/dev/null)
    key_text=$(openssl pkey -in "$WXPAY_PRIVATE_KEY" -text -noout 2>/dev/null | head -1)
  fi
fi
key_fp=""
if [ -n "$key_pub" ]; then
  key_fp=$(printf '%s\n' "$key_pub" | openssl md5 | sed 's/^.*= //')
  printf '  private key public-half fingerprint: %s\n' "$key_fp"
  printf '  %s\n' "$key_text"
  case "$key_text" in
  *2048\ bit*) : ;;
  *) echo '  WARN  WeChat Pay expects a 2048-bit RSA key; other sizes may be rejected' ;;
  esac
fi

echo
echo "== private key <-> certificate pairing =="
cert_fp=""
if [[ "${WXPAY_PRIVATE_KEY:-}" == -----BEGIN* ]]; then
  echo '  (private key is inline PEM — point WXPAY_PRIVATE_KEY at the'
  echo '   apiclient_key.pem file to run the pairing check)'
elif [ -z "${WXPAY_PRIVATE_KEY:-}" ] || [ ! -r "${WXPAY_PRIVATE_KEY:-/nonexistent}" ]; then
  echo '  skipped: no readable private key file'
else
  cert="$(dirname "$WXPAY_PRIVATE_KEY")/apiclient_cert.pem"
  if [ ! -r "$cert" ]; then
    echo "  (no $cert — the API certificate zip from the merchant console"
    echo '   contains both apiclient_cert.pem and apiclient_key.pem; put them'
    echo '   side by side to run the pairing check)'
  else
    cert_serial=$(openssl x509 -in "$cert" -noout -serial 2>/dev/null | sed 's/^serial=//' || true)
    cert_fp=$(openssl x509 -in "$cert" -noout -pubkey 2>/dev/null | openssl md5 2>/dev/null | sed 's/^.*= //' || true)
    if [ -z "$cert_serial" ] || [ -z "$cert_fp" ]; then
      echo "  FAIL  $cert is not a readable X.509 certificate — check the file"
      fails=$((fails + 1))
    else
      printf '  certificate: %s\n' "$cert"
      printf '  certificate serial:      %s\n' "$cert_serial"
      printf '  certificate fingerprint: %s\n' "$cert_fp"
      printf '  validity: %s\n' "$(openssl x509 -in "$cert" -noout -dates 2>/dev/null | tr '\n' ' ')"
      if [ -n "${WXPAY_SERIAL_NO:-}" ]; then
        if [ "$(echo "$WXPAY_SERIAL_NO" | tr 'a-f' 'A-F')" = "$(echo "$cert_serial" | tr 'a-f' 'A-F')" ]; then
          check "WXPAY_SERIAL_NO matches the certificate serial" 1
        else
          check "WXPAY_SERIAL_NO matches the certificate serial" 0
        fi
      fi
      if [ -n "$key_fp" ]; then
        if [ "$cert_fp" = "$key_fp" ]; then
          check "private key belongs to this certificate" 1
        else
          check "private key belongs to this certificate" 0
        fi
      fi
    fi
  fi
fi

echo
echo "== ALIPAY_* (optional Alipay panel) =="
if [ -z "${ALIPAY_APPID:-}" ] && [ -z "${ALIPAY_PRIVATE_KEY:-}" ] && [ -z "${ALIPAY_PUBLIC_KEY:-}" ]; then
  echo '  not configured — the Alipay panel stays disabled (set ALIPAY_* to enable it)'
else
  if [ -n "${ALIPAY_APPID:-}" ]; then
    printf '  appid: %s\n' "$ALIPAY_APPID"
  else
    check 'ALIPAY_APPID is set' 0
  fi

  ali_priv_pub=""
  if [ -z "${ALIPAY_PRIVATE_KEY:-}" ]; then
    check 'ALIPAY_PRIVATE_KEY is set' 0
  elif [[ "$ALIPAY_PRIVATE_KEY" == *'BEGIN PUBLIC KEY'* ]] ||
    { [ -r "$ALIPAY_PRIVATE_KEY" ] && grep -q 'BEGIN PUBLIC KEY' "$ALIPAY_PRIVATE_KEY" 2>/dev/null; }; then
    echo '  FAIL  ALIPAY_PRIVATE_KEY holds a PUBLIC key — it needs the application'
    echo '        private key generated with the Alipay key tool (密钥工具)'
    fails=$((fails + 1))
  else
    if [[ "$ALIPAY_PRIVATE_KEY" == -----BEGIN* ]]; then
      echo '  source: inline PEM'
      ali_priv_pub=$(printf '%s\n' "$ALIPAY_PRIVATE_KEY" | openssl pkey -in /dev/stdin -pubout 2>/dev/null)
    elif [ -r "$ALIPAY_PRIVATE_KEY" ]; then
      check 'ALIPAY_PRIVATE_KEY file is readable' 1
      ali_priv_pub=$(openssl pkey -in "$ALIPAY_PRIVATE_KEY" -pubout 2>/dev/null)
    else
      check "ALIPAY_PRIVATE_KEY file is readable ($ALIPAY_PRIVATE_KEY)" 0
    fi
    if [ -n "$ali_priv_pub" ]; then
      check 'ALIPAY_PRIVATE_KEY parses as an RSA private key' 1
      priv_bits=$(printf '%s' "$ali_priv_pub" | openssl pkey -pubin -text -noout 2>/dev/null | head -1)
      case "$priv_bits" in
      *2048*) : ;;
      *) echo '  WARN  Alipay expects a 2048-bit RSA2 key; other sizes may be rejected' ;;
      esac
    else
      check 'ALIPAY_PRIVATE_KEY parses as an RSA private key (PEM text or readable file path)' 0
    fi
  fi

  ali_pub_fp=""
  if [ -z "${ALIPAY_PUBLIC_KEY:-}" ]; then
    check 'ALIPAY_PUBLIC_KEY is set' 0
  elif [[ "$ALIPAY_PUBLIC_KEY" == *'BEGIN PRIVATE KEY'* ]] ||
    { [ -r "$ALIPAY_PUBLIC_KEY" ] && grep -q 'BEGIN.*PRIVATE KEY' "$ALIPAY_PUBLIC_KEY" 2>/dev/null; }; then
    echo '  FAIL  ALIPAY_PUBLIC_KEY holds a PRIVATE key — it needs the Alipay'
    echo '        public key (支付宝公钥) from the open-platform console, NOT'
    echo '        the application key pair you generated'
    fails=$((fails + 1))
  else
    if [[ "$ALIPAY_PUBLIC_KEY" == -----BEGIN* ]]; then
      ali_pub_fp=$(printf '%s\n' "$ALIPAY_PUBLIC_KEY" | openssl pkey -pubin -in /dev/stdin 2>/dev/null | openssl md5 2>/dev/null | sed 's/^.*= //')
    elif [ -r "$ALIPAY_PUBLIC_KEY" ]; then
      check 'ALIPAY_PUBLIC_KEY file is readable' 1
      ali_pub_fp=$(openssl pkey -pubin -in "$ALIPAY_PUBLIC_KEY" 2>/dev/null | openssl md5 2>/dev/null | sed 's/^.*= //')
    else
      check "ALIPAY_PUBLIC_KEY file is readable ($ALIPAY_PUBLIC_KEY)" 0
    fi
    if [ -n "$ali_pub_fp" ]; then
      check 'ALIPAY_PUBLIC_KEY parses as a public key' 1
    else
      check 'ALIPAY_PUBLIC_KEY parses as a public key (PEM text or readable file path)' 0
    fi
  fi

  if [ -n "$ali_priv_pub" ] && [ -n "$ali_pub_fp" ]; then
    ali_priv_fp=$(printf '%s\n' "$ali_priv_pub" | openssl md5 | sed 's/^.*= //')
    if [ "$ali_priv_fp" = "$ali_pub_fp" ]; then
      echo '  FAIL  ALIPAY_PUBLIC_KEY is the public half of ALIPAY_PRIVATE_KEY —'
      echo '        it must be the Alipay public key (支付宝公钥) instead'
      fails=$((fails + 1))
    else
      check 'ALIPAY_PUBLIC_KEY is not the application key pair' 1
    fi
  fi
fi

echo
if [ "$fails" -gt 0 ]; then
  echo "diagnose: $fails check(s) failed — fix the FAIL lines above, re-source env.sh and retry"
else
  echo 'diagnose: local checks passed.'
  echo 'If the gateway still answers SIGN_ERROR, the certificate may belong to a'
  echo 'different merchant id or be revoked — check 商户平台 → API安全 → API证书.'
fi
exit 0
