///|
test "amounts in fen must be positive" {
  @moon-pay-sdk.validate_amount_fen(100)
  let zero : String = try @moon-pay-sdk.validate_amount_fen(0) catch {
    @moon-pay-sdk.Config(message) => message
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(zero, "amount must be a positive number of fen, got 0")
  let negative : String = try @moon-pay-sdk.validate_amount_fen(-1) catch {
    @moon-pay-sdk.Config(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(negative, "rejected")
}

///|
test "yuan formatting pads cents to two decimals" {
  assert_eq(@moon-pay-sdk.format_yuan(8800), "88.00")
  assert_eq(@moon-pay-sdk.format_yuan(100), "1.00")
  assert_eq(@moon-pay-sdk.format_yuan(50), "0.50")
  assert_eq(@moon-pay-sdk.format_yuan(5), "0.05")
  assert_eq(@moon-pay-sdk.format_yuan(123456), "1234.56")
}

///|
test "yuan parsing accepts exactly two decimals" {
  assert_eq(@moon-pay-sdk.parse_yuan_fen("88.00"), 8800)
  assert_eq(@moon-pay-sdk.parse_yuan_fen("0.05"), 5)
  assert_eq(@moon-pay-sdk.parse_yuan_fen("1234.56"), 123456)
  let bad : Array[String] = [
    "88.5", "88", "1,234.00", "-1.00", "1.234", ".50", "",
  ]
  for text in bad {
    let verdict : String = try @moon-pay-sdk.parse_yuan_fen(text) catch {
      @moon-pay-sdk.Config(_) => "rejected"
      _ => "other error"
    } noraise {
      _ => "no error raised"
    }
    assert_eq(verdict, "rejected")
  }
}

///|
test "wechat out_trade_no enforces length and charset" {
  @moon-pay-sdk.validate_wechat_out_trade_no("hack-20261001-0001")
  @moon-pay-sdk.validate_wechat_out_trade_no("a*b|c|d_e")
  let too_short : String = try
    @moon-pay-sdk.validate_wechat_out_trade_no("abc")
  catch {
    @moon-pay-sdk.Config(message) => message
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(too_short, "out_trade_no must be 6-32 characters, got 3")
  let too_long : String = try
    @moon-pay-sdk.validate_wechat_out_trade_no("a".repeat(33))
  catch {
    @moon-pay-sdk.Config(message) => message
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(too_long, "out_trade_no must be 6-32 characters, got 33")
  let bad_charset : String = try
    @moon-pay-sdk.validate_wechat_out_trade_no("订单1001")
  catch {
    @moon-pay-sdk.Config(message) => message
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(bad_charset.has_prefix("out_trade_no"))
  let slash : String = try
    @moon-pay-sdk.validate_wechat_out_trade_no("order/1001")
  catch {
    @moon-pay-sdk.Config(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(slash, "rejected")
}

///|
test "alipay out_trade_no allows up to 64 chars with _ and -" {
  @moon-pay-sdk.validate_alipay_out_trade_no("a")
  @moon-pay-sdk.validate_alipay_out_trade_no("order_2026-1001")
  @moon-pay-sdk.validate_alipay_out_trade_no("a".repeat(64))
  let too_long : String = try
    @moon-pay-sdk.validate_alipay_out_trade_no("a".repeat(65))
  catch {
    @moon-pay-sdk.Config(message) => message
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(too_long, "out_trade_no must be 1-64 characters, got 65")
  let bad_charset : String = try
    @moon-pay-sdk.validate_alipay_out_trade_no("order*1001")
  catch {
    @moon-pay-sdk.Config(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(bad_charset, "rejected")
}
