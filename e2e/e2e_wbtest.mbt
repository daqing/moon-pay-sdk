///|
// End to end: the WeChat client talks to a local provider over real HTTP —
// native order first, then a signed callback verified against the platform
// certificate the same provider serves.
async test "wechat end to end over loopback http" {
  @async.with_task_group <| group => {
    let server = @http.Server::Server(loopback_addr())
    let port = server.addr.port()
    group.spawn_bg(no_wait=true, () => {
      server.run_forever(
        async fn(req, reader, conn) {
          let _ = reader.read_all()
          let auth = match
            req.headers.get(@http.CaseInsensitiveString("authorization")) {
            Some(value) => value
            None => "missing"
          }
          if req.path.has_prefix("/v3/pay/transactions/native") {
            // The provider only answers properly signed requests.
            if auth.has_prefix("WECHATPAY2-SHA256-RSA2048 ") {
              conn.send_response(200, "OK")
              conn.write_string(
                "{\"code_url\":\"weixin://wxpay/bizpayurl?pr=e2e\"}",
              )
            } else {
              conn.send_response(401, "Unauthorized")
            }
            conn.end_response()
          } else if req.path.has_prefix("/v3/certificates") {
            conn.send_response(200, "OK")
            conn.write_string(certificates_body())
            conn.end_response()
          } else {
            conn.send_response(404, "Not Found")
            conn.end_response()
          }
        },
        allow_failure=true,
      )
    })
    let http = @transport.HttpClient::new()
    let client = @wechat.Client::new(
      config=@wechat.Config::new(
        appid="wx8888888888888888",
        mchid="1900000000",
        serial_no="TEST-SERIAL",
        private_key_pem=merchant_private_key_pem,
        api_v3_key=test_api_v3_key,
        base_url="http://127.0.0.1:\{port}",
      ),
      transport=http,
      now_ms=() => 1600000000000L,
      verify_responses=false,
    ) catch {
      e => abort("client must build: \{e}")
    }
    // 1. Create the order over real HTTP.
    let order = client.native_order(
      out_trade_no="e2e-0001",
      total=100,
      description="MoonBit Hackathon Ticket",
      notify_url="https://example.com/callback/wechat",
    )
    assert_eq(order.code_url(), "weixin://wxpay/bizpayurl?pr=e2e")
    // 2. The provider posts a signed callback; verify, decrypt and parse it.
    let (headers, body) = notification_callback()
    let notification = client.verify_callback(headers, body)
    assert_eq(notification.out_trade_no(), "e2e-0001")
    assert_true(notification.trade_state() is @wechat.Success)
    assert_eq(notification.total_fen(), 100)
    // 3. Acknowledge the way WeChat requires.
    let (ack_status, ack_body) = @wechat.ack_success()
    assert_eq(ack_status, 200)
    assert_true(ack_body.contains("SUCCESS"))
    server.close()
  }
}

///|
// End to end: the Alipay client builds a signed redirect and verifies a
// signed notification, reconciling the amount against the local order.
async test "alipay end to end: redirect then notification" {
  let mock = @transport.MockTransport::new([])
  let client = @alipay.Client::new(
    config=@alipay.Config::new(
      app_id="2021000000000000",
      private_key_pem=merchant_private_key_pem,
      alipay_public_key_pem=merchant_public_key_pem,
      gateway_url="https://openapi.alipay.com/gateway.do",
    ),
    transport=mock,
    now_ms=() => 1600000000000L,
  ) catch {
    e => abort("client must build: \{e}")
  }
  // 1. The redirect URL for desktop checkout.
  let url = client.page_pay_url(
    out_trade_no="e2e-0002",
    total_fen=8800,
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/notify/alipay",
    return_url="https://example.com/thanks",
  )
  assert_true(url.has_prefix("https://openapi.alipay.com/gateway.do?"))
  assert_true(url.contains("method=alipay.trade.page.pay"))
  // 2. The provider posts the async notification; verify and reconcile.
  let unsigned : Array[(String, String)] = [
    ("app_id", "2021000000000000"),
    ("trade_status", "TRADE_SUCCESS"),
    ("out_trade_no", "e2e-0002"),
    ("trade_no", "2026100299999"),
    ("total_amount", "88.00"),
    ("seller_id", "2088test"),
    ("sign_type", "RSA2"),
  ]
  let signature = @alipay.sign_content(
    app_private_key(),
    @alipay.build_sign_content(unsigned),
  )
  let form : Array[(String, String)] = []
  for pair in unsigned {
    form.push((@alipay.percent_encode(pair.0), @alipay.percent_encode(pair.1)))
  }
  form.push(("sign", @alipay.percent_encode(signature)))
  let notify = client.verify_notify(form)
  assert_true(notify.trade_status() is @alipay.TradeSuccess)
  assert_eq(notify.out_trade_no(), "e2e-0002")
  assert_true(notify.amount_matches(8800))
  // 3. Acknowledge the way Alipay requires.
  inspect(@alipay.ack_success(), content="success")
}
