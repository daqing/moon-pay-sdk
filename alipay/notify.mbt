///|
/// A verified async notification: the RSA2 signature over its form
/// parameters checks out and the `app_id` belongs to this client.
pub(all) struct NotifyResult {
  trade_status : TradeStatus
  out_trade_no : String
  trade_no : String
  total_amount : String
  total_fen : Int
  app_id : String
  seller_id : String?
  raw : Array[(String, String)]
}

///|
pub fn NotifyResult::trade_status(self : NotifyResult) -> TradeStatus {
  self.trade_status
}

///|
pub fn NotifyResult::out_trade_no(self : NotifyResult) -> String {
  self.out_trade_no
}

///|
pub fn NotifyResult::trade_no(self : NotifyResult) -> String {
  self.trade_no
}

///|
pub fn NotifyResult::total_amount(self : NotifyResult) -> String {
  self.total_amount
}

///|
pub fn NotifyResult::total_fen(self : NotifyResult) -> Int {
  self.total_fen
}

///|
pub fn NotifyResult::app_id(self : NotifyResult) -> String {
  self.app_id
}

///|
pub fn NotifyResult::seller_id(self : NotifyResult) -> String? {
  self.seller_id
}

///|
/// Whether the paid amount equals the local order's amount, in fen. Always
/// run this before marking an order paid: the signature proves who sent the
/// notification, not that it is the one you are waiting for.
pub fn NotifyResult::amount_matches(
  self : NotifyResult,
  expected_fen : Int,
) -> Bool {
  self.total_fen == expected_fen
}

///|
fn lookup_param(params : Array[(String, String)], key : String) -> String {
  let mut found = ""
  for pair in params {
    if pair.0 == key {
      found = pair.1
    }
  }
  found
}

///|
/// Verify an async notification posted as a urlencoded form: every value is
/// decoded, the RSA2 signature over the canonical parameter content is
/// checked with the Alipay public key, and the `app_id` must belong to this
/// client. Raises `SdkError::Network` on any failure.
pub fn Client::verify_notify(
  self : Client,
  form : Array[(String, String)],
) -> NotifyResult raise @moon-pay-sdk.SdkError {
  let decoded = decode_form(form)
  self.verify_signed_params(decoded)
  let signature = lookup_param(decoded, "sign")
  let total_amount = lookup_param(decoded, "total_amount")
  {
    trade_status: trade_status_of(lookup_param(decoded, "trade_status")),
    out_trade_no: lookup_param(decoded, "out_trade_no"),
    trade_no: lookup_param(decoded, "trade_no"),
    total_amount,
    total_fen: @moon-pay-sdk.parse_yuan_fen(total_amount),
    app_id: lookup_param(decoded, "app_id"),
    seller_id: match lookup_param(decoded, "seller_id") {
      "" => None
      value => Some(value)
    },
    raw: decoded,
  }
}

///|
fn decode_form(
  form : Array[(String, String)],
) -> Array[(String, String)] raise @moon-pay-sdk.SdkError {
  let decoded : Array[(String, String)] = []
  for pair in form {
    decoded.push((percent_decode(pair.0), percent_decode(pair.1)))
  }
  decoded
}

///|
/// The shared ownership check behind notifications and return redirects:
/// signature first, then the app_id this client answers for.
fn Client::verify_signed_params(
  self : Client,
  decoded : Array[(String, String)],
) -> Unit raise @moon-pay-sdk.SdkError {
  let signature = lookup_param(decoded, "sign")
  if signature == "" {
    raise Network("signed parameters carry no signature")
  }
  if !self.verify_signature(decoded, signature[:]) {
    raise Network("signature verification failed")
  }
  let app_id = lookup_param(decoded, "app_id")
  if app_id != self.config.app_id {
    raise Network(
      "parameters carry app_id \"\{app_id}\" which does not match this client",
    )
  }
}

///|
/// Verify the signed parameters Alipay appends to the `return_url` redirect
/// (a GET query string, same canonical rules as notifications). Returns the
/// decoded parameters so the caller can read e.g. `out_trade_no`.
pub fn Client::verify_return_params(
  self : Client,
  query : StringView,
) -> Array[(String, String)] raise @moon-pay-sdk.SdkError {
  let decoded = decode_form(parse_form_params(query))
  self.verify_signed_params(decoded)
  decoded
}

///|
/// Parse a urlencoded form body (the notification POST body, or the
/// `return_url` query string) into raw encoded pairs for `verify_notify`.
pub fn parse_form_params(text : StringView) -> Array[(String, String)] {
  parse_form(text)
}
