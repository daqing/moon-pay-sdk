///|
fn status_response(trade_state : String) -> @transport.Response {
  {
    status: 200,
    headers: [],
    body: @utf8.encode(
      "{\"out_trade_no\":\"hack-20261001-0001\",\"transaction_id\":\"4200001234\",\"trade_state\":\"\{trade_state}\",\"amount\":{\"total\":100,\"payer_total\":100,\"currency\":\"CNY\",\"payer_currency\":\"CNY\"},\"success_time\":\"2026-10-02T08:00:00+08:00\"}",
    ),
  }
}

///|
async test "query by out_trade_no sends a signed GET and parses the status" {
  let (client, mock) = mock_client([status_response("SUCCESS")])
  let status = client.query_order(out_trade_no="hack-20261001-0001")
  assert_eq(status.out_trade_no(), "hack-20261001-0001")
  assert_eq(status.transaction_id(), "4200001234")
  assert_true(status.trade_state() is Success)
  assert_eq(status.total_fen(), 100)
  assert_eq(status.payer_fen(), Some(100))
  assert_eq(status.success_time(), Some("2026-10-02T08:00:00+08:00"))
  let request = mock.recorded()[0]
  assert_true(request.meth is Get)
  assert_eq(
    request.url,
    "https://api.mch.weixin.qq.com/v3/pay/transactions/out-trade-no/hack-20261001-0001?mchid=1900000000",
  )
  let auth = request.headers[0].1
  assert_true(auth.has_prefix("WECHATPAY2-SHA256-RSA2048 mchid=\"1900000000\""))
  assert_true(auth.contains("timestamp=\"1600000000\""))
  assert_eq(request.body, b"")
}

///|
async test "query by transaction id uses the id route" {
  let (client, mock) = mock_client([status_response("SUCCESS")])
  let status = client.query_order_by_id(transaction_id="4200001234")
  assert_eq(status.transaction_id(), "4200001234")
  assert_eq(
    mock.recorded()[0].url,
    "https://api.mch.weixin.qq.com/v3/pay/transactions/id/4200001234?mchid=1900000000",
  )
}

///|
async test "all documented trade states are recognized" {
  let states : Array[String] = [
    "SUCCESS", "REFUND", "NOTPAY", "CLOSED", "REVOKED", "USERPAYING", "PAYERROR",
  ]
  let expected : Array[TradeState] = [
    Success,
    Refund,
    NotPay,
    Closed,
    Revoked,
    UserPaying,
    PayError,
  ]
  let responses = states.rev().map(fn(state) { status_response(state) })
  let (client, _) = mock_client(responses)
  for i in 0..<states.length() {
    let status = client.query_order(out_trade_no="hack-20261001-0001")
    let want = expected[i]
    let got = status.trade_state()
    let same = match (got, want) {
      (Success, Success) => true
      (Refund, Refund) => true
      (NotPay, NotPay) => true
      (Closed, Closed) => true
      (Revoked, Revoked) => true
      (UserPaying, UserPaying) => true
      (PayError, PayError) => true
      _ => false
    }
    assert_true(same)
  }
}

///|
async test "unknown trade states degrade to Unknown with the raw text" {
  let (client, _) = mock_client([status_response("FUTURE_STATE")])
  let status = client.query_order(out_trade_no="hack-20261001-0001")
  assert_eq(status.trade_state(), Unknown("FUTURE_STATE"))
}

///|
async test "a missing order maps to the provider's ORDER_NOT_EXIST" {
  let (client, _) = mock_client([
    {
      status: 404,
      headers: [],
      body: b"{\"code\":\"ORDER_NOT_EXIST\",\"message\":\"order does not exist\"}",
    },
  ])
  let err : @moon-pay-sdk.SdkError = try
    client.query_order(out_trade_no="hack-20261001-0001")
  catch {
    e => e
  } noraise {
    _ => abort("expected an error")
  }
  assert_eq(
    "\{err}",
    "api error ORDER_NOT_EXIST (http 404): order does not exist",
  )
}

///|
async test "payer_total may be absent" {
  let (client, _) = mock_client([
    {
      status: 200,
      headers: [],
      body: @utf8.encode(
        "{\"out_trade_no\":\"hack-20261001-0001\",\"transaction_id\":\"4200001234\",\"trade_state\":\"NOTPAY\",\"amount\":{\"total\":100,\"currency\":\"CNY\"}}",
      ),
    },
  ])
  let status = client.query_order(out_trade_no="hack-20261001-0001")
  assert_true(status.trade_state() is NotPay)
  assert_eq(status.payer_fen(), None)
  assert_eq(status.success_time(), None)
}
