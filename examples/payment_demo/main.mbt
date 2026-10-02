///|
/// Walk the whole payment story once, against a local mock provider:
///
/// 1. WeChat Pay — create a Native (QR) order over real HTTP, then receive,
///    verify and decrypt a signed callback, and acknowledge it.
/// 2. Alipay — build the signed desktop-checkout redirect, then receive,
///    verify and reconcile a signed async notification, and acknowledge it.
///
/// All keys are the test-only fixtures from test_keys/. Nothing here talks to
/// a real provider and no real money can move.
async fn demo_wechat(port : Int) -> Unit {
  println(
    "── WeChat Pay ─────────────────────────────────────────",
  )
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
    e => abort("wechat client failed: \{e}")
  }
  // 1. Create a QR order; render order.code_url() as a QR code in production.
  let order = client.native_order(
    out_trade_no="demo-0001",
    total=100,
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
  ) catch {
    e => abort("native order failed: \{e}")
  }
  println("order created, QR content: \{order.code_url()}")
  // 2. The provider posts a signed callback; verify, decrypt and parse it.
  let (headers, body) = wechat_callback()
  let notification = client.verify_callback(headers, body) catch {
    e => abort("callback verification failed: \{e}")
  }
  if notification.trade_state() is @wechat.Success {
    println(
      "callback verified: \{notification.out_trade_no()} paid \{notification.total_fen()} fen (transaction \{notification.transaction_id()})",
    )
  } else {
    println("callback verified, but the order is not paid yet")
  }
  // 3. Acknowledge so the provider stops retrying.
  let (status, ack_body) = @wechat.ack_success()
  println("ack: http \{status} \{ack_body}")
}

///|
fn demo_alipay() -> Unit {
  println(
    "── Alipay ─────────────────────────────────────────────",
  )
  let mock = @transport.MockTransport::new([])
  let client = @alipay.Client::new(
    config=@alipay.Config::new(
      app_id="2021000000000000",
      private_key_pem=merchant_private_key_pem,
      alipay_public_key_pem~,
    ),
    transport=mock,
    now_ms=() => 1600000000000L,
  ) catch {
    e => abort("alipay client failed: \{e}")
  }
  // 1. The signed desktop-checkout redirect; send the customer there.
  let url = client.page_pay_url(
    out_trade_no="demo-0002",
    total_fen=8800,
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/notify/alipay",
    return_url="https://example.com/thanks",
  ) catch {
    e => abort("page pay url failed: \{e}")
  }
  println(
    "checkout redirect (first 100 chars): \{url.substring(start=0, end=100)}…",
  )
  // 2. The provider posts a signed notification; verify and reconcile it
  //    against the local order amount.
  let unsigned : Array[(String, String)] = [
    ("app_id", "2021000000000000"),
    ("trade_status", "TRADE_SUCCESS"),
    ("out_trade_no", "demo-0002"),
    ("trade_no", "2026100200001"),
    ("total_amount", "88.00"),
    ("seller_id", "2088demo"),
    ("sign_type", "RSA2"),
  ]
  let signature = @alipay.sign_params(app_private_key(), unsigned)
  let form : Array[(String, String)] = []
  for pair in unsigned {
    form.push((@alipay.percent_encode(pair.0), @alipay.percent_encode(pair.1)))
  }
  form.push(("sign", @alipay.percent_encode(signature)))
  let notify = client.verify_notify(form) catch {
    e => abort("notification verification failed: \{e}")
  }
  if notify.amount_matches(8800) &&
    notify.trade_status() is @alipay.TradeSuccess {
    println(
      "notification verified: \{notify.out_trade_no()} paid \{notify.total_amount()} CNY (trade \{notify.trade_no()})",
    )
  } else {
    println("notification verified, but the amount or status does not match")
  }
  // 3. Acknowledge so Alipay stops retrying.
  println("ack: \{@alipay.ack_success()}")
}

///|
async fn main {
  let server = @http.Server::Server(loopback_addr())
  let port = server.addr.port()
  @async.with_task_group <| group => {
    group.spawn_bg(no_wait=true, () => {
      server.run_forever(
        async fn(req, reader, conn) {
          let _ = reader.read_all()
          if req.path.has_prefix("/v3/certificates") {
            conn.send_response(200, "OK")
            conn.write_string(certificates_body())
            conn.end_response()
          } else if req.path.has_prefix("/v3/pay/transactions/native") {
            conn.send_response(200, "OK")
            conn.write_string(
              "{\"code_url\":\"weixin://wxpay/bizpayurl?pr=demo\"}",
            )
            conn.end_response()
          } else {
            conn.send_response(404, "Not Found")
            conn.end_response()
          }
        },
        allow_failure=true,
      )
    })
    demo_wechat(port)
    demo_alipay()
    server.close()
  }
  println(
    "── demo finished ──────────────────────────────────────",
  )
}
