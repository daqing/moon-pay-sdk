///|
/// A verified and decrypted payment notification. `resource` keeps the whole
/// decrypted JSON so callers can read fields this SDK does not model yet.
pub(all) struct Notification {
  event_type : String
  summary : String?
  out_trade_no : String
  transaction_id : String
  trade_state : TradeState
  total_fen : Int
  payer_fen : Int?
  resource : Json
}

///|
pub fn Notification::event_type(self : Notification) -> String {
  self.event_type
}

///|
pub fn Notification::summary(self : Notification) -> String? {
  self.summary
}

///|
pub fn Notification::out_trade_no(self : Notification) -> String {
  self.out_trade_no
}

///|
pub fn Notification::transaction_id(self : Notification) -> String {
  self.transaction_id
}

///|
pub fn Notification::trade_state(self : Notification) -> TradeState {
  self.trade_state
}

///|
pub fn Notification::total_fen(self : Notification) -> Int {
  self.total_fen
}

///|
pub fn Notification::payer_fen(self : Notification) -> Int? {
  self.payer_fen
}

///|
pub fn Notification::resource(self : Notification) -> Json {
  self.resource
}

///|
/// Decrypt the notification's `resource` blob (AES-256-GCM under the APIv3
/// key) and return the plaintext JSON.
fn Client::decrypt_notification_resource(
  self : Client,
  envelope : Json,
) -> Json raise @moon-pay-sdk.SdkError {
  let resource = obj_field(envelope, "resource")
  let nonce = field(resource, "nonce")
  let ciphertext_b64 = field(resource, "ciphertext")
  let aad = @moon-pay-sdk.string_field(resource, "associated_data") catch {
    _ => ""
  }
  let ciphertext = @base64.decode(ciphertext_b64) catch {
    _ => raise Network("notification ciphertext is not valid base64")
  }
  let plain = @crypto.aes256_gcm_decrypt(
    @utf8.encode(self.config.api_v3_key)[:],
    @utf8.encode(nonce)[:],
    ciphertext[:],
    aad=@utf8.encode(aad)[:],
  ) catch {
    e => raise Crypto(e)
  }
  let text = @utf8.decode(plain[:]) catch {
    _ => raise Network("notification plaintext is not valid UTF-8")
  }
  @moon-pay-sdk.parse_json(text) catch {
    e => raise Network("notification resource is not valid JSON: \{e}")
  }
}

///|
/// Verify, decrypt and parse one notification: the callback signature is
/// checked first (including the replay window), then the resource blob is
/// decrypted and its payment fields extracted.
pub async fn Client::parse_notification(
  self : Client,
  headers : Array[(String, String)],
  body : Bytes,
) -> Notification raise @moon-pay-sdk.SdkError {
  let callback_headers = callback_headers_of(headers)
  let callback_headers = match callback_headers {
    Some(headers) => headers
    None =>
      raise Network("callback is missing the Wechatpay-* signature headers")
  }
  let text = @utf8.decode(body[:]) catch {
    _ => raise Network("callback body is not valid UTF-8")
  }
  self.verify_callback_signature(headers=callback_headers, body=text)
  let envelope = @moon-pay-sdk.parse_json(text) catch {
    e => raise Network("callback body is not valid JSON: \{e}")
  }
  let event_type = field(envelope, "event_type")
  let summary = optional_string(envelope, "summary")
  let resource = self.decrypt_notification_resource(envelope)
  {
    event_type,
    summary,
    out_trade_no: field(resource, "out_trade_no"),
    transaction_id: field(resource, "transaction_id"),
    trade_state: trade_state_of(field(resource, "trade_state")),
    total_fen: int_field(obj_field(resource, "amount"), "total"),
    payer_fen: optional_int(obj_field(resource, "amount"), "payer_total"),
    resource,
  }
}
