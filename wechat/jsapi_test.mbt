///|
// The public half of the test_keys/ merchant pair, for verifying paySign.
let merchant_public_pem : String =
  #|-----BEGIN PUBLIC KEY-----
  #|MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAl8xnVOqaYUGrkSmqv4bu
  #|iDrSwvechdJn5FoxFLaNj8lIYT3au1D4Y5Jt6Pbv1Q5A3xHxQb0cKpqfq9IW7xQm
  #|eBcccW9+wdQRw96lIagV++TM8OCNgNKhXgjH4ewKdGvv6R0QzFymb0O7puC5n6sp
  #|fYKC7D3gxXhJ6ZCC0G2H4x5h+mebjYggsuLtUoXHH/9a11ZzGg7KJV0lye+kyiaV
  #|saPYOdoYVGlvYbxemsd/yUOPPQ2z3534PlUqANh+X00elon4Cyf9clxJ8muhySho
  #|1kMScS2hbWb2ltQgJR74rCgzR2BBgElD4r/7QjNFg91/QhaLkZn3x6eKDjjNniLD
  #|6wIDAQAB
  #|-----END PUBLIC KEY-----

///|
async test "jsapi order sends payer openid and parses prepay_id" {
  let (client, mock) = mock_client([
    {
      status: 200,
      headers: [],
      body: b"{\"prepay_id\":\"wx201410272009395522067a6904e437\"}",
    },
  ])
  let order = client.jsapi_order(
    out_trade_no="hack-20261001-0004",
    total=100,
    description="MoonBit Hackathon Ticket",
    notify_url="https://example.com/callback/wechat",
    openid="oUpF8uMuAJO_M2pxb1Q9zNjWeS6o",
  )
  assert_eq(order.prepay_id(), "wx201410272009395522067a6904e437")
  let request = mock.recorded()[0]
  assert_eq(
    request.url,
    "https://api.mch.weixin.qq.com/v3/pay/transactions/jsapi",
  )
  assert_true(request.meth is Post)
  let body = @moon-pay-sdk.parse_json(@utf8.decode(request.body[:]))
  assert_eq(@moon-pay-sdk.string_field(body, "appid"), "wx8888888888888888")
  assert_eq(@moon-pay-sdk.string_field(body, "mchid"), "1900000000")
  assert_eq(
    @moon-pay-sdk.string_field(body, "out_trade_no"),
    "hack-20261001-0004",
  )
  let payer = @moon-pay-sdk.object_field(body, "payer")
  assert_eq(
    @moon-pay-sdk.string_field(payer, "openid"),
    "oUpF8uMuAJO_M2pxb1Q9zNjWeS6o",
  )
}

///|
async test "jsapi pay params carry a merchant-verifiable paySign" {
  let (client, _) = mock_client([])
  let params = client.jsapi_pay_params(
    prepay_id="wx201410272009395522067a6904e437",
  )
  assert_eq(params.app_id(), "wx8888888888888888")
  // The mock client pins the clock at 1600000000000 ms.
  assert_eq(params.timestamp(), "1600000000")
  assert_eq(params.pay_package(), "prepay_id=wx201410272009395522067a6904e437")
  assert_eq(params.sign_type(), "RSA")
  assert_true(params.nonce_str().length() >= 16)
  let message = "\{params.app_id()}\n\{params.timestamp()}\n\{params.nonce_str()}\n\{params.pay_package()}\n"
  let decoded = @base64.decode(params.pay_sign()) catch {
    _ => abort("paySign must be base64")
  }
  let public_key = @crypto.load_public_key_pem(merchant_public_pem) catch {
    e => abort("fixture public key must load: \{e}")
  }
  assert_true(
    @crypto.verify_rsa_sha256(public_key, @utf8.encode(message)[:], decoded[:]),
  )
}

///|
async test "jsapi rejects an empty openid and an empty prepay_id locally" {
  let (client, mock) = mock_client([])
  let verdict : String = try
    client.jsapi_order(
      out_trade_no="hack-20261001-0004",
      total=100,
      description="x",
      notify_url="https://example.com/callback/wechat",
      openid="",
    )
  catch {
    @moon-pay-sdk.Config(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
  let verdict2 : String = try client.jsapi_pay_params(prepay_id="") catch {
    @moon-pay-sdk.Config(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict2, "rejected")
  assert_eq(mock.recorded().length(), 0)
}
