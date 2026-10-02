///|
/// A WeChat Pay API v3 client bound to its credentials and a transport.
/// The clock is injectable so tests can pin timestamps.
pub struct Client {
  config : Config
  private_key : @rsa.PrivateKey
  transport : &@transport.Transport
  now_ms : () -> Int64
}

///|
pub fn Client::new(
  config~ : Config,
  transport~ : &@transport.Transport,
  now_ms? : () -> Int64 = () => @async.now(),
) -> Client raise @moon-pay-sdk.SdkError {
  config.validate()
  let private_key = @crypto.load_private_key_pem(config.private_key_pem) catch {
    e => raise Crypto(e)
  }
  { config, private_key, transport, now_ms, }
}

///|
fn field(json : Json, key : String) -> String raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.string_field(json, key) catch {
    e => raise Network("response is missing \"\{key}\": \{e}")
  }
}

///|
/// Build the `SdkError::Api` for a non-success response, keeping the
/// provider's structured code and message when the body is the expected
/// JSON error envelope.
fn api_error_from(status : Int, body_text : String) -> @moon-pay-sdk.SdkError {
  let json = @moon-pay-sdk.try_parse_json(body_text)
  let default_message = {
    let trimmed = body_text.trim()
    if trimmed.is_empty() {
      "(no body)"
    } else {
      trimmed.to_owned()
    }
  }
  let code = match json {
    Some(json) =>
      @moon-pay-sdk.string_field(json, "code") catch {
        _ => "HTTP_\{status}"
      }
    None => "HTTP_\{status}"
  }
  let message = match json {
    Some(json) =>
      @moon-pay-sdk.string_field(json, "message") catch {
        _ => default_message
      }
    None => default_message
  }
  Api(@moon-pay-sdk.ApiError::new(code~, message~, http_status=Some(status)))
}

///|
/// Send one signed API v3 request and return the parsed JSON answer.
/// Non-2xx answers become `SdkError::Api` carrying the provider's code.
async fn Client::request_json(
  self : Client,
  meth~ : @transport.Method,
  path~ : String,
  body~ : String,
) -> Json raise @moon-pay-sdk.SdkError {
  let nonce = @crypto.random_hex(16) catch { e => raise Crypto(e) }
  let timestamp = (self.now_ms)() / 1000
  let authorization = authorization_header(
    self.config,
    self.private_key,
    meth=method_name(meth),
    path~,
    timestamp~,
    nonce~,
    body~,
  )
  let response = self.transport.send({
    meth,
    url: self.config.base_url + path,
    headers: [
      ("Authorization", authorization),
      ("Content-Type", "application/json"),
      ("Accept", "application/json"),
      ("User-Agent", "moon-pay-sdk/0.1.0"),
    ],
    body: @utf8.encode(body),
  }) catch {
    e => raise Network("\{e}")
  }
  let text = @utf8.decode(response.body[:]) catch { _ => "" }
  if response.status >= 300 {
    raise api_error_from(response.status, text)
  }
  @moon-pay-sdk.parse_json(text) catch {
    e => raise Network("malformed response body: \{e}")
  }
}

///|
fn method_name(meth : @transport.Method) -> String {
  match meth {
    Get => "GET"
    Post => "POST"
  }
}
