///|
async test "h5 order posts scene_info and parses h5_url" {
  let (client, mock) = mock_client([
    {
      status: 200,
      headers: [],
      body: b"{\"h5_url\":\"https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb?prepay_id=wx123\"}",
    },
  ])
  let order = client.h5_order(
    out_trade_no="hack-20261001-0002",
    total=8800,
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
    payer_client_ip="203.0.113.7",
  )
  assert_eq(
    order.h5_url(),
    "https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb?prepay_id=wx123",
  )
  let request = mock.recorded()[0]
  assert_eq(request.url, "https://api.mch.weixin.qq.com/v3/pay/transactions/h5")
  assert_true(request.meth is Post)
  let body = @moon-pay-sdk.parse_json(@utf8.decode(request.body[:]))
  assert_eq(
    @moon-pay-sdk.string_field(body, "out_trade_no"),
    "hack-20261001-0002",
  )
  let scene_info = @moon-pay-sdk.object_field(body, "scene_info")
  assert_eq(
    @moon-pay-sdk.string_field(scene_info, "payer_client_ip"),
    "203.0.113.7",
  )
  assert_eq(@moon-pay-sdk.string_field(scene_info, "scene_type"), "H5")
  let amount = @moon-pay-sdk.object_field(body, "amount")
  assert_eq(@moon-pay-sdk.int_field(amount, "total"), 8800)
}

///|
async test "h5 order rejects an empty client ip before any request" {
  let (client, mock) = mock_client([])
  let verdict : String = try
    client.h5_order(
      out_trade_no="hack-20261001-0002",
      total=8800,
      description="x",
      notify_url="https://example.com/cb",
      payer_client_ip="",
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
