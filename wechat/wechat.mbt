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
  /// Public-key mode (public key mode): the WeChat Pay public key from the
  /// merchant console and its serial (`PUB_KEY_ID_...`). Empty in
  /// certificate mode, where platform certificates are downloaded instead.
  platform_public_key_pem : String
  platform_public_key_id : String
}

///|
pub fn Config::new(
  appid~ : String,
  mchid~ : String,
  serial_no~ : String,
  private_key_pem~ : String,
  api_v3_key~ : String,
  base_url? : String = "https://api.mch.weixin.qq.com",
  platform_public_key_pem? : String = "",
  platform_public_key_id? : String = "",
) -> Config {
  {
    appid,
    mchid,
    serial_no,
    private_key_pem,
    api_v3_key,
    base_url,
    platform_public_key_pem,
    platform_public_key_id,
  }
}

///|
/// Reject configs that cannot possibly work, before any request is made.
pub fn Config::validate(self : Config) -> Unit raise @moon-pay-sdk.SdkError {
  reject_stray_whitespace(name="appid", value=self.appid)
  reject_stray_whitespace(name="mchid", value=self.mchid)
  reject_stray_whitespace(name="serial_no", value=self.serial_no)
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
  if self.platform_public_key_pem.is_empty() !=
    self.platform_public_key_id.is_empty() {
    raise @moon-pay-sdk.Config(
      "platform_public_key_pem and platform_public_key_id must be set together (public-key mode) or both left empty (certificate mode)",
    )
  }
  if !self.platform_public_key_pem.is_empty() {
    let _ = @crypto.load_public_key_pem(self.platform_public_key_pem) catch {
      e => raise @moon-pay-sdk.Config("platform_public_key_pem: \{e}")
    }
  }
}

///|
/// A value copied from a web console often carries a trailing space or a
/// full-width space; inside the Authorization header it silently breaks the
/// request signature, so reject it up front with the field name.
fn reject_stray_whitespace(
  name~ : String,
  value~ : String,
) -> Unit raise @moon-pay-sdk.SdkError {
  if value.trim().to_owned() != value {
    raise @moon-pay-sdk.Config(
      "\{name} contains stray whitespace — copy the value exactly as shown, without spaces",
    )
  }
}
