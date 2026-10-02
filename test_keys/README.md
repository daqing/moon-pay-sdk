# test_keys — test-only key material

These keys and this certificate exist only for the automated test suite.
They protect nothing and are committed on purpose. **Never use them, or any
key generated the same way, in a real deployment.**

| File | Format | Role in tests |
| --- | --- | --- |
| `merchant_private_key.pem` | PKCS#8 PEM (`BEGIN PRIVATE KEY`) | WeChat/Alipay merchant signing key |
| `merchant_private_key_pkcs1.pem` | PKCS#1 PEM (`BEGIN RSA PRIVATE KEY`) | same, legacy format — loader must accept both |
| `merchant_public_key.pem` | SubjectPublicKeyInfo PEM (`BEGIN PUBLIC KEY`) | public-key loading tests |
| `platform_private_key.pem` | PKCS#8 PEM | stands in for a WeChat Pay platform key (test callback signing) |
| `platform_certificate.pem` | X.509 self-signed certificate | certificate parsing: public key + serial extraction |

Regenerate everything with OpenSSL (deterministic layout, random keys):

```bash
cd test_keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out merchant_private_key.pem
openssl pkey -in merchant_private_key.pem -pubout -out merchant_public_key.pem
openssl genrsa -out merchant_private_key_pkcs1.pem 2048
openssl rsa -in merchant_private_key_pkcs1.pem -traditional -out merchant_private_key_pkcs1.pem
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out platform_private_key.pem
openssl req -x509 -new -key platform_private_key.pem -sha256 -days 3650 \
  -subj "/CN=moon-pay-sdk test platform/O=moon-pay-sdk tests" \
  -out platform_certificate.pem
```

Note: regenerating replaces the key material, so any golden values (reference
signatures, the certificate serial) embedded in tests must be regenerated with
it.
