///|
/// Sign with RSA PKCS#1 v1.5 over SHA-256 — the scheme behind both WeChat Pay
/// v3 request authentication and Alipay RSA2. Deterministic: the same key and
/// message always produce the same signature.
pub fn sign_rsa_sha256(key : @rsa.PrivateKey, message : BytesView) -> Bytes {
  key.sign(message)
}
