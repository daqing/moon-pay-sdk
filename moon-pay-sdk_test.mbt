// Blackbox tests run against the package's public API. Use `@moon-pay-sdk` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
test "json round trip through string fields" {
  let json = @moon-pay-sdk.parse_json(
    "{\"code_url\":\"weixin://wxpay/bizpayurl?pr=abc\",\"total\":100,\"sandbox\":true}",
  )
  assert_eq(
    @moon-pay-sdk.encode_json(json),
    "{\"code_url\":\"weixin://wxpay/bizpayurl?pr=abc\",\"total\":100,\"sandbox\":true}",
  )
  assert_eq(
    @moon-pay-sdk.string_field(json, "code_url"),
    "weixin://wxpay/bizpayurl?pr=abc",
  )
  assert_eq(@moon-pay-sdk.int_field(json, "total"), 100)
  assert_eq(@moon-pay-sdk.bool_field(json, "sandbox"), true)
}

///|
test "json helpers report useful errors" {
  let json = @moon-pay-sdk.parse_json("{\"name\":\"n\",\"price\":19.99}")
  let missing : String = try
    @moon-pay-sdk.string_field(json, "code_url")
  catch {
    @moon-pay-sdk.Missing(key) => "missing \{key}"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(missing, "missing code_url")
  let wrong_type : String = try
    @moon-pay-sdk.string_field(json, "price")
  catch {
    @moon-pay-sdk.WrongType(key, expected) => "\{key} is not \{expected}"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(wrong_type, "price is not string")
  let fractional : String = try @moon-pay-sdk.int_field(json, "price") catch {
    @moon-pay-sdk.WrongType(key, expected) => "\{key} is not \{expected}"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(fractional, "price is not integer")
}

///|
test "malformed json text is rejected with position info" {
  let verdict : String = try @moon-pay-sdk.parse_json("{\"total\":") catch {
    @moon-pay-sdk.Invalid(detail) => "invalid: \{detail}"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(verdict.has_prefix("invalid: "))
}

///|
test "nested objects and arrays are reachable" {
  let json = @moon-pay-sdk.parse_json(
    "{\"amount\":{\"total\":100,\"currency\":\"CNY\"},\"scenes\":[\"h5\",\"native\"]}",
  )
  let amount = @moon-pay-sdk.object_field(json, "amount")
  assert_eq(@moon-pay-sdk.int_field(amount, "total"), 100)
  assert_eq(@moon-pay-sdk.string_field(amount, "currency"), "CNY")
  let scenes = @moon-pay-sdk.array_field(json, "scenes")
  assert_eq(scenes.length(), 2)
  let first_scene = match scenes[0] {
    String(name) => name
    _ => ""
  }
  assert_eq(first_scene, "h5")
}
