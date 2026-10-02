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
let alipay_public_key_pem : String =
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
// In production alipay_public_key_pem is Alipay's own key; the tests use the
// merchant pair so signatures round-trip locally.

///|
fn app_private_key() -> @rsa.PrivateKey {
  @crypto.load_private_key_pem(merchant_private_key_pem) catch {
    e => abort("fixture key must load: \{e}")
  }
}

///|
fn alipay_config() -> @alipay.Config {
  @alipay.Config::new(
    app_id="2021000000000000",
    private_key_pem=merchant_private_key_pem,
    alipay_public_key_pem~,
  )
}

///|
test "sign content is sorted, without sign and sign_type" {
  let content = @alipay.build_sign_content([
    ("version", "1.0"),
    ("sign_type", "RSA2"),
    ("charset", "utf-8"),
    ("method", "alipay.trade.page.pay"),
    ("sign", "IGNORED"),
    ("app_id", "2021000000000000"),
    ("biz_content", "{\"out_trade_no\":\"T6GOLDEN\"}"),
  ])
  assert_eq(
    content, "app_id=2021000000000000&biz_content={\"out_trade_no\":\"T6GOLDEN\"}&charset=utf-8&method=alipay.trade.page.pay&version=1.0",
  )
}

///|
test "parameter signing matches the openssl reference signature" {
  // Reference generated with:
  //   printf 'app_id=2021000000000000&biz_content={"out_trade_no":"T6GOLDEN","total_amount":"88.00"}&charset=utf-8&format=JSON&method=alipay.trade.page.pay&timestamp=2026-10-02 08:00:00&version=1.0' > msg
  //   openssl dgst -sha256 -sign test_keys/merchant_private_key.pem -out sig msg
  //   base64 < sig
  let signature = @alipay.sign_params(app_private_key(), [
    ("app_id", "2021000000000000"),
    ("method", "alipay.trade.page.pay"),
    ("format", "JSON"),
    ("charset", "utf-8"),
    ("sign_type", "RSA2"),
    ("timestamp", "2026-10-02 08:00:00"),
    ("version", "1.0"),
    (
      "biz_content", "{\"out_trade_no\":\"T6GOLDEN\",\"total_amount\":\"88.00\"}",
    ),
  ])
  assert_eq(
    signature, "bhro797ndGGnMr67hO/0mmhwOOf2s1Nohr13ANZzwpJOCDcfkR5ROPeYBEdZAVsEWqrkoDGouEQ7ecjIKZEDCoGcH39qBPS3yf2IdWaaH14rvAw91x7abP4NO+/PJpbO3YYlyo7jbORP7G2cikHaklfi91FVT+TpDvyQEu1RUDIcJKGSXGFxTcHDuzXa5HfQ1l4t7HV2Xg5kN2OcTMDSLv0ZhmdYJz/1FRGzVjuEm3K3Co8Ybi0xXrnHUTK1/NL3ySkn/2MZdMOaGLZnsNLjEt/sj8aY0UOlP54o/L3K/77o9+IEUi3J2OKLFEC10ZYojwA1rsg7jPzr+C6OYem5yA==",
  )
}

///|
test "timestamps render as Beijing time" {
  // 1600000000 s = 2020-09-13 12:26:40 UTC = 2020-09-13 20:26:40 Beijing.
  assert_eq(@alipay.format_beijing(1600000000000L), "2020-09-13 20:26:40")
  // 1769961600 s = 2026-02-01 16:00:00 UTC = 2026-02-02 00:00:00 Beijing.
  assert_eq(@alipay.format_beijing(1769961600000L), "2026-02-02 00:00:00")
  // Epoch start in Beijing is 08:00 on 1970-01-01.
  assert_eq(@alipay.format_beijing(0L), "1970-01-01 08:00:00")
}

///|
test "system params carry the fixed fields plus optional urls" {
  let params = @alipay.system_params(
    alipay_config(),
    api_method="alipay.trade.query",
    timestamp="2026-10-02 08:00:00",
  )
  let lookup = fn(key : String) -> String {
    let mut found = ""
    for pair in params {
      if pair.0 == key {
        found = pair.1
      }
    }
    found
  }
  assert_eq(lookup("app_id"), "2021000000000000")
  assert_eq(lookup("method"), "alipay.trade.query")
  assert_eq(lookup("sign_type"), "RSA2")
  assert_eq(lookup("version"), "1.0")
  assert_eq(lookup("notify_url"), "")
}
