// WeChat Mini-Program payment: the server-side flow around the JSAPI
// variant — wx.login code exchange (code2session) plus one-call order and
// wx.requestPayment parameters, on top of the wechat pay client.

///|
/// Credentials for the Mini-Program login API (`api.weixin.qq.com`). The
/// `app_id` must be the same mini-program appid the pay client signs with;
/// `app_secret` comes from the mini-program console (开发管理 → 开发设置).
pub(all) struct Config {
  app_id : String
  app_secret : String
  session_base_url : String
}

///|
pub fn Config::new(
  app_id~ : String,
  app_secret~ : String,
  session_base_url? : String = "https://api.weixin.qq.com",
) -> Config {
  { app_id, app_secret, session_base_url, }
}

///|
/// Reject configs that cannot possibly work, before any request is made.
pub fn Config::validate(self : Config) -> Unit raise @moon-pay-sdk.SdkError {
  if self.app_id.is_empty() {
    raise @moon-pay-sdk.Config("app_id must not be empty")
  }
  if self.app_secret.is_empty() {
    raise @moon-pay-sdk.Config("app_secret must not be empty")
  }
  if !self.session_base_url.has_prefix("https://") &&
    !self.session_base_url.has_prefix("http://") {
    raise @moon-pay-sdk.Config(
      "session_base_url must start with https:// (or http:// for a mock server)",
    )
  }
}

///|
/// Percent-encode one query-string value: everything outside the
/// unreserved set travels escaped.
fn encode_query_value(text : StringView) -> String {
  let builder = StringBuilder(size_hint=text.length() * 3)
  for ch in text {
    let code = ch.to_int()
    if (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A) ||
      (code >= 0x30 && code <= 0x39) ||
      code == 0x2D ||
      code == 0x5F ||
      code == 0x2E ||
      code == 0x7E {
      builder.write_char(ch)
    } else {
      let encoded = @utf8.encode(ch.to_string())
      for byte in encoded {
        builder.write_string("%")
        builder.write_string(hex_digit(byte.to_int() >> 4))
        builder.write_string(hex_digit(byte.to_int() & 0x0F))
      }
    }
  }
  builder.to_string()
}

///|
fn hex_digit(value : Int) -> String {
  let digits = "0123456789ABCDEF"
  let ch = match digits.get_char(value) {
    Some(c) => c
    None => '?'
  }
  String::make(1, ch)
}
