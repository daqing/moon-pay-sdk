///|
/// The result of a `wx.login` code exchange: the payer identity under this
/// mini-program. `session_key` is for the mini-program client's own use
/// (decrypting phone-number/profile payloads); payment only needs `openid`.
pub(all) struct Session {
  openid : String
  session_key : String
  unionid : String?
}

///|
pub fn Session::openid(self : Session) -> String {
  self.openid
}

///|
pub fn Session::session_key(self : Session) -> String {
  self.session_key
}

///|
pub fn Session::unionid(self : Session) -> String? {
  self.unionid
}

///|
/// Exchange one `wx.login` code for the payer's openid via
/// `GET /sns/jscode2session`. Codes are single-use and expire in five
/// minutes, so call this at order time, not at login time.
pub async fn Client::code2session(
  self : Client,
  js_code~ : String,
) -> Session raise @moon-pay-sdk.SdkError {
  if js_code.is_empty() {
    raise Config("js_code must not be empty")
  }
  // The URL carries the app secret, so transport failures are reported
  // without the underlying error text — it may embed the request URL.
  let url = "\{self.config.session_base_url}/sns/jscode2session?appid=\{encode_query_value(self.config.app_id)}&secret=\{encode_query_value(self.config.app_secret)}&js_code=\{encode_query_value(js_code)}&grant_type=authorization_code"
  let response = self.transport.send({ meth: Get, url, headers: [], body: b"", }) catch {
    _ => raise Network("code2session request failed")
  }
  let text = @utf8.decode_lossy(response.body[:])
  let root = @moon-pay-sdk.try_parse_json(text)
  let root = match root {
    Some(root) => root
    None => raise Network("code2session response is not valid JSON")
  }
  // The login API answers HTTP 200 even on business errors, with errcode.
  let errcode = match root {
    Object(fields) =>
      match fields.get("errcode") {
        Some(Number(code, ..)) => code
        _ => 0.0
      }
    _ => 0.0
  }
  if errcode != 0.0 {
    let message = @moon-pay-sdk.string_field(root, "errmsg") catch { _ => "" }
    let message = if message == "" { "(no message)" } else { message }
    raise Api(
      @moon-pay-sdk.ApiError::new(
        code="\{errcode}",
        message~,
        http_status=Some(response.status),
      ),
    )
  }
  let openid = @moon-pay-sdk.string_field(root, "openid") catch {
    e => raise Network("code2session response field openid: \{e}")
  }
  let session_key = @moon-pay-sdk.string_field(root, "session_key") catch {
    e => raise Network("code2session response field session_key: \{e}")
  }
  let unionid = match root {
    Object(fields) =>
      match fields.get("unionid") {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
  { openid, session_key, unionid, }
}
