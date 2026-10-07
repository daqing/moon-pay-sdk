///|
/// The result of a JSAPI order: the `prepay_id` that `wx.requestPayment`
/// (mini-program) or `WeixinJSBridge` (official-account page) consumes via
/// `Client::jsapi_pay_params`.
pub(all) struct JsapiOrder {
  prepay_id : String
}

///|
pub fn JsapiOrder::prepay_id(self : JsapiOrder) -> String {
  self.prepay_id
}

///|
/// The parameter set the WeChat client needs to invoke payment, with the
/// merchant-key `paySign` already computed over
/// `appId\ntimeStamp\nnonceStr\npackage\n`.
pub(all) struct JsapiPayParams {
  app_id : String
  timestamp : String
  nonce_str : String
  pay_package : String
  sign_type : String
  pay_sign : String
}

///|
pub fn JsapiPayParams::app_id(self : JsapiPayParams) -> String {
  self.app_id
}

///|
pub fn JsapiPayParams::timestamp(self : JsapiPayParams) -> String {
  self.timestamp
}

///|
pub fn JsapiPayParams::nonce_str(self : JsapiPayParams) -> String {
  self.nonce_str
}

///|
pub fn JsapiPayParams::pay_package(self : JsapiPayParams) -> String {
  self.pay_package
}

///|
pub fn JsapiPayParams::sign_type(self : JsapiPayParams) -> String {
  self.sign_type
}

///|
pub fn JsapiPayParams::pay_sign(self : JsapiPayParams) -> String {
  self.pay_sign
}

///|
/// Create a JSAPI order via `POST /v3/pay/transactions/jsapi` for payment
/// inside WeChat (mini-program or official-account page). `openid` is the
/// payer's openid under this appid, from the mini-program login flow or the
/// OAuth web-authorization flow.
pub async fn Client::jsapi_order(
  self : Client,
  out_trade_no~ : String,
  total~ : Int,
  description~ : String,
  notify_url~ : String,
  openid~ : String,
) -> JsapiOrder raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.validate_amount_fen(total)
  @moon-pay-sdk.validate_wechat_out_trade_no(out_trade_no)
  if openid.is_empty() {
    raise Config("openid must not be empty")
  }
  let body = @moon-pay-sdk.encode_json({
    "appid": self.config.appid,
    "mchid": self.config.mchid,
    "description": description,
    "out_trade_no": out_trade_no,
    "notify_url": notify_url,
    "amount": { "total": total, "currency": "CNY" },
    "payer": { "openid": openid },
  })
  let json = self.request_json(
    meth=Post,
    path="/v3/pay/transactions/jsapi",
    body~,
  )
  { prepay_id: field(json, "prepay_id"), }
}

///|
/// Build the `wx.requestPayment` parameter set for one `prepay_id`: the
/// timestamp comes from the client's clock, the nonce is fresh, and the
/// paySign is the RSA-SHA256 signature by the merchant private key over the
/// four-line canonical form. The same set feeds `WeixinJSBridge`.
pub async fn Client::jsapi_pay_params(
  self : Client,
  prepay_id~ : String,
) -> JsapiPayParams raise @moon-pay-sdk.SdkError {
  if prepay_id.is_empty() {
    raise Config("prepay_id must not be empty")
  }
  let timestamp = "\{(self.now_ms)() / 1000L}"
  let nonce = @crypto.random_hex(16) catch { e => raise Crypto(e) }
  let pkg = "prepay_id=\{prepay_id}"
  let message = "\{self.config.appid}\n\{timestamp}\n\{nonce}\n\{pkg}\n"
  {
    app_id: self.config.appid,
    timestamp,
    nonce_str: nonce,
    pay_package: pkg,
    sign_type: "RSA",
    pay_sign: sign_request(self.private_key, message),
  }
}
