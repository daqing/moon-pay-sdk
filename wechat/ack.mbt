///|
/// The HTTP status and body to return to WeChat after a notification was
/// processed successfully. Any other answer makes WeChat retry the delivery.
pub fn ack_success() -> (Int, String) {
  (200, "{\"code\":\"SUCCESS\",\"message\":\"成功\"}")
}

///|
/// The HTTP status and body to return when processing failed: a 500 with a
/// `FAIL` envelope, which puts the notification on WeChat's retry schedule.
pub fn ack_failure(message~ : String) -> (Int, String) {
  let body : Json = { "code": "FAIL", "message": message }
  (500, @moon-pay-sdk.encode_json(body))
}
