///|
/// Load an X.509 certificate from a PEM string (`BEGIN CERTIFICATE`).
pub fn load_certificate_pem(text : String) -> @x509.Cert raise CryptoError {
  let der = pem_der(text)
  @x509.parse(der[:]) catch {
    e => raise Malformed("certificate: \{e}")
  }
}

///|
/// The certificate serial number as lowercase hex — the form WeChat Pay uses
/// in its `Wechatpay-Serial` header.
pub fn certificate_serial_hex(cert : @x509.Cert) -> String {
  cert.serial.to_string(radix=16)
}

///|
/// The RSA public key the certificate carries.
pub fn certificate_public_key(
  cert : @x509.Cert,
) -> @rsa.PublicKey raise CryptoError {
  cert.spki.rsa() catch {
    e => raise Unsupported("certificate public key: \{e}")
  }
}
