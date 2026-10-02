///|
let merchant_private_key_pem : String =
  #|-----BEGIN PRIVATE KEY-----
  #|MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCXzGdU6pphQauR
  #|Kaq/hu6IOtLC95yF0mfkWjEUto2PyUhhPdq7UPhjkm3o9u/VDkDfEfFBvRwqmp+r
  #|0hbvFCZ4Fxxxb37B1BHD3qUhqBX75Mzw4I2A0qFeCMfh7Ap0a+/pHRDMXKZvQ7um
  #|4Lmfqyl9goLsPeDFeEnpkILQbYfjHmH6Z5uNiCCy4u1Shccf/1rXVnMaDsolXSXJ
  #|76TKJpWxo9g52hhUaW9hvF6ax3/JQ489DbPfnfg+VSoA2H5fTR6WifgLJ/1yXEny
  #|a6HJKGjWQxJxLaFtZvaW1CAlHvisKDNHYEGASUPiv/tCM0WD3X9CFouRmffHp4oO
  #|OM2eIsPrAgMBAAECggEABXkM+AP1/pqqWl35C4Bhujn7Xk8kxAhiztoCRKpo7oMF
  #|yoe7NUoFN+XQHk2aNlbAt6otxhPQ36ev07c2iiEdBUhkB0z18ia4ten25ICVu6gI
  #|oYifDBghUZgZyMdEqzo3A0hqfMu8WReakjjY8xeYiS9lk/85IDV8M2EOmQAnSDoX
  #|z9J/sOED5WCtPuX7YOez8wGMr/LmD4qLJBGT6rsfo4t7GZug2kVpZVc9G5IMGlD+
  #|g28h+wCcLnx8CL23amdFcPjROtxDIJrBfKWmpMRiPCDFwtoEh6DD4dLeLm71YX60
  #|0U8p0beW7KMexz185BrW4RKWQf7hmlxEexLsuYIV/QKBgQDLZfW/OwJSynwAI/TH
  #|8O7ByKaWnTJzIHrWcnCFo09nWHs8z8WWZKpfWlqt5wBBfHmV9GZix13ug1n26MME
  #|3ZH12iU1JGgB9Lnt2JPpsmQ2z/NfVK4T/fyp2KYA6CvTd+UWhg6/qs0nYfFzoMlP
  #|MBwsLqtWB3wNFByo5LHyynsAhwKBgQC/DkM3hoq0RyQ1gwOq4tFN6nbCxi68IQrU
  #|QBIJ1B15gMgcURBbz2UZvANvpN038MICxY8XzU1TjoYhkm6NjjmBcZb+ReCTzSv3
  #|JwcWnD5tBFee7YAt5UxXZ7rzhkiq1YYEbhyjod5Yrph0/gml1dDbCii0OK5PsDdF
  #|2XhuQTrufQKBgQC6MfpHNuOnmojtL/0y01Idv2sQ0ZKPZZpNmbF8BMX5mzwlrSX5
  #|yOlWJMaCD8diK2q6ZWMc5dkNMN04dFeiqpqlby9EeLFlqPxTyUGOW6n1q2PlTwWU
  #|c5vKd/NvPRpxmX3zooD54Iexl62K5hOjFC2WHJroRC3BYznhOonT8purHQKBgQCg
  #|TkpN86C8JRkXoUdZghkWpE1jnkAmcB8S+nNoNcdJZKoDQG1Wa40r65qCebV4M5XG
  #|F5e54/Qm0OZwktoaAiT0HKgRz/Xgbf2e0etbqFukw0j1u9eaKtREXm/510lvtdtO
  #|KknzbmUOyeh3+ZOExwQIVdzTYt+3U2b9P7yR3j+hTQKBgGYsDsIYlwz51oj1b7QH
  #|rNYiYnHJjPd7tdfksEtmZ7yhk0OB18cFB4LRHgNokc3lgNUgGC0C+7JquetdE2FU
  #|0mGviUbyPzp8TM5gAqm+q2JUyApo27303uIz59rmO2pE3KvqGzue9a/J4HjasVPc
  #|PhmsS0JfBPTePVgBFEMn8aag
  #|-----END PRIVATE KEY-----

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
let merchant_public_key_pem : String =
  #|-----BEGIN PUBLIC KEY-----
  #|MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAl8xnVOqaYUGrkSmqv4bu
  #|iDrSwvechdJn5FoxFLaNj8lIYT3au1D4Y5Jt6Pbv1Q5A3xHxQb0cKpqfq9IW7xQm
  #|eBcccW9+wdQRw96lIagV++TM8OCNgNKhXgjH4ewKdGvv6R0QzFymb0O7puC5n6sp
  #|fYKC7D3gxXhJ6ZCC0G2H4x5h+mebjYggsuLtUoXHH/9a11ZzGg7KJV0lye+kyiaV
  #|saPYOdoYVGlvYbxemsd/yUOPPQ2z3534PlUqANh+X00elon4Cyf9clxJ8muhySho
  #|1kMScS2hbWb2ltQgJR74rCgzR2BBgElD4r/7QjNFg91/QhaLkZn3x6eKDjjNniLD
  #|6wIDAQAB
  #|-----END PUBLIC KEY-----

///|
let test_api_v3_key : String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

///|
let platform_serial : String = "4e42d63e06e3969f7360e892f118b86f9d8ab3da"

///|
fn platform_key() -> @rsa.PrivateKey {
  @crypto.load_private_key_pem(platform_private_key_pem) catch {
    e => abort("platform fixture key must load: \{e}")
  }
}

///|
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
// The /v3/certificates answer: the platform certificate encrypted under the
// APIv3 key, exactly as WeChat delivers it.
fn certificates_body() -> String {
  let cipher = gcm_seal(
    test_api_v3_key, b"1234567890ab", platform_certificate_pem, "certificate",
  )
  let body : Json = {
    "data": [
      {
        "serial_no": platform_serial,
        "encrypt_certificate": {
          "algorithm": "AEAD_AES_256_GCM",
          "associated_data": "certificate",
          "ciphertext": @base64.encode(cipher[:]),
          "nonce": "1234567890ab",
        },
      },
    ],
  }
  @moon-pay-sdk.encode_json(body)
}

///|
// A signed, encrypted TRANSACTION.SUCCESS callback with its Wechatpay-*
// headers.
fn notification_callback() -> (Array[(String, String)], Bytes) {
  let resource = "{\"out_trade_no\":\"e2e-0001\",\"transaction_id\":\"4200009999\",\"trade_state\":\"SUCCESS\",\"amount\":{\"total\":100,\"payer_total\":100,\"currency\":\"CNY\"}}"
  let cipher = gcm_seal(
    test_api_v3_key, b"abc123def456", resource, "transaction",
  )
  let envelope : Json = {
    "id": "evt-e2e",
    "event_type": "TRANSACTION.SUCCESS",
    "resource_type": "encrypt-resource",
    "resource": {
      "algorithm": "AEAD_AES_256_GCM",
      "ciphertext": @base64.encode(cipher[:]),
      "nonce": "abc123def456",
      "associated_data": "transaction",
    },
  }
  let text = @moon-pay-sdk.encode_json(envelope)
  let message = "1600000000\ne2e-nonce\n" + text + "\n"
  let signature = @crypto.sign_rsa_sha256(
    platform_key(),
    @utf8.encode(message)[:],
  )
  let headers : Array[(String, String)] = [
    ("Wechatpay-Serial", platform_serial),
    ("Wechatpay-Timestamp", "1600000000"),
    ("Wechatpay-Nonce", "e2e-nonce"),
    ("Wechatpay-Signature", @base64.encode(signature[:])),
  ]
  (headers, @utf8.encode(text))
}

///|
fn loopback_addr() -> @socket.Addr {
  @socket.Addr::parse("127.0.0.1:0") catch {
    _ => @socket.Addr::new(2130706433U, 0)
  }
}

///|
fn app_private_key() -> @rsa.PrivateKey {
  @crypto.load_private_key_pem(merchant_private_key_pem) catch {
    e => abort("merchant fixture key must load: \{e}")
  }
}
