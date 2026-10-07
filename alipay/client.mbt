///|
/// An Alipay OpenAPI client bound to its credentials and a transport.
/// `alipay_public_key` is the key notifications and responses are verified
/// with; the clock is injectable so tests can pin timestamps.
pub struct Client {
  config : Config
  private_key : @rsa.PrivateKey
  alipay_public_key : @rsa.PublicKey
  transport : &@transport.Transport
  now_ms : () -> Int64
}

///|
pub fn Client::new(
  config~ : Config,
  transport~ : &@transport.Transport,
  now_ms? : () -> Int64 = () => @async.now(),
) -> Client raise @moon-pay-sdk.SdkError {
  config.validate()
  let private_key = @crypto.load_private_key_pem(config.private_key_pem) catch {
    e => raise Crypto(e)
  }
  let alipay_public_key = @crypto.load_public_key_pem(
    config.alipay_public_key_pem,
  ) catch {
    e => raise Crypto(e)
  }
  { config, private_key, alipay_public_key, transport, now_ms, }
}

///|
/// Verify one Alipay signature over the canonical verification content of
/// `params` — the incoming-notification / return-redirect form, which
/// excludes `sign` and `sign_type` — using the Alipay public key.
pub fn Client::verify_signature(
  self : Client,
  params : Array[(String, String)],
  signature : StringView,
) -> Bool {
  self.verify_content(build_sign_content(params), signature)
}

///|
/// Verify one Alipay RSA2 signature over an already-canonicalized content
/// string using the Alipay public key; used for notifications, return
/// redirects and the verbatim sync-response member.
pub fn Client::verify_content(
  self : Client,
  content : String,
  signature : StringView,
) -> Bool {
  let decoded = @base64.decode(signature) catch { _ => return false }
  @crypto.verify_rsa_sha256(
    self.alipay_public_key,
    @utf8.encode(content)[:],
    decoded[:],
  )
}
