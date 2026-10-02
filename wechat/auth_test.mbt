///|
// Fixture merchant key from test_keys/, regenerated per test_keys/README.md.
let merchant_pem : String =
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
let auth_config : @wechat.Config = @wechat.Config::new(
  appid="wx8888888888888888",
  mchid="1900000000",
  serial_no="TEST-SERIAL",
  private_key_pem=merchant_pem,
  api_v3_key="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
)

///|
fn merchant_key() -> @rsa.PrivateKey {
  @crypto.load_private_key_pem(merchant_pem) catch {
    e => abort("fixture key must load: \{e}")
  }
}

///|
test "sign message follows the v3 canonical form" {
  let message = @wechat.build_sign_message(
    meth="POST",
    path="/v3/pay/transactions/native",
    timestamp=1600000000L,
    nonce="mymoonnonce",
    body="{\"out_trade_no\":\"T4GOLDEN\"}",
  )
  assert_eq(
    message, "POST\n/v3/pay/transactions/native\n1600000000\nmymoonnonce\n{\"out_trade_no\":\"T4GOLDEN\"}\n",
  )
}

///|
test "authorization header matches the openssl reference signature" {
  // Reference generated with:
  //   printf 'POST\n/v3/pay/transactions/native\n1600000000\nmymoonnonce\n{"out_trade_no":"T4GOLDEN"}\n' > msg
  //   openssl dgst -sha256 -sign test_keys/merchant_private_key.pem -out sig msg
  //   base64 < sig
  let header = @wechat.authorization_header(
    auth_config,
    merchant_key(),
    meth="POST",
    path="/v3/pay/transactions/native",
    timestamp=1600000000L,
    nonce="mymoonnonce",
    body="{\"out_trade_no\":\"T4GOLDEN\"}",
  )
  assert_eq(
    header, "WECHATPAY2-SHA256-RSA2048 mchid=\"1900000000\",nonce_str=\"mymoonnonce\",signature=\"DAduXxwPIc2IKJsfsblozTR037giArJWRvzJbNBhg5Aq0y4GBLMwG+63AhXBk9xv6mNMY2ELSHN9vZssZt65sY24/Y3xgdzMpc5u4ZEDLHw7IhjIgcUhKkfZRIn1rj89K7xstQJbAeLAGmsKlR0JsH8jvmnnxwLejrdigAxqfSHvHMNQS0XQVXF9JBpxy26FN55bbor7hncn8s2P0G0refCvVA8iUROlSNXitOf65+9OnNZvf0gTqg0FiiEwFYOJbMb0iYixWi7TBqycHjsGFqy2ZZYYta8QtJn4cdrdzOndS9GqrXC1gUe310h0vFrCHmLADmRHyZLvt3wBvIEz9A==\",timestamp=\"1600000000\",serial_no=\"TEST-SERIAL\"",
  )
}
