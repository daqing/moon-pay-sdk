///|
// The APIv3 key the fixtures are encrypted under (32 'a's, test-only).
let test_api_v3_key : String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

///|
// The platform certificate serial of test_keys/platform_certificate.pem.
let platform_serial : String = "4e42d63e06e3969f7360e892f118b86f9d8ab3da"

///|
// Fixed 12-byte nonce for the deterministic test encryptions.
let test_gcm_nonce : Bytes = b"1234567890ab"

///|
let platform_certificate_pem : String =
  #|-----BEGIN CERTIFICATE-----
  #|MIIDZTCCAk2gAwIBAgIUTkLWPgbjlp9zYOiS8Ri4b52Ks9owDQYJKoZIhvcNAQEL
  #|BQAwQjEjMCEGA1UEAwwabW9vbi1wYXktc2RrIHRlc3QgcGxhdGZvcm0xGzAZBgNV
  #|BAoMEm1vb24tcGF5LXNkayB0ZXN0czAeFw0yNjEwMDIwMDAxMTRaFw0zNjA5Mjkw
  #|MDAxMTRaMEIxIzAhBgNVBAMMGm1vb24tcGF5LXNkayB0ZXN0IHBsYXRmb3JtMRsw
  #|GQYDVQQKDBJtb29uLXBheS1zZGsgdGVzdHMwggEiMA0GCSqGSIb3DQEBAQUAA4IB
  #|DwAwggEKAoIBAQDy/08KDz8vcYNL/P170YJ+5hn7S4mz7ZiiT45/p48CyWK69Vna
  #|R0lmaHrE8b9VQJWLifQiiJW44IXw4DutPWw+e/kO/Oxm716yvxC682FPbBfjMA2w
  #|TfxMT1ZDBPx8X5dgqTb1N05jkjsuz+ME2jw4V+4B98onFxnJUj/dMuoQa4fDrIj1
  #|1iDVpSI4t+qX/2KzFvP3xDZcb+rXlELXrnLQ2CTVxJrPIaS0/syKXCuC7d6ApurV
  #|bl4rk059hjyFvcC/2i/85UzRB3iE8oJJ8bSXYKsUCmoO9yoFV4nHY5pz34pcIGw2
  #|uJ6fcZiJKXh3YacD36Vul63D4KxjQvSDh/zBAgMBAAGjUzBRMB0GA1UdDgQWBBR0
  #|VxVpjvmLhiAHktYqxbkquibdvjAfBgNVHSMEGDAWgBR0VxVpjvmLhiAHktYqxbkq
  #|uibdvjAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQC5R4FcHitJ
  #|RGK94W9vjyRt8glBgoOCEz40VKAsgXNCSIV9mUkswLTU/HnjhpTg3O6vlNulykk1
  #|3CwpvW98oUIyj/ENnJKzOIHvgHnSF5kYCRohAgjHd/xPbpT2J3tgoI7ggN6SMkeI
  #|aeHFKIDlyRYAlYW+GCekNPFqvLS+ytoaGt6u4h0GpOW/WAethOxAelMks7YWnRCL
  #|RTHf+SF2eqG8G9kVMXYT3vvDcG6l6uMHwz7llV8YIXYjCSIAV7mhqskDkBFhQzvW
  #|bCgRK5M65ay7GYGaJcmWeBAC8hI2bP5y5I3eMJ7fCH0hEeVC8EH/bIOUTEujcDQ2
  #|XVu9fdnUmGsS
  #|-----END CERTIFICATE-----

///|
let platform_private_key_pem : String =
  #|-----BEGIN PRIVATE KEY-----
  #|MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDy/08KDz8vcYNL
  #|/P170YJ+5hn7S4mz7ZiiT45/p48CyWK69VnaR0lmaHrE8b9VQJWLifQiiJW44IXw
  #|4DutPWw+e/kO/Oxm716yvxC682FPbBfjMA2wTfxMT1ZDBPx8X5dgqTb1N05jkjsu
  #|z+ME2jw4V+4B98onFxnJUj/dMuoQa4fDrIj11iDVpSI4t+qX/2KzFvP3xDZcb+rX
  #|lELXrnLQ2CTVxJrPIaS0/syKXCuC7d6ApurVbl4rk059hjyFvcC/2i/85UzRB3iE
  #|8oJJ8bSXYKsUCmoO9yoFV4nHY5pz34pcIGw2uJ6fcZiJKXh3YacD36Vul63D4Kxj
  #|QvSDh/zBAgMBAAECggEAG6S2uaa9YejQbnMT5SOS7FvB5egUfL8RR5m0VMpbhw4g
  #|6LLjq2TDsV4+ZSw5P3oO6SZi+xC9s5/7LMldkJo1t7ADx9Q3Eoi1pbD9tr7cOZxK
  #|5WIAlKdyhb3aytoE3SNExc7KPUAy7znh+LPWmCU5h5FdNqUZPrQuj0wHjuLtZLuW
  #|H4kAckSF2c/mfh5zYN7tqtvHmzL7cPLUyV1Ir+GE+w3ktWb4NV8f2uqOiEqFkZ8d
  #|LhFjxWktcK78CsicnzsTfjAWIbHHN3859nfHc/cyLRlLedooUr2sR/GcOjnnki3i
  #|olRjZhxTbAhF0Pjgkz5ssquVdO6ZdZqf+7bZauuXvwKBgQD9cLFJo/XrTLnWfYxz
  #|a2WjPoDJ4+XcaDdhg+VXk37f1OE8vTNtNs1zdhj0HqUpKs4fGxyRxRYZ59cILmZN
  #|LlqcVc3eFa/VVB7CnSsrsaPamLxouCxzaemsZ4fgk6d/oGaO7kUE75fNiTEwPzLc
  #|+e3LGzFmyYAuow6KBSr5ByR2fwKBgQD1c51RpYWftfGNR6luX3XdRG4/rSVsnloG
  #|L9mh7xMHE0ierFSe8ngrecWSACtZEyJzLeUSbBP5sHL92UHqKW/+aUXXOW6bTygm
  #|UXod7i0OBbu1eATTtdOUmeIg31Rp74/SnLWOXuG4pM/50XNi+/euVyIgwQGB5wu7
  #|T3RlY6psvwKBgC/NNpMmKrcTxKVxDrGiWww8OLxbkLpOqctpvjMTbcW3+Delk/KQ
  #|eJXDe5dnxE0Mds4lJfFUlAOU19kCL2d1S7/a6zZtLrn04MxiKodWPQp47mht/GxU
  #|WK+c42L3Vota7J0e0cPJkP9CVhW8hdJqDXDWky3I6bViKdbcfKt1rmnvAoGABbn5
  #|zKLY+D3tccdfO5T8kfn7vH6UpfEX1pcdM7r5LawUgKcynja3+QOxSVO5ry1UG23R
  #|r1lYKfYk6Kk98XGgDEZ2e6v6WaNCI4q5F6Or52zY0UYIjsvqMMhaTzwGoyYUq+w+
  #|DCFIkN8/fuuVDpUkVSvxPuRh3Z7/VhJne8oUes8CgYEA5nGi5MpFPribFEytCyZW
  #|DZOoAu7xWK5mo+wHEkxUYvfHMDW8uVko4eUlmN9mqss7s3JM+EQLscvSPCJFvPw9
  #|ZzxuEJN3Nf5uz1P1WdTuM9rwCcjJwIeWPtas7gUktNHJERkVnux+fDAMUUpdKr++
  #|t29RRFhPW1/CKtxi2VtpX8g=
  #|-----END PRIVATE KEY-----

///|
fn platform_key() -> @rsa.PrivateKey {
  @crypto.load_private_key_pem(platform_private_key_pem) catch {
    e => abort("platform fixture key must load: \{e}")
  }
}

///|
// Seal plaintext the way WeChat does before base64: AES-256-GCM, tag
// appended, under the APIv3 key.
fn gcm_seal(
  key : String,
  nonce : Bytes,
  plain : StringView,
  aad : StringView,
) -> Bytes {
  let block = @aes.Cipher::new(@utf8.encode(key)[:]) catch {
    _ => abort("test cipher must init")
  }
  let gcm = @gcm.Gcm::new(block) catch { _ => abort("test gcm must init") }
  gcm.seal(nonce~, plain=@utf8.encode(plain)[:], aad=@utf8.encode(aad)[:])
}

///|
// The platform certificate PEM, encrypted the way /v3/certificates delivers
// it (AES-256-GCM under the APIv3 key, associated data "certificate").
fn encrypted_platform_certificate() -> String {
  let cipher = gcm_seal(
    test_api_v3_key, test_gcm_nonce, platform_certificate_pem, "certificate",
  )
  @base64.encode(cipher[:])
}

///|
fn certs_response_body() -> Bytes {
  let body : Json = {
    "data": [
      {
        "serial_no": platform_serial,
        "effective_time": "2026-01-01T00:00:00+08:00",
        "expire_time": "2031-01-01T00:00:00+08:00",
        "encrypt_certificate": {
          "algorithm": "AEAD_AES_256_GCM",
          "associated_data": "certificate",
          "ciphertext": encrypted_platform_certificate(),
          "nonce": "1234567890ab",
        },
      },
    ],
  }
  @utf8.encode(@moon-pay-sdk.encode_json(body))
}

///|
fn certs_response() -> @transport.Response {
  { status: 200, headers: [], body: certs_response_body(), }
}

///|
async test "platform certificates are fetched, decrypted and cached" {
  let (client, mock) = mock_client([certs_response()])
  let public_key = client.platform_public_key(platform_serial)
  // The key really is the platform certificate's key: it verifies a
  // signature made by the platform fixture key.
  let sig = @crypto.sign_rsa_sha256(platform_key(), b"platform payload"[:])
  assert_true(
    @crypto.verify_rsa_sha256(public_key, b"platform payload"[:], sig[:]),
  )
  assert_eq(mock.recorded().length(), 1)
}

///|
async test "the certificate cache serves later lookups without requests" {
  let (client, mock) = mock_client([certs_response()])
  let _ = client.platform_public_key(platform_serial)
  let _ = client.platform_public_key(platform_serial)
  let _ = client.platform_public_key(platform_serial)
  assert_eq(mock.recorded().length(), 1)
}

///|
async test "an unknown serial triggers one refresh and then fails" {
  let (client, mock) = mock_client([certs_response(), certs_response()])
  let verdict : String = try client.platform_public_key("deadbeef") catch {
    @moon-pay-sdk.Network(_) => "unknown serial"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "unknown serial")
  // The miss caused exactly one refresh request.
  assert_eq(mock.recorded().length(), 1)
  // The refreshed cache serves the known serial without another request.
  let _ = client.platform_public_key(platform_serial)
  assert_eq(mock.recorded().length(), 1)
}

///|
// The WeChat Pay public key a public-key-mode (公钥模式) merchant configures:
// the platform fixture key's public half, as the console publishes it.
let platform_public_key_pem : String =
  #|-----BEGIN PUBLIC KEY-----
  #|MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA8v9PCg8/L3GDS/z9e9GC
  #|fuYZ+0uJs+2Yok+Of6ePAsliuvVZ2kdJZmh6xPG/VUCVi4n0IoiVuOCF8OA7rT1s
  #|Pnv5DvzsZu9esr8QuvNhT2wX4zANsE38TE9WQwT8fF+XYKk29TdOY5I7Ls/jBNo8
  #|OFfuAffKJxcZyVI/3TLqEGuHw6yI9dYg1aUiOLfql/9isxbz98Q2XG/q15RC165y
  #|0Ngk1cSazyGktP7Milwrgu3egKbq1W5eK5NOfYY8hb3Av9ov/OVM0Qd4hPKCSfG0
  #|l2CrFApqDvcqBVeJx2Oac9+KXCBsNrien3GYiSl4d2GnA9+lbpetw+CsY0L0g4f8
  #|wQIDAQAB
  #|-----END PUBLIC KEY-----

///|
let pubkey_id : String = "PUB_KEY_ID_test0001"

///|
fn pubkey_client(
  responses : Array[@transport.Response],
) -> (@wechat.Client, @transport.MockTransport) {
  let mock = @transport.MockTransport::new(responses)
  let client = @wechat.Client::new(
    config=@wechat.Config::new(
      appid="wx8888888888888888",
      mchid="1900000000",
      serial_no="TEST-SERIAL",
      private_key_pem=merchant_pem,
      api_v3_key=test_api_v3_key,
      base_url="https://api.mch.weixin.qq.com",
      platform_public_key_pem~,
      platform_public_key_id=pubkey_id,
    ),
    transport=mock,
    now_ms=() => 1600000000000L,
    verify_responses=false,
  ) catch {
    e => abort("pubkey client must build: \{e}")
  }
  (client, mock)
}

///|
// Callback headers signed by the platform key under an explicit serial.
fn signed_headers_with_serial(
  serial~ : String,
  timestamp~ : String,
  nonce~ : String,
  body~ : String,
) -> Array[(String, String)] {
  let message = callback_message(timestamp, nonce, body)
  let signature = @crypto.sign_rsa_sha256(
    platform_key(),
    @utf8.encode(message)[:],
  )
  [
    ("Wechatpay-Serial", serial),
    ("Wechatpay-Timestamp", timestamp),
    ("Wechatpay-Nonce", nonce),
    ("Wechatpay-Signature", @base64.encode(signature[:])),
  ]
}

///|
async test "public-key mode verifies a callback without any certificate download" {
  let (client, mock) = pubkey_client([])
  let body = "{\"id\":\"evt-pk-1\"}"
  let headers = match
    @wechat.callback_headers_of(
      signed_headers_with_serial(
        serial=pubkey_id,
        timestamp="1600000000",
        nonce="cb-pk-nonce",
        body~,
      ),
    ) {
    Some(headers) => headers
    None => abort("headers must extract")
  }
  client.verify_callback_signature(headers~, body~)
  // Verification came entirely from the configured public key: the mock
  // transport saw no /v3/certificates request at all.
  assert_eq(mock.recorded().length(), 0)
}

///|
async test "a mismatched public-key serial fails without hitting the certificate endpoint" {
  let (client, mock) = pubkey_client([])
  let verdict : String = try
    client.platform_public_key("PUB_KEY_ID_other9999")
  catch {
    @moon-pay-sdk.Network(message) => message
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(verdict.contains("public-key mode"))
  assert_true(verdict.contains("PUB_KEY_ID_test0001"))
  assert_eq(mock.recorded().length(), 0)
}

///|
async test "an unconfigured client refuses public-key serials with guidance" {
  let (client, mock) = mock_client([])
  let verdict : String = try
    client.platform_public_key("PUB_KEY_ID_25566888")
  catch {
    @moon-pay-sdk.Network(message) => message
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(verdict.contains("public-key mode"))
  // No certificate refresh was attempted: public-key-mode merchants cannot
  // download platform certificates.
  assert_eq(mock.recorded().length(), 0)
}

///|
fn config_with_pubkey(pem~ : String, id~ : String) -> @wechat.Config {
  @wechat.Config::new(
    appid="wx8888888888888888",
    mchid="1900000000",
    serial_no="TEST-SERIAL",
    private_key_pem=merchant_pem,
    api_v3_key=test_api_v3_key,
    platform_public_key_pem=pem,
    platform_public_key_id=id,
  )
}

///|
async test "public key config must be complete and well-formed" {
  let verdicts : Array[String] = []
  for
    config in [
      config_with_pubkey(pem=platform_public_key_pem, id=""),
      config_with_pubkey(pem="", id=pubkey_id),
      config_with_pubkey(pem="not a pem", id=pubkey_id),
    ] {
    try config.validate() catch {
      @moon-pay-sdk.Config(message) => verdicts.push(message)
      _ => verdicts.push("other error")
    } noraise {
      _ => verdicts.push("no error raised")
    }
  }
  assert_eq(verdicts.length(), 3)
  for verdict in verdicts {
    assert_true(verdict.contains("platform_public_key"))
  }
  // The complete pair passes and the client builds with the key loaded.
  let (client, _) = pubkey_client([])
  let public_key = client.platform_public_key(pubkey_id)
  let sig = @crypto.sign_rsa_sha256(platform_key(), b"pk payload"[:])
  assert_true(@crypto.verify_rsa_sha256(public_key, b"pk payload"[:], sig[:]))
}
