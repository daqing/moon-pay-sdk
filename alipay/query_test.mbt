///|
// The query answer body for one trade status, signed with the app key so
// the client's Alipay-public-key check passes.
fn query_response(trade_status : String, total_amount : String) -> Bytes {
  let payload = "{\"code\":\"10000\",\"msg\":\"Success\",\"out_trade_no\":\"hack-20261001-0002\",\"trade_no\":\"2026100222001\",\"trade_status\":\"\{trade_status}\",\"total_amount\":\"\{total_amount}\",\"send_pay_date\":\"2026-10-02 08:30:00\"}"
  let signature = @alipay.sign_params(app_private_key(), [
    ("alipay_trade_query_response", payload),
    ("sign_type", "RSA2"),
  ])
  let body = "{\"alipay_trade_query_response\":" +
    payload +
    ",\"sign\":\"" +
    signature +
    "\"}"
  @utf8.encode(body)
}

///|
async test "order query verifies the response and parses the status" {
  let responses : Array[@transport.Response] = [
    {
      status: 200,
      headers: [],
      body: query_response("TRADE_SUCCESS", "88.00"),
    },
  ]
  let (client, mock) = mock_client(responses~)
  let status = client.query_order(out_trade_no="hack-20261001-0002")
  assert_eq(status.out_trade_no(), "hack-20261001-0002")
  assert_eq(status.trade_no(), "2026100222001")
  assert_true(status.trade_status() is TradeSuccess)
  assert_eq(status.total_amount(), "88.00")
  assert_eq(status.total_fen(), 8800)
  assert_eq(status.send_pay_date(), Some("2026-10-02 08:30:00"))
  let request = mock.recorded()[0]
  assert_true(request.meth is Post)
  assert_eq(request.url, "https://openapi.alipay.com/gateway.do")
  let sent = @alipay.percent_decode(@utf8.decode(request.body[:]))
  assert_true(
    sent.has_prefix("app_id=2021000000000000&method=alipay.trade.query"),
  )
  assert_true(
    sent.contains("biz_content={\"out_trade_no\":\"hack-20261001-0002\"}"),
  )
}

///|
async test "all documented trade statuses are recognized" {
  let states : Array[String] = [
    "WAIT_BUYER_PAY", "TRADE_CLOSED", "TRADE_SUCCESS", "TRADE_FINISHED",
  ]
  let responses : Array[@transport.Response] = states
    .rev()
    .map(fn(state) {
      { status: 200, headers: [], body: query_response(state, "88.00"), }
    })
  let (client, _) = mock_client(responses~)
  for i in 0..<states.length() {
    let status = client.query_order(out_trade_no="hack-20261001-0002")
    let same = match (status.trade_status(), states[i]) {
      (WaitBuyerPay, "WAIT_BUYER_PAY") => true
      (TradeClosed, "TRADE_CLOSED") => true
      (TradeSuccess, "TRADE_SUCCESS") => true
      (TradeFinished, "TRADE_FINISHED") => true
      _ => false
    }
    assert_true(same)
  }
}

///|
async test "provider errors map to Api errors with their code" {
  let responses : Array[@transport.Response] = [
    {
      status: 200,
      headers: [],
      body: b"{\"alipay_trade_query_response\":{\"code\":\"40004\",\"msg\":\"Business Failed\",\"sub_msg\":\"ACQ.TRADE_NOT_EXIST\"}}",
    },
  ]
  let (client, _) = mock_client(responses~)
  let err : @moon-pay-sdk.SdkError = try
    client.query_order(out_trade_no="hack-20261001-0002")
  catch {
    e => e
  } noraise {
    _ => abort("expected an error")
  }
  assert_eq("\{err}", "api error 40004 (http 200): ACQ.TRADE_NOT_EXIST")
}

///|
async test "a tampered query response fails signature verification" {
  // Signed for 88.00 but answering 0.01.
  let payload = "{\"code\":\"10000\",\"msg\":\"Success\",\"out_trade_no\":\"hack-20261001-0002\",\"trade_no\":\"2026100222001\",\"trade_status\":\"TRADE_SUCCESS\",\"total_amount\":\"0.01\"}"
  let signature = @alipay.sign_params(app_private_key(), [
    ("alipay_trade_query_response", payload),
    ("sign_type", "RSA2"),
  ])
  let swapped_payload = "{\"code\":\"10000\",\"msg\":\"Success\",\"out_trade_no\":\"hack-20261001-0002\",\"trade_no\":\"2026100222001\",\"trade_status\":\"TRADE_SUCCESS\",\"total_amount\":\"88.00\"}"
  let body = "{\"alipay_trade_query_response\":" +
    swapped_payload +
    ",\"sign\":\"" +
    signature +
    "\"}"
  let responses : Array[@transport.Response] = [
    { status: 200, headers: [], body: @utf8.encode(body), },
  ]
  let (client, _) = mock_client(responses~)
  let verdict : String = try
    client.query_order(out_trade_no="hack-20261001-0002")
  catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "query response signature verification failed")
}
