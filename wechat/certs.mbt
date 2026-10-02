///|
/// Fetch, decrypt and cache WeChat Pay platform certificates.
///
/// Platform public keys are what every callback signature and every API
/// response signature is verified against. WeChat rotates them: the current
/// set is downloaded from `/v3/certificates`, where each certificate arrives
/// encrypted under the APIv3 key. The cache maps certificate serial (lowercase
/// hex, the `Wechatpay-Serial` form) to the public key; a signature bearing an
/// unknown serial triggers one full refresh.

///|
/// The public key for a platform certificate serial. Serves from the cache;
/// an unknown serial triggers a refresh before failing.
pub async fn Client::platform_public_key(
  self : Client,
  serial : String,
) -> @rsa.PublicKey raise @moon-pay-sdk.SdkError {
  let normalized = serial.to_lower()
  match self.certs.get(normalized) {
    Some(public_key) => public_key
    None => {
      self.refresh_platform_certs()
      match self.certs.get(normalized) {
        Some(public_key) => public_key
        None =>
          raise Network(
            "platform certificate \"\{serial}\" is unknown even after refresh",
          )
      }
    }
  }
}

///|
/// Re-download the platform certificate set and refresh the cache.
pub async fn Client::refresh_platform_certs(
  self : Client,
) -> Unit raise @moon-pay-sdk.SdkError {
  let json = self.request_json(
    meth=Get,
    path="/v3/certificates",
    body="",
    verify=false,
  )
  let items = @moon-pay-sdk.array_field(json, "data") catch {
    e => raise Network("certificate list is malformed: \{e}")
  }
  for item in items {
    let serial = field(item, "serial_no").to_lower()
    let encrypted = obj_field(item, "encrypt_certificate")
    let nonce = field(encrypted, "nonce")
    let aad = @moon-pay-sdk.string_field(encrypted, "associated_data") catch {
      _ => ""
    }
    let ciphertext_b64 = field(encrypted, "ciphertext")
    let ciphertext = @base64.decode(ciphertext_b64) catch {
      _ => raise Network("certificate ciphertext is not valid base64")
    }
    let plain_pem = @crypto.aes256_gcm_decrypt(
      @utf8.encode(self.config.api_v3_key)[:],
      @utf8.encode(nonce)[:],
      ciphertext[:],
      aad=@utf8.encode(aad)[:],
    ) catch {
      e => raise Crypto(e)
    }
    let plain_text = @utf8.decode(plain_pem[:]) catch {
      _ => raise Network("certificate plaintext is not valid UTF-8")
    }
    let cert = @crypto.load_certificate_pem(plain_text) catch {
      e => raise Crypto(e)
    }
    let public_key = @crypto.certificate_public_key(cert) catch {
      e => raise Crypto(e)
    }
    self.certs.set(serial, public_key)
  }
}
