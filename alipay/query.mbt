///|
/// Alipay trade statuses as returned in `trade_status`.
pub(all) enum TradeStatus {
  /// The transaction is created; the buyer has not paid.
  WaitBuyerPay
  /// Closed without payment, or refunded in full.
  TradeClosed
  /// Paid; funds are usable but a refund is still possible.
  TradeSuccess
  /// Paid and closed — no further refund.
  TradeFinished
  /// A status this SDK does not know yet; the raw text is kept.
  Unknown(String)
}

///|
pub fn TradeStatus::is_unknown(self : TradeStatus) -> Bool {
  match self {
    Unknown(_) => true
    _ => false
  }
}

///|
fn trade_status_of(text : String) -> TradeStatus {
  match text {
    "WAIT_BUYER_PAY" => WaitBuyerPay
    "TRADE_CLOSED" => TradeClosed
    "TRADE_SUCCESS" => TradeSuccess
    "TRADE_FINISHED" => TradeFinished
    other => Unknown(other)
  }
}

///|
/// The full status of one Alipay order, as returned by order query.
pub(all) struct OrderStatus {
  out_trade_no : String
  trade_no : String
  trade_status : TradeStatus
  total_amount : String
  total_fen : Int
  send_pay_date : String?
}

///|
pub fn OrderStatus::out_trade_no(self : OrderStatus) -> String {
  self.out_trade_no
}

///|
pub fn OrderStatus::trade_no(self : OrderStatus) -> String {
  self.trade_no
}

///|
pub fn OrderStatus::trade_status(self : OrderStatus) -> TradeStatus {
  self.trade_status
}

///|
pub fn OrderStatus::total_amount(self : OrderStatus) -> String {
  self.total_amount
}

///|
pub fn OrderStatus::total_fen(self : OrderStatus) -> Int {
  self.total_fen
}

///|
pub fn OrderStatus::send_pay_date(self : OrderStatus) -> String? {
  self.send_pay_date
}

///|
/// The raw JSON text of one top-level member of a JSON object, brace-balanced
/// and string-aware. Alipay signs the response member verbatim, so the
/// signature check must run over these exact bytes, not a re-serialization.
fn raw_json_member(text : StringView, key : String) -> String? {
  let needle = "\"" + key + "\":"
  let start = match text.find(needle) {
    Some(index) => index + needle.length()
    None => return None
  }
  let mut depth = 0
  let mut in_string = false
  let mut previous_escape = false
  for i in start..<text.length() {
    let ch = text.get_char(i)
    let ch = match ch {
      Some(c) => c
      None => return None
    }
    if in_string {
      if previous_escape {
        previous_escape = false
      } else if ch == '\\' {
        previous_escape = true
      } else if ch == '"' {
        in_string = false
      }
    } else {
      match ch {
        '"' => in_string = true
        '{' => depth += 1
        '}' => {
          depth -= 1
          if depth == 0 {
            return Some(text[start:i + 1].to_owned())
          }
        }
        _ => ()
      }
    }
  }
  None
}

///|
fn encode_form(params : Array[(String, String)]) -> String {
  let builder = StringBuilder(size_hint=256)
  for i, pair in params {
    if i > 0 {
      builder.write_string("&")
    }
    builder.write_string(percent_encode(pair.0))
    builder.write_string("=")
    builder.write_string(percent_encode(pair.1))
  }
  builder.to_string()
}

///|
/// Parse an urlencoded form body into raw (key, value) pairs; values stay
/// encoded until each caller decodes the ones it needs.
fn parse_form(text : StringView) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  for chunk in text.split("&") {
    let eq = chunk.find("=")
    let eq = match eq {
      Some(index) => index
      None => chunk.length()
    }
    pairs.push((chunk[0:eq].to_owned(), chunk[eq + 1:].to_owned()))
  }
  pairs
}

///|
/// Query an order via `alipay.trade.query`: a signed form POST to the
/// gateway, whose answer is verified against the Alipay public key before
/// its fields are trusted.
pub async fn Client::query_order(
  self : Client,
  out_trade_no~ : String,
) -> OrderStatus raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.validate_alipay_out_trade_no(out_trade_no)
  let biz : Json = { "out_trade_no": out_trade_no }
  let timestamp = format_beijing((self.now_ms)())
  let params = system_params(
    self.config,
    method="alipay.trade.query",
    timestamp~,
  )
  params.push(("biz_content", @moon-pay-sdk.encode_json(biz)))
  let signature = sign_params(self.private_key, params)
  let with_sign = params.copy()
  with_sign.push(("sign", signature))
  let response = self.transport.send({
    meth: Post,
    url: self.config.gateway_url,
    headers: [("Content-Type", "application/x-www-form-urlencoded")],
    body: @utf8.encode(encode_form(with_sign)),
  }) catch {
    e => raise Network("\{e}")
  }
  let text = @utf8.decode(response.body[:]) catch { _ => "" }
  let root = @moon-pay-sdk.try_parse_json(text)
  let root = match root {
    Some(root) => root
    None => raise Network("query response is not valid JSON")
  }
  let payload = root.value("alipay_trade_query_response")
  let payload = match payload {
    Some(payload) => payload
    None => raise Network("query response has no alipay_trade_query_response")
  }
  let code = @moon-pay-sdk.string_field(payload, "code") catch { _ => "" }
  if code != "10000" {
    let message = message_of(payload, "sub_msg")
    let message = if message == "" {
      message_of(payload, "msg")
    } else {
      message
    }
    let message = if message == "" { "(no message)" } else { message }
    raise Api(
      @moon-pay-sdk.ApiError::new(
        code~,
        message~,
        http_status=Some(response.status),
      ),
    )
  }
  // Verify the response signature over the verbatim member text.
  let payload_raw = raw_json_member(text, "alipay_trade_query_response")
  let payload_raw = match payload_raw {
    Some(raw) => raw
    None => raise Network("query response member could not be recovered")
  }
  let response_sign = @moon-pay-sdk.string_field(root, "sign") catch {
    _ => raise Network("query response carries no signature")
  }
  if !self.verify_signature(
      [
        ("alipay_trade_query_response", payload_raw),
        ("sign", response_sign),
        ("sign_type", "RSA2"),
      ],
      response_sign[:],
    ) {
    raise Network("query response signature verification failed")
  }
  let total_amount = @moon-pay-sdk.string_field(payload, "total_amount") catch {
    e => raise Network("response field total_amount: \{e}")
  }
  {
    out_trade_no: field_text(payload, "out_trade_no"),
    trade_no: field_text(payload, "trade_no"),
    trade_status: trade_status_of(field_text(payload, "trade_status")),
    total_amount,
    total_fen: @moon-pay-sdk.parse_yuan_fen(total_amount),
    send_pay_date: optional_string(payload, "send_pay_date"),
  }
}

///|
fn message_of(json : Json, key : String) -> String {
  @moon-pay-sdk.string_field(json, key) catch {
    _ => ""
  }
}

///|
fn field_text(json : Json, key : String) -> String raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.string_field(json, key) catch {
    e => raise Network("response is missing \"\{key}\": \{e}")
  }
}

///|
fn optional_string(json : Json, key : String) -> String? {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}
