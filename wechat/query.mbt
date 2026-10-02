///|
/// WeChat Pay order states as returned in `trade_state`.
pub(all) enum TradeState {
  /// Payment succeeded.
  Success
  /// Refunded.
  Refund
  /// Not paid.
  NotPay
  /// Closed (never paid, or closed after timeout).
  Closed
  /// Revoked (card payment).
  Revoked
  /// User is mid-payment.
  UserPaying
  /// Payment failed.
  PayError
  /// A state this SDK does not know yet; the raw text is kept so callers
  /// can log it and newer provider states never break upgrades.
  Unknown(String)
} derive(Eq, @debug.Debug)

///|
pub extend TradeState with Eq::{equal, not_equal}

///|
pub extend TradeState with @debug.Debug::{to_repr}

///|
fn trade_state_of(text : String) -> TradeState {
  match text {
    "SUCCESS" => Success
    "REFUND" => Refund
    "NOTPAY" => NotPay
    "CLOSED" => Closed
    "REVOKED" => Revoked
    "USERPAYING" => UserPaying
    "PAYERROR" => PayError
    other => Unknown(other)
  }
}

///|
/// The full status of one WeChat Pay order, as returned by order query.
pub(all) struct OrderStatus {
  out_trade_no : String
  transaction_id : String
  trade_state : TradeState
  total_fen : Int
  payer_fen : Int?
  success_time : String?
}

///|
pub fn OrderStatus::out_trade_no(self : OrderStatus) -> String {
  self.out_trade_no
}

///|
pub fn OrderStatus::transaction_id(self : OrderStatus) -> String {
  self.transaction_id
}

///|
pub fn OrderStatus::trade_state(self : OrderStatus) -> TradeState {
  self.trade_state
}

///|
pub fn OrderStatus::total_fen(self : OrderStatus) -> Int {
  self.total_fen
}

///|
pub fn OrderStatus::payer_fen(self : OrderStatus) -> Int? {
  self.payer_fen
}

///|
pub fn OrderStatus::success_time(self : OrderStatus) -> String? {
  self.success_time
}

///|
fn obj_field(json : Json, key : String) -> Json raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.object_field(json, key) catch {
    e => raise Network("response is missing \"\{key}\": \{e}")
  }
}

///|
fn int_field(json : Json, key : String) -> Int raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.int_field(json, key) catch {
    e => raise Network("response field \"\{key}\": \{e}")
  }
}

///|
fn optional_int(json : Json, key : String) -> Int? {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(Number(value, ..)) => Some(value.to_int())
        _ => None
      }
    _ => None
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

///|
fn parse_order_status(json : Json) -> OrderStatus raise @moon-pay-sdk.SdkError {
  {
    out_trade_no: field(json, "out_trade_no"),
    transaction_id: field(json, "transaction_id"),
    trade_state: trade_state_of(field(json, "trade_state")),
    total_fen: int_field(obj_field(json, "amount"), "total"),
    payer_fen: optional_int(obj_field(json, "amount"), "payer_total"),
    success_time: optional_string(json, "success_time"),
  }
}

///|
/// Query an order by the merchant's `out_trade_no`.
pub async fn Client::query_order(
  self : Client,
  out_trade_no~ : String,
) -> OrderStatus raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.validate_wechat_out_trade_no(out_trade_no)
  let json = self.request_json(
    meth=Get,
    path="/v3/pay/transactions/out-trade-no/\{out_trade_no}?mchid=\{self.config.mchid}",
    body="",
  )
  parse_order_status(json)
}

///|
/// Query an order by WeChat's `transaction_id`.
pub async fn Client::query_order_by_id(
  self : Client,
  transaction_id~ : String,
) -> OrderStatus raise @moon-pay-sdk.SdkError {
  if transaction_id.is_empty() {
    raise Config("transaction_id must not be empty")
  }
  let json = self.request_json(
    meth=Get,
    path="/v3/pay/transactions/id/\{transaction_id}?mchid=\{self.config.mchid}",
    body="",
  )
  parse_order_status(json)
}
