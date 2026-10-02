///|
/// The result of a Native (QR checkout) order: render `code_url` as a QR
/// code for the customer to scan.
pub(all) struct NativeOrder {
  code_url : String
}

///|
pub fn NativeOrder::code_url(self : NativeOrder) -> String {
  self.code_url
}

///|
/// Create a Native (QR) order via `POST /v3/pay/transactions/native`.
/// The amount is integer fen; the out-trade number follows WeChat rules.
pub async fn Client::native_order(
  self : Client,
  out_trade_no~ : String,
  total~ : Int,
  description~ : String,
  notify_url~ : String,
) -> NativeOrder raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.validate_amount_fen(total)
  @moon-pay-sdk.validate_wechat_out_trade_no(out_trade_no)
  let body = @moon-pay-sdk.encode_json({
    "appid": self.config.appid,
    "mchid": self.config.mchid,
    "description": description,
    "out_trade_no": out_trade_no,
    "notify_url": notify_url,
    "amount": { "total": total, "currency": "CNY" },
  })
  let json = self.request_json(
    meth=Post,
    path="/v3/pay/transactions/native",
    body~,
  )
  { code_url: field(json, "code_url"), }
}
