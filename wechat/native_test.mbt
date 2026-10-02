///|
// A client wired to a mock transport with a pinned clock; test_keys/ key.
fn mock_client(
  responses : Array[@transport.Response],
  verify_responses? : Bool = false,
) -> (@wechat.Client, @transport.MockTransport) {
  let mock = @transport.MockTransport::new(responses)
  let client = @wechat.Client::new(
    config=@wechat.Config::new(
      appid="wx8888888888888888",
      mchid="1900000000",
      serial_no="TEST-SERIAL",
      private_key_pem=merchant_pem,
      api_v3_key="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      base_url="https://api.mch.weixin.qq.com",
    ),
    transport=mock,
    now_ms=() => 1600000000000L,
    verify_responses~,
  ) catch {
    e => abort("mock client must build: \{e}")
  }
  (client, mock)
}

///|
async test "native order sends the signed request and parses code_url" {
  let (client, mock) = mock_client([
    {
      status: 200,
      headers: [],
      body: b"{\"code_url\":\"weixin://wxpay/bizpayurl?pr=abc123\"}",
    },
  ])
  let order = client.native_order(
    out_trade_no="hack-20261001-0001",
    total=100,
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
  )
  assert_eq(order.code_url(), "weixin://wxpay/bizpayurl?pr=abc123")
  let sent = mock.recorded()
  assert_eq(sent.length(), 1)
  let request = sent[0]
  assert_true(request.meth is Post)
  assert_eq(
    request.url,
    "https://api.mch.weixin.qq.com/v3/pay/transactions/native",
  )
  // The Authorization header carries the pinned timestamp and the merchant
  // identity; the nonce is random so only the prefix and fields are checked.
  let auth = match request.headers[0] {
    (name, value) => if name == "Authorization" { value } else { "" }
  }
  assert_true(
    auth.has_prefix(
      "WECHATPAY2-SHA256-RSA2048 mchid=\"1900000000\",nonce_str=\"",
    ),
  )
  assert_true(auth.contains("timestamp=\"1600000000\""))
  assert_true(auth.contains("serial_no=\"TEST-SERIAL\""))
  // The request body carries the order fields in fen.
  let body = @moon-pay-sdk.parse_json(@utf8.decode(request.body[:]))
  assert_eq(@moon-pay-sdk.string_field(body, "appid"), "wx8888888888888888")
  assert_eq(@moon-pay-sdk.string_field(body, "mchid"), "1900000000")
  assert_eq(
    @moon-pay-sdk.string_field(body, "description"),
    "MoonBit Hackathon Ticket",
  )
  assert_eq(
    @moon-pay-sdk.string_field(body, "out_trade_no"),
    "hack-20261001-0001",
  )
  assert_eq(
    @moon-pay-sdk.string_field(body, "notify_url"),
    "https://example.com/callback/wechat",
  )
  let amount = @moon-pay-sdk.object_field(body, "amount")
  assert_eq(@moon-pay-sdk.int_field(amount, "total"), 100)
  assert_eq(@moon-pay-sdk.string_field(amount, "currency"), "CNY")
}

///|
async test "native order rejects invalid amounts before any request" {
  let (client, mock) = mock_client([])
  let verdict : String = try
    client.native_order(
      out_trade_no="hack-20261001-0001",
      total=0,
      description="x",
      notify_url="https://example.com/cb",
    )
  catch {
    @moon-pay-sdk.Config(_) => "rejected locally"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected locally")
  assert_eq(mock.recorded().length(), 0)
}

///|
async test "provider rejections become Api errors with their code" {
  let (client, _) = mock_client([
    {
      status: 400,
      headers: [],
      body: b"{\"code\":\"PARAM_ERROR\",\"message\":\"invalid request\"}",
    },
  ])
  let err : @moon-pay-sdk.SdkError = try
    client.native_order(
      out_trade_no="hack-20261001-0001",
      total=100,
      description="x",
      notify_url="https://example.com/cb",
    )
  catch {
    e => e
  } noraise {
    _ => abort("expected an error")
  }
  assert_eq("\{err}", "api error PARAM_ERROR (http 400): invalid request")
}
