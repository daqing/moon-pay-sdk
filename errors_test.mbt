///|
test "sdk errors render their layer and detail" {
  let api : SdkError = Api(
    ApiError::new(code="ORDER_NOT_EXIST", message="order does not exist"),
  )
  assert_eq("\{api}", "api error ORDER_NOT_EXIST: order does not exist")
  let api_with_status : SdkError = Api(
    ApiError::new(
      code="INVALID_REQUEST",
      message="param error",
      http_status=Some(400),
    ),
  )
  assert_eq(
    "\{api_with_status}",
    "api error INVALID_REQUEST (http 400): param error",
  )
  let network : SdkError = Network("connection reset")
  assert_eq("\{network}", "network error: connection reset")
  let config : SdkError = Config("appid must not be empty")
  assert_eq("\{config}", "config error: appid must not be empty")
}

///|
test "crypto errors are wrapped, not flattened" {
  let err : SdkError = Crypto(@crypto.Malformed("PEM: not a PEM envelope"))
  assert_eq("\{err}", "crypto error: malformed: PEM: not a PEM envelope")
  let detailed = match err {
    Crypto(@crypto.Malformed(detail)) => detail
    _ => "unreachable"
  }
  assert_eq(detailed, "PEM: not a PEM envelope")
}
