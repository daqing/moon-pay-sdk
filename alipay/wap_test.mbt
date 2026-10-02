///|
async test "wap pay url targets the wap method with the order fields" {
  let (client, _) = mock_client()
  let url = client.wap_pay_url(
    out_trade_no="hack-20261001-0003",
    total_fen=8800,
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
  )
  assert_true(url.has_prefix("https://openapi.alipay.com/gateway.do?"))
  let params = query_pairs(url)
  let decoded : Array[(String, String)] = []
  for pair in params {
    decoded.push(
      (@alipay.percent_decode(pair.0), @alipay.percent_decode(pair.1)),
    )
  }
  assert_eq(lookup_value(decoded, "method"), "alipay.trade.wap.pay")
  let biz = @moon-pay-sdk.parse_json(lookup_value(decoded, "biz_content"))
  assert_eq(
    @moon-pay-sdk.string_field(biz, "out_trade_no"),
    "hack-20261001-0003",
  )
  assert_eq(@moon-pay-sdk.string_field(biz, "total_amount"), "88.00")
  assert_eq(
    lookup_value(decoded, "notify_url"),
    "https://example.com/callback/alipay",
  )
  // No return_url is sent for wap orders.
  assert_eq(lookup_value(decoded, "return_url"), "")
  let signature = lookup_value(decoded, "sign")
  assert_true(client.verify_signature(decoded, signature[:]))
}

///|
async test "wap pay url rejects a bad order number locally" {
  let (client, mock) = mock_client()
  let verdict : String = try
    client.wap_pay_url(
      out_trade_no="bad/order",
      total_fen=100,
      subject="x",
      notify_url="https://example.com/cb",
    )
  catch {
    @moon-pay-sdk.Config(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
  assert_eq(mock.recorded().length(), 0)
}
