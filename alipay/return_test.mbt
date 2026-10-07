///|
test "return_url query parameters verify and decode" {
  let (client, _) = mock_client()
  let params : Array[(String, String)] = [
    ("app_id", "2021000000000000"),
    ("out_trade_no", "hack-20261001-0002"),
    ("trade_no", "2026100222001"),
    ("total_amount", "88.00"),
    ("sign_type", "RSA2"),
  ]
  let signature = @alipay.sign_content(
    app_private_key(),
    @alipay.build_sign_content(params),
  )
  params.push(("sign", signature))
  let builder = StringBuilder(size_hint=256)
  for i, pair in params {
    if i > 0 {
      builder.write_string("&")
    }
    builder.write_string(@alipay.percent_encode(pair.0))
    builder.write_string("=")
    builder.write_string(@alipay.percent_encode(pair.1))
  }
  let decoded = client.verify_return_params(builder.to_string())
  assert_eq(
    @alipay.percent_decode(lookup_value(decoded, "out_trade_no")),
    "hack-20261001-0002",
  )
  let sign = lookup_value(decoded, "sign")
  assert_true(client.verify_signature(decoded, sign[:]))
}

///|
test "a tampered return redirect fails verification" {
  let (client, _) = mock_client()
  let params : Array[(String, String)] = [
    ("app_id", "2021000000000000"),
    ("out_trade_no", "hack-20261001-0002"),
    ("total_amount", "88.00"),
    ("sign_type", "RSA2"),
  ]
  let signature = @alipay.sign_content(
    app_private_key(),
    @alipay.build_sign_content(params),
  )
  params.push(("sign", signature))
  let tampered : Array[(String, String)] = []
  for pair in params {
    if pair.0 == "total_amount" {
      tampered.push((pair.0, "0.01"))
    } else {
      tampered.push(pair)
    }
  }
  let builder = StringBuilder(size_hint=256)
  for i, pair in tampered {
    if i > 0 {
      builder.write_string("&")
    }
    builder.write_string(@alipay.percent_encode(pair.0))
    builder.write_string("=")
    builder.write_string(@alipay.percent_encode(pair.1))
  }
  let verdict : String = try
    client.verify_return_params(builder.to_string())
  catch {
    @moon-pay-sdk.Network(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
}
