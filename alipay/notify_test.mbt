///|
// A signed notification form for one trade status and amount.
fn notification_form(
  trade_status : String,
  total_amount : String,
  app_id : String,
) -> Array[(String, String)] {
  let unsigned : Array[(String, String)] = [
    ("app_id", app_id),
    ("trade_status", trade_status),
    ("out_trade_no", "hack-20261001-0002"),
    ("trade_no", "2026100222001"),
    ("total_amount", total_amount),
    ("seller_id", "2088test"),
    ("sign_type", "RSA2"),
  ]
  let signature = @alipay.sign_params(app_private_key(), unsigned)
  unsigned.push(("sign", signature))
  // On the wire the form is urlencoded; verify_notify decodes it again.
  let encoded : Array[(String, String)] = []
  for pair in unsigned {
    encoded.push(
      (@alipay.percent_encode(pair.0), @alipay.percent_encode(pair.1)),
    )
  }
  encoded
}

///|
async test "a valid notification is verified and parsed" {
  let (client, _) = mock_client()
  let notify = client.verify_notify(
    notification_form("TRADE_SUCCESS", "88.00", "2021000000000000"),
  )
  assert_true(notify.trade_status() is TradeSuccess)
  assert_eq(notify.out_trade_no(), "hack-20261001-0002")
  assert_eq(notify.trade_no(), "2026100222001")
  assert_eq(notify.total_amount(), "88.00")
  assert_eq(notify.total_fen(), 8800)
  assert_eq(notify.app_id(), "2021000000000000")
  assert_eq(notify.seller_id(), Some("2088test"))
  // Amount reconciliation against the local order.
  assert_true(notify.amount_matches(8800))
  assert_false(notify.amount_matches(100))
}

///|
async test "a tampered notification amount fails verification" {
  let (client, _) = mock_client()
  let form = notification_form("TRADE_SUCCESS", "88.00", "2021000000000000")
  let tampered : Array[(String, String)] = []
  for pair in form {
    if pair.0 == "total_amount" {
      tampered.push((pair.0, "0.01"))
    } else {
      tampered.push(pair)
    }
  }
  let verdict : String = try client.verify_notify(tampered) catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "notification signature verification failed")
}

///|
async test "a notification for another app_id is rejected" {
  let (client, _) = mock_client()
  // Properly signed, but by a different application's identity.
  let form = notification_form("TRADE_SUCCESS", "88.00", "2021999999999999")
  let verdict : String = try client.verify_notify(form) catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(
    verdict, "notification app_id \"2021999999999999\" does not match this client",
  )
}

///|
test "form bodies parse into encoded pairs" {
  let pairs = @alipay.parse_form_params(
    "trade_status=TRADE_SUCCESS&total_amount=88.00&subject=a%20b",
  )
  assert_eq(pairs.length(), 3)
  assert_eq(@alipay.percent_decode(pairs[2].1), "a b")
}
