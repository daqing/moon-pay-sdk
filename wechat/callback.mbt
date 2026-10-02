///|
/// The one call most integrations need: verify the callback signature
/// (replay window included), decrypt the resource and return the typed
/// notification. Reply with `ack_success` / `ack_failure` afterwards.
pub async fn Client::verify_callback(
  self : Client,
  headers : Array[(String, String)],
  body : Bytes,
) -> Notification raise @moon-pay-sdk.SdkError {
  self.parse_notification(headers, body)
}
