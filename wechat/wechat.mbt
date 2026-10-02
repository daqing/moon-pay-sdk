// WeChat Pay API v3 client: Native / H5 orders, order query,
// callback signature verification and AES-256-GCM decryption.

///|
/// Credentials and endpoints for WeChat Pay API v3.
pub(all) struct Config {
  appid : String
  mchid : String
  serial_no : String
  private_key_pem : String
  api_v3_key : String
  base_url : String
}

///|
pub fn Config::new(
  appid~ : String,
  mchid~ : String,
  serial_no~ : String,
  private_key_pem~ : String,
  api_v3_key~ : String,
  base_url? : String = "https://api.mch.weixin.qq.com",
) -> Config {
  { appid, mchid, serial_no, private_key_pem, api_v3_key, base_url, }
}

///|
/// Reject configs that cannot possibly work, before any request is made.
pub fn Config::validate(self : Config) -> Unit raise @moon-pay-sdk.SdkError {
  if self.appid.is_empty() {
    raise @moon-pay-sdk.Config("appid must not be empty")
  }
  if self.mchid.is_empty() {
    raise @moon-pay-sdk.Config("mchid must not be empty")
  }
  if self.serial_no.is_empty() {
    raise @moon-pay-sdk.Config("serial_no must not be empty")
  }
  if self.private_key_pem.is_empty() {
    raise @moon-pay-sdk.Config("private_key_pem must not be empty")
  }
  if self.api_v3_key.length() != 32 {
    raise @moon-pay-sdk.Config(
      "api_v3_key must be 32 characters, got \{self.api_v3_key.length()}",
    )
  }
  if !self.base_url.has_prefix("https://") &&
    !self.base_url.has_prefix("http://") {
    raise @moon-pay-sdk.Config(
      "base_url must start with https:// (or http:// for a mock server)",
    )
  }
}
