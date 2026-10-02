///|
/// The four `Wechatpay-*` headers a callback must carry.
pub(all) struct CallbackHeaders {
  serial : String
  timestamp : String
  nonce : String
  signature : String
}

///|
fn header_value(headers : Array[(String, String)], name : String) -> String? {
  let wanted = name.to_lower()
  let mut found : String? = None
  for pair in headers {
    if pair.0.to_lower() == wanted {
      found = Some(pair.1)
    }
  }
  found
}

///|
/// Extract `Wechatpay-Serial/-Timestamp/-Nonce/-Signature` from raw headers,
/// case-insensitively. `None` when any of the four is missing.
pub fn callback_headers_of(
  headers : Array[(String, String)],
) -> CallbackHeaders? {
  let serial = header_value(headers, "wechatpay-serial")
  let timestamp = header_value(headers, "wechatpay-timestamp")
  let nonce = header_value(headers, "wechatpay-nonce")
  let signature = header_value(headers, "wechatpay-signature")
  match (serial, timestamp, nonce, signature) {
    (Some(serial), Some(timestamp), Some(nonce), Some(signature)) =>
      Some({ serial, timestamp, nonce, signature, })
    _ => None
  }
}

///|
/// Verify one callback's signature: the timestamp must sit inside the
/// acceptance window (default ±5 minutes, blocking replays), and the
/// `timestamp\nnonce\nbody\n` message must verify under the platform public
/// key named by the serial header.
pub async fn Client::verify_callback_signature(
  self : Client,
  headers~ : CallbackHeaders,
  body~ : StringView,
  window_seconds? : Int = 300,
) -> Unit raise @moon-pay-sdk.SdkError {
  let ts = match parse_int64(headers.timestamp) {
    Some(ts) => ts
    None =>
      raise Network(
        "callback timestamp \"\{headers.timestamp}\" is not a number",
      )
  }
  let now = (self.now_ms)() / 1000
  let drift = if now > ts { now - ts } else { ts - now }
  if drift > window_seconds.to_int64() {
    raise Network(
      "callback timestamp is \{drift}s old, outside the ±\{window_seconds}s window (possible replay)",
    )
  }
  let message = "\{headers.timestamp}\n\{headers.nonce}\n\{body}\n"
  let public_key = self.platform_public_key(headers.serial)
  let signature = @base64.decode(headers.signature) catch {
    _ => raise Network("callback signature is not valid base64")
  }
  let ok = @crypto.verify_rsa_sha256(
    public_key,
    @utf8.encode(message)[:],
    signature[:],
  )
  if !ok {
    raise Network("callback signature verification failed")
  }
}

///|
fn parse_int64(text : StringView) -> Int64? {
  let text = text.to_owned()
  if text.is_empty() {
    return None
  }
  let mut negative = false
  let mut rest = text
  if rest.has_prefix("-") {
    negative = true
    rest = rest[1:].to_owned()
  }
  let mut value : Int64 = 0L
  for ch in rest {
    let code = ch.to_int()
    if code < 0x30 || code > 0x39 {
      return None
    }
    value = value * 10L + (code - 0x30).to_int64()
  }
  Some(if negative { -value } else { value })
}
