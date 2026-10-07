///|
/// Assemble the signed redirect URL for one pay method: system parameters
/// plus `biz_content`, all signed RSA2 and percent-encoded into the
/// gateway URL.
fn Client::pay_url(
  self : Client,
  api_method~ : String,
  biz~ : Json,
  notify_url~ : String,
  return_url? : String? = None,
) -> String {
  let timestamp = format_beijing((self.now_ms)())
  let params = system_params(
    self.config,
    api_method~,
    timestamp~,
    notify_url=Some(notify_url),
    return_url~,
  )
  params.push(("biz_content", @moon-pay-sdk.encode_json(biz)))
  let signature = sign_params(self.private_key, params)
  build_pay_url(self.config, params, signature)
}

///|
/// Create a desktop-website checkout via `alipay.trade.page.pay`: redirect
/// the customer to the returned URL.
pub fn Client::page_pay_url(
  self : Client,
  out_trade_no~ : String,
  total_fen~ : Int,
  subject~ : String,
  notify_url~ : String,
  return_url~ : String,
) -> String raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.validate_amount_fen(total_fen)
  @moon-pay-sdk.validate_alipay_out_trade_no(out_trade_no)
  // product_code is what the gateway resolves the signed product contract
  // by; the official demos always send it explicitly for page pay.
  let biz : Json = {
    "out_trade_no": out_trade_no,
    "total_amount": @moon-pay-sdk.format_yuan(total_fen),
    "subject": subject,
    "product_code": "FAST_INSTANT_TRADE_PAY",
  }
  self.pay_url(
    api_method="alipay.trade.page.pay",
    biz~,
    notify_url~,
    return_url=Some(return_url),
  )
}

///|
/// Create a mobile-website checkout via `alipay.trade.wap.pay`: redirect
/// the customer's mobile browser to the returned URL.
pub fn Client::wap_pay_url(
  self : Client,
  out_trade_no~ : String,
  total_fen~ : Int,
  subject~ : String,
  notify_url~ : String,
) -> String raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.validate_amount_fen(total_fen)
  @moon-pay-sdk.validate_alipay_out_trade_no(out_trade_no)
  let biz : Json = {
    "out_trade_no": out_trade_no,
    "total_amount": @moon-pay-sdk.format_yuan(total_fen),
    "subject": subject,
    "product_code": "QUICK_WAP_WAY",
  }
  self.pay_url(api_method="alipay.trade.wap.pay", biz~, notify_url~)
}
