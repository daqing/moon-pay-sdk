///|
/// Fetch, decrypt and cache WeChat Pay platform certificates.
///
/// Platform public keys are what every callback signature and every API
/// response signature is verified against. In certificate mode the current
/// set is downloaded from `/v3/certificates`, where each certificate arrives
/// encrypted under the APIv3 key. In public-key mode (public key mode) the
/// WeChat Pay public key from the merchant console is configured up front
/// under its `PUB_KEY_ID_...` serial and no certificate is ever downloaded.
/// The cache maps serial (lowercase, the `Wechatpay-Serial` form) to the
/// public key; a signature bearing an unknown serial triggers one full
/// refresh in certificate mode.

///|
/// The public key for a platform certificate serial, or the configured
/// WeChat Pay public key in public-key mode. Serves from the cache; an
/// unknown serial triggers a refresh before failing.
pub async fn Client::platform_public_key(
  self : Client,
  serial : String,
) -> @rsa.PublicKey raise @moon-pay-sdk.SdkError {
  let normalized = serial.to_lower()
  match self.certs.get(normalized) {
    Some(public_key) => public_key
    None =>
      if normalized.has_prefix("pub_key_id_") {
        // Public-key mode serials never come from /v3/certificates; a miss
        // means the configured public key id does not match this signature.
        raise Network(
          "wechat pay public-key mode: signature serial \"\{serial}\" does not match the configured platform_public_key_id \"\{self.config.platform_public_key_id}\" — use the public key and serial from the merchant console",
        )
      } else {
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
