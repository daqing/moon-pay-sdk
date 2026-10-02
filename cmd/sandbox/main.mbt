///|
/// Sandbox smoke check for the Alipay redirect flow. Guarded by
/// environment variables so `moon run cmd/sandbox` without credentials just
/// prints what to set. Never posts real money: it only builds the signed
/// redirect URL for a manual visit.
///
/// Set these to run against the Alipay sandbox:
///   ALIPAY_APP_ID          sandbox app id
///   ALIPAY_PRIVATE_KEY     application private key, PEM
///   ALIPAY_PUBLIC_KEY      Alipay public key, PEM
fn main {
  let app_id = @env.get_env_var("ALIPAY_APP_ID")
  let private_key = @env.get_env_var("ALIPAY_PRIVATE_KEY")
  let public_key = @env.get_env_var("ALIPAY_PUBLIC_KEY")
  let config = match (app_id, private_key, public_key) {
    (Some(app_id), Some(private_key), Some(public_key)) =>
      @alipay.Config::new(
        app_id=app_id,
        private_key_pem=private_key,
        alipay_public_key_pem=public_key,
        gateway_url="https://openapi-sandbox.dl.alipaydev.com/gateway.do",
      )
    _ => {
      println(
        "sandbox check skipped: set ALIPAY_APP_ID, ALIPAY_PRIVATE_KEY and ALIPAY_PUBLIC_KEY to run it",
      )
      return
    }
  }
  let client = @alipay.Client::new(
    config=config,
    transport=@transport.HttpClient::new(),
  ) catch {
    e => {
      println("client construction failed: \{e}")
      return
    }
  }
  let url = client.page_pay_url(
    out_trade_no="sandbox-check-0001",
    total_fen=100,
    subject="moon-pay-sdk sandbox check",
    notify_url="https://example.com/notify",
    return_url="https://example.com/return",
  ) catch {
    e => {
      println("sandbox check failed: \{e}")
      return
    }
  }
  println("sandbox checkout url (visit manually to confirm it opens):")
  println(url)
}
