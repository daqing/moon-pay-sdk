///|
/// Decrypt an AES-256-GCM payload in the WeChat Pay v3 callback layout: the
/// ciphertext bytes carry the 16-byte authentication tag appended, the nonce
/// is 12 bytes and the associated data may be empty.
pub fn aes256_gcm_decrypt(
  key : BytesView,
  nonce : BytesView,
  cipher : BytesView,
  aad? : BytesView = b""[:],
) -> Bytes raise CryptoError {
  if key.length() != 32 {
    raise Operation("aes-256-gcm key must be 32 bytes, got \{key.length()}")
  }
  let block = @aes.Cipher::new(key) catch {
    _ => raise Operation("aes-256 key rejected")
  }
  let gcm = @gcm.Gcm::new(block) catch {
    _ => raise Operation("gcm initialisation failed")
  }
  gcm.open(nonce~, cipher~, aad~) catch {
    e =>
      match e {
        @spec.Tag => raise Operation("ciphertext failed authentication")
        _ => raise Operation("gcm decryption failed")
      }
  }
}
