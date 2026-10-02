///|
// T7.2 gap coverage: the notification path without a signature parameter.

///|
async test "a notification without a sign parameter is rejected" {
  let (client, _) = mock_client()
  let verdict : String = try
    client.verify_notify([
      ("app_id", "2021000000000000"),
      ("trade_status", "TRADE_SUCCESS"),
    ])
  catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "signed parameters carry no signature")
}
