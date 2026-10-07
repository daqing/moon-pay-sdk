///|
// Fixture merchant key from test_keys/, same pair the wechat tests use.
let merchant_private_pem : String =
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
// The pay client wired to a mock gateway; the same setup the wechat tests
// use, pinned at 1600000000000 ms.
fn mock_pay_client(
  responses : Array[@transport.Response],
) -> (@wechat.Client, @transport.MockTransport) {
  let mock = @transport.MockTransport::new(responses)
  let client = @wechat.Client::new(
    config=@wechat.Config::new(
      appid="wx8888888888888888",
      mchid="1900000000",
      serial_no="TEST-SERIAL",
      private_key_pem=merchant_private_pem,
      api_v3_key="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      base_url="https://api.mch.weixin.qq.com",
    ),
    transport=mock,
    now_ms=() => 1600000000000L,
    verify_responses=false,
  ) catch {
    e => abort("mock pay client must build: \{e}")
  }
  (client, mock)
}

///|
fn miniapp_client(
  session_responses : Array[@transport.Response],
  pay_responses : Array[@transport.Response],
) -> (@miniprogram.Client, @transport.MockTransport, @transport.MockTransport) {
  let (pay, pay_mock) = mock_pay_client(pay_responses)
  let session_mock = @transport.MockTransport::new(session_responses)
  let client = @miniprogram.Client::new(
    config=@miniprogram.Config::new(
      app_id="wx8888888888888888",
      app_secret="test-secret",
      session_base_url="https://session.example.test",
    ),
    pay~,
    transport=session_mock,
  ) catch {
    e => abort("miniapp client must build: \{e}")
  }
  (client, session_mock, pay_mock)
}

///|
async test "code2session exchanges the login code and parses the session" {
  let (client, _, _) = miniapp_client(
    [
      {
        status: 200,
        headers: [],
        body: b"{\"openid\":\"oUpF8uMuAJO_M2pxb1Q9zNjWeS6o\",\"session_key\":\"SG1hZSB1bmRlciB0aGUgd2F0ZXI=\",\"unionid\":\"oUNION1234\"}",
      },
    ],
    [],
  )
  let session = client.code2session(js_code="081Ab2Cd3Ef4Gh5")
  assert_eq(session.openid(), "oUpF8uMuAJO_M2pxb1Q9zNjWeS6o")
  assert_eq(session.session_key(), "SG1hZSB1bmRlciB0aGUgd2F0ZXI=")
  assert_eq(session.unionid(), Some("oUNION1234"))
}

///|
async test "a login-code error maps to an Api error with its code" {
  let (client, _, _) = miniapp_client(
    [
      {
        status: 200,
        headers: [],
        body: b"{\"errcode\":40029,\"errmsg\":\"invalid code\"}",
      },
    ],
    [],
  )
  let err : @moon-pay-sdk.SdkError = try
    client.code2session(js_code="used-code")
  catch {
    e => e
  } noraise {
    _ => abort("expected an error")
  }
  assert_eq("\{err}", "api error 40029 (http 200): invalid code")
}

///|
async test "pay covers login code to wx.requestPayment params in one call" {
  let (client, session_mock, pay_mock) = miniapp_client(
    [
      {
        status: 200,
        headers: [],
        body: b"{\"openid\":\"oUpF8uMuAJO_M2pxb1Q9zNjWeS6o\",\"session_key\":\"sk\"}",
      },
    ],
    [
      {
        status: 200,
        headers: [],
        body: b"{\"prepay_id\":\"wx201410272009395522067a6904e437\"}",
      },
    ],
  )
  let result = client.pay(
    out_trade_no="hack-20261001-0005",
    total=100,
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
    js_code="081Ab2Cd3Ef4Gh5",
  )
  assert_eq(result.openid(), "oUpF8uMuAJO_M2pxb1Q9zNjWeS6o")
  assert_eq(result.out_trade_no(), "hack-20261001-0005")
  assert_eq(result.prepay_id(), "wx201410272009395522067a6904e437")
  let params = result.pay_params()
  assert_eq(params.app_id(), "wx8888888888888888")
  assert_eq(params.pay_package(), "prepay_id=wx201410272009395522067a6904e437")
  assert_eq(params.sign_type(), "RSA")
  // The session request went to the login API with the code and grant type.
  let session_request = session_mock.recorded()[0]
  assert_true(session_request.meth is Get)
  assert_true(
    session_request.url.has_prefix(
      "https://session.example.test/sns/jscode2session?",
    ),
  )
  assert_true(session_request.url.contains("appid=wx8888888888888888"))
  assert_true(session_request.url.contains("js_code=081Ab2Cd3Ef4Gh5"))
  assert_true(session_request.url.contains("grant_type=authorization_code"))
  // The pay request is a JSAPI order for the openid the session resolved.
  let pay_request = pay_mock.recorded()[0]
  assert_eq(
    pay_request.url,
    "https://api.mch.weixin.qq.com/v3/pay/transactions/jsapi",
  )
  let body = @moon-pay-sdk.parse_json(@utf8.decode(pay_request.body[:]))
  let payer = @moon-pay-sdk.object_field(body, "payer")
  assert_eq(
    @moon-pay-sdk.string_field(payer, "openid"),
    "oUpF8uMuAJO_M2pxb1Q9zNjWeS6o",
  )
}

///|
async test "a config whose app_id differs from the pay client is rejected" {
  let (pay, _) = mock_pay_client([])
  let verdict : String = try
    @miniprogram.Client::new(
      config=@miniprogram.Config::new(
        app_id="wx0000000000000000",
        app_secret="test-secret",
      ),
      pay~,
      transport=@transport.MockTransport::new([]),
    )
  catch {
    @moon-pay-sdk.Config(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "built"
  }
  assert_eq(verdict, "rejected")
}

///|
async test "an empty login code is rejected without a request" {
  let (client, session_mock, _) = miniapp_client([], [])
  let verdict : String = try client.code2session(js_code="") catch {
    @moon-pay-sdk.Config(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
  assert_eq(session_mock.recorded().length(), 0)
}
