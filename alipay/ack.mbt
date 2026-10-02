///|
/// The body Alipay expects after a notification was processed successfully:
/// the plain text `success`, nothing else. Any other answer (or a timeout)
/// puts the notification on Alipay's retry schedule.
pub fn ack_success() -> String {
  "success"
}
