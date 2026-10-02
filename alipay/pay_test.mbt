///|
fn mock_client() -> (@alipay.Client, @transport.MockTransport) {
  let mock = @transport.MockTransport::new([])
  let client = @alipay.Client::new(config=alipay_config(), transport=mock, now_ms=() => {
    1600000000000L
  }) catch {
    e => abort("mock client must build: \{e}")
  }
  (client, mock)
}

///|
// Split a query string into raw (key, value) pairs without decoding.
fn query_pairs(url : StringView) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  let text = url.to_owned()
  let question = text.find("?")
  let start = match question {
    Some(index) => index + 1
    None => 0
  }
  let rest = text.substring(start~)
  for chunk in rest.split("&") {
    let eq = chunk.find("=")
    let eq = match eq {
      Some(index) => index
      None => chunk.length()
    }
    pairs.push((chunk[0:eq].to_owned(), chunk[eq + 1:].to_owned()))
  }
  pairs
}

///|
async test "page pay url carries the signed order parameters" {
  let (client, _) = mock_client()
  let url = client.page_pay_url(
    out_trade_no="hack-20261001-0002",
    total_fen=8800,
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
    return_url="https://example.com/thanks",
  )
  assert_true(url.has_prefix("https://openapi.alipay.com/gateway.do?"))
  // The signed parameter set, recovered from the URL.
  let params = query_pairs(url)
  let decoded : Array[(String, String)] = []
  for pair in params {
    decoded.push(
      (@alipay.percent_decode(pair.0), @alipay.percent_decode(pair.1)),
    )
  }
  let lookup = fn(key : String) -> String {
    let mut found = ""
    for pair in decoded {
      if pair.0 == key {
        found = pair.1
      }
    }
    found
  }
  assert_eq(lookup("method"), "alipay.trade.page.pay")
  assert_eq(lookup("app_id"), "2021000000000000")
  assert_eq(lookup("timestamp"), "2020-09-13 20:26:40")
  assert_eq(lookup("notify_url"), "https://example.com/callback/alipay")
  assert_eq(lookup("return_url"), "https://example.com/thanks")
  let biz = @moon-pay-sdk.parse_json(lookup("biz_content"))
  assert_eq(
    @moon-pay-sdk.string_field(biz, "out_trade_no"),
    "hack-20261001-0002",
  )
  assert_eq(@moon-pay-sdk.string_field(biz, "total_amount"), "88.00")
  // The signature in the URL verifies with the Alipay public key over the
  // canonical content of the decoded parameters.
  let signature = lookup("sign")
  assert_true(client.verify_signature(decoded, signature[:]))
}

///|
async test "a tampered pay url fails signature verification" {
  let (client, _) = mock_client()
  let url = client.page_pay_url(
    out_trade_no="hack-20261001-0002",
    total_fen=8800,
    subject="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/alipay",
    return_url="https://example.com/thanks",
  )
  let params = query_pairs(url)
  let decoded : Array[(String, String)] = []
  for pair in params {
    decoded.push(
      (@alipay.percent_decode(pair.0), @alipay.percent_decode(pair.1)),
    )
  }
  // Swap the amount the customer actually pays.
  let biz = @moon-pay-sdk.parse_json(lookup_value(decoded, "biz_content"))
  assert_eq(@moon-pay-sdk.string_field(biz, "total_amount"), "88.00")
  let tampered : Array[(String, String)] = []
  for pair in decoded {
    if pair.0 == "biz_content" {
      tampered.push(
        (
          pair.0,
          "{\"out_trade_no\":\"hack-20261001-0002\",\"total_amount\":\"0.01\",\"subject\":\"MoonBit Hackathon Ticket\"}",
        ),
      )
    } else {
      tampered.push(pair)
    }
  }
  let signature = lookup_value(tampered, "sign")
  assert_false(client.verify_signature(tampered, signature[:]))
}

///|
fn lookup_value(params : Array[(String, String)], key : String) -> String {
  let mut found = ""
  for pair in params {
    if pair.0 == key {
      found = pair.1
    }
  }
  found
}

///|
async test "page pay rejects bad amounts and order numbers locally" {
  let (client, mock) = mock_client()
  let amount : String = try
    client.page_pay_url(
      out_trade_no="hack-20261001-0002",
      total_fen=0,
      subject="x",
      notify_url="https://example.com/cb",
      return_url="https://example.com/thanks",
    )
  catch {
    @moon-pay-sdk.Config(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(amount, "rejected")
  let trade_no : String = try
    client.page_pay_url(
      out_trade_no="bad/order",
      total_fen=100,
      subject="x",
      notify_url="https://example.com/cb",
      return_url="https://example.com/thanks",
    )
  catch {
    @moon-pay-sdk.Config(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(trade_no, "rejected")
  assert_eq(mock.recorded().length(), 0)
}
