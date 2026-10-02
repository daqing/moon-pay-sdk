///|
/// The result of an H5 order: redirect the customer's mobile browser to
/// `h5_url` to open WeChat Pay.
pub(all) struct H5Order {
  h5_url : String
}

///|
pub fn H5Order::h5_url(self : H5Order) -> String {
  self.h5_url
}

///|
/// Create an H5 order via `POST /v3/pay/transactions/h5` for mobile-browser
/// checkout. `payer_client_ip` is the customer's IP as WeChat requires it in
/// `scene_info`.
pub async fn Client::h5_order(
  self : Client,
  out_trade_no~ : String,
  total~ : Int,
  description~ : String,
  notify_url~ : String,
  payer_client_ip~ : String,
) -> H5Order raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.validate_amount_fen(total)
  @moon-pay-sdk.validate_wechat_out_trade_no(out_trade_no)
  if payer_client_ip.is_empty() {
    raise Config("payer_client_ip must not be empty")
  }
  let body = @moon-pay-sdk.encode_json({
    "appid": self.config.appid,
    "mchid": self.config.mchid,
    "description": description,
    "out_trade_no": out_trade_no,
    "notify_url": notify_url,
    "amount": { "total": total, "currency": "CNY" },
    "scene_info": { "payer_client_ip": payer_client_ip, "scene_type": "H5" },
  })
  let json = self.request_json(meth=Post, path="/v3/pay/transactions/h5", body~)
  { h5_url: field(json, "h5_url"), }
}
