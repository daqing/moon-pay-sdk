// WeChat Pay API v3 client: Native / H5 orders, order query,
// callback signature verification and AES-256-GCM decryption.

///|
/// The canonical signing message of WeChat Pay API v3 (v3 request signature):
/// `METHOD\nPATH\nTIMESTAMP\nNONCE\nBODY\n`, with the trailing newline.
pub fn build_sign_message(
  meth~ : String,
  path~ : String,
  timestamp~ : Int64,
  nonce~ : String,
  body~ : String,
) -> String {
  "\{meth}\n\{path}\n\{timestamp}\n\{nonce}\n\{body}\n"
}

///|
/// Sign a request message with the merchant private key and return the
/// base64 signature the Authorization header carries.
pub fn sign_request(
  private_key : @rsa.PrivateKey,
  message : StringView,
) -> String {
  let signature = @crypto.sign_rsa_sha256(private_key, @utf8.encode(message)[:])
  @base64.encode(signature[:])
}

///|
/// The `Authorization` header value for one API v3 request:
/// `WECHATPAY2-SHA256-RSA2048 mchid="…",nonce_str="…",signature="…",
/// timestamp="…",serial_no="…"`.
pub fn authorization_header(
  config : Config,
  private_key : @rsa.PrivateKey,
  meth~ : String,
  path~ : String,
  timestamp~ : Int64,
  nonce~ : String,
  body~ : String,
) -> String {
  let message = build_sign_message(meth~, path~, timestamp~, nonce~, body~)
  let signature = sign_request(private_key, message)
  "WECHATPAY2-SHA256-RSA2048 mchid=\"\{config.mchid}\",nonce_str=\"\{nonce}\",signature=\"\{signature}\",timestamp=\"\{timestamp}\",serial_no=\"\{config.serial_no}\""
}
