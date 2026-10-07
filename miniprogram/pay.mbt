///|
/// A Mini-Program payment client: the wechat pay client does the ordering
/// and signing, while this client adds the `wx.login` code exchange so one
/// call covers login-code to wx.requestPayment parameters.
pub struct Client {
  config : Config
  pay : @wechat.Client
  transport : &@transport.Transport
}

///|
/// Build a client from the login-API credentials, the pay client and the
/// transport used for the login API. The `app_id` must match the pay
/// client's appid — the openid a code resolves to is only valid under the
/// mini-program that issued it.
pub fn Client::new(
  config~ : Config,
  pay~ : @wechat.Client,
  transport~ : &@transport.Transport,
) -> Client raise @moon-pay-sdk.SdkError {
  config.validate()
  if config.app_id != pay.config.appid {
    raise Config(
      "app_id \{config.app_id} does not match the pay client's appid \{pay.config.appid}",
    )
  }
  { config, pay, transport, }
}

///|
/// The outcome of one Mini-Program payment order: who is paying, which
/// order, and the signed parameter set for `wx.requestPayment`.
pub(all) struct PayResult {
  openid : String
  out_trade_no : String
  prepay_id : String
  pay_params : @wechat.JsapiPayParams
}

///|
pub fn PayResult::openid(self : PayResult) -> String {
  self.openid
}

///|
pub fn PayResult::out_trade_no(self : PayResult) -> String {
  self.out_trade_no
}

///|
pub fn PayResult::prepay_id(self : PayResult) -> String {
  self.prepay_id
}

///|
pub fn PayResult::pay_params(self : PayResult) -> @wechat.JsapiPayParams {
  self.pay_params
}

///|
/// One call from `wx.login` code to payment: exchange the code for the
/// payer's openid, place a JSAPI order and return the signed
/// `wx.requestPayment` parameter set.
pub async fn Client::pay(
  self : Client,
  out_trade_no~ : String,
  total~ : Int,
  description~ : String,
  notify_url~ : String,
  js_code~ : String,
) -> PayResult raise @moon-pay-sdk.SdkError {
  let session = self.code2session(js_code~)
  self.pay_with_openid(
    out_trade_no~,
    total~,
    description~,
    notify_url~,
    openid=session.openid(),
  )
}

///|
/// Place the order for a payer whose openid is already known (kept from an
/// earlier login): a JSAPI order plus its signed `wx.requestPayment`
/// parameter set.
pub async fn Client::pay_with_openid(
  self : Client,
  out_trade_no~ : String,
  total~ : Int,
  description~ : String,
  notify_url~ : String,
  openid~ : String,
) -> PayResult raise @moon-pay-sdk.SdkError {
  let order = self.pay.jsapi_order(
    out_trade_no~,
    total~,
    description~,
    notify_url~,
    openid~,
  )
  let params = self.pay.jsapi_pay_params(prepay_id=order.prepay_id())
  { openid, out_trade_no, prepay_id: order.prepay_id(), pay_params: params, }
}
