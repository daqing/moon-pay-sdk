///|
/// Assemble the signed redirect URL for one pay method: system parameters
/// plus `biz_content`, all signed RSA2 and percent-encoded into the
/// gateway URL.
async fn Client::pay_url(
  self : Client,
  method~ : String,
  biz~ : Json,
  notify_url~ : String,
  return_url? : String? = None,
) -> String raise @moon-pay-sdk.SdkError {
  let timestamp = format_beijing((self.now_ms)())
  let params = system_params(
    self.config,
    method~,
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
pub async fn Client::page_pay_url(
  self : Client,
  out_trade_no~ : String,
  total_fen~ : Int,
  subject~ : String,
  notify_url~ : String,
  return_url~ : String,
) -> String raise @moon-pay-sdk.SdkError {
  @moon-pay-sdk.validate_amount_fen(total_fen)
  @moon-pay-sdk.validate_alipay_out_trade_no(out_trade_no)
  let biz : Json = {
    "out_trade_no": out_trade_no,
    "total_amount": @moon-pay-sdk.format_yuan(total_fen),
    "subject": subject,
  }
  self.pay_url(
    method="alipay.trade.page.pay",
    biz~,
    notify_url~,
    return_url=Some(return_url),
  )
}
