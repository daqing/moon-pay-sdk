///|
test "percent encoding keeps unreserved characters literal" {
  assert_eq(@alipay.percent_encode("abcXYZ019-_.~"), "abcXYZ019-_.~")
}

///|
test "percent encoding escapes reserved and non-ascii bytes" {
  assert_eq(@alipay.percent_encode("a b&c=d"), "a%20b%26c%3Dd")
  assert_eq(@alipay.percent_encode("{"), "%7B")
  // 中文 in UTF-8 is e4 b8 ad e6 96 87.
  assert_eq(@alipay.percent_encode("中文"), "%E4%B8%AD%E6%96%87")
}

///|
test "pay url appends encoded parameters and the signature" {
  let url = @alipay.build_pay_url(
    @alipay.Config::new(
      app_id="2021000000000000",
      private_key_pem=merchant_private_key_pem,
      alipay_public_key_pem~,
      gateway_url="https://openapi.alipay.com/gateway.do",
    ),
    [
      ("app_id", "2021000000000000"),
      ("biz_content", "{\"out_trade_no\":\"T6\"}"),
    ],
    "SIG==",
  )
  assert_eq(
    url, "https://openapi.alipay.com/gateway.do?app_id=2021000000000000&biz_content=%7B%22out_trade_no%22%3A%22T6%22%7D&sign=SIG%3D%3D",
  )
}
