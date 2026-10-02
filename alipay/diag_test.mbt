///|
test "diag full pipeline" {
  let params = [
    ("version", "1.0"),
    ("sign_type", "RSA2"),
    ("charset", "utf-8"),
    ("method", "alipay.trade.page.pay"),
    ("sign", "IGNORED"),
    ("app_id", "2021000000000000"),
    ("biz_content", "{\"out_trade_no\":\"T6GOLDEN\"}"),
  ]
  let filtered : Array[(String, String)] = []
  for pair in params {
    if pair.0 != "sign" && pair.0 != "sign_type" {
      filtered.push(pair)
    }
  }
  filtered.sort_by_key(fn(pair) { pair.0 })
  let mut keys = ""
  for pair in filtered {
    keys = keys + pair.0 + ";"
  }
  println("keys: \{keys}")
  let content = @alipay.build_sign_content(params)
  println("content: \{content}")
}
