// Alipay OpenAPI client: page / wap payment redirects, order query,
// async notification signature verification.

///|
/// Credentials and endpoints for the Alipay OpenAPI.
pub(all) struct Config {
  app_id : String
  private_key_pem : String
  alipay_public_key_pem : String
  gateway_url : String
}

///|
pub fn Config::new(
  app_id~ : String,
  private_key_pem~ : String,
  alipay_public_key_pem~ : String,
  gateway_url? : String = "https://openapi.alipay.com/gateway.do",
) -> Config {
  { app_id, private_key_pem, alipay_public_key_pem, gateway_url, }
}

///|
/// Reject configs that cannot possibly work, before any request is made.
pub fn Config::validate(self : Config) -> Unit raise @moon-pay-sdk.SdkError {
  if self.app_id.is_empty() {
    raise @moon-pay-sdk.Config("app_id must not be empty")
  }
  if self.private_key_pem.is_empty() {
    raise @moon-pay-sdk.Config("private_key_pem must not be empty")
  }
  if self.alipay_public_key_pem.is_empty() {
    raise @moon-pay-sdk.Config("alipay_public_key_pem must not be empty")
  }
  if !self.gateway_url.has_prefix("https://") &&
    !self.gateway_url.has_prefix("http://") {
    raise @moon-pay-sdk.Config(
      "gateway_url must start with https:// (or http:// for a mock server)",
    )
  }
}
