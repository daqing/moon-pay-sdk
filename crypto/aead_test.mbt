///|
// Reference vectors produced with Node's AES-256-GCM (OpenSSL): key
// 000102..1f, nonce 00112233445566778899aabb, plaintext "moon-pay-sdk".
let gcm_key : Bytes = @base16.decode_lossy(
  "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
)

///|
let gcm_nonce : Bytes = @base16.decode_lossy("00112233445566778899aabb")

///|
test "decrypts a reference vector without aad" {
  let ciphertext = @base16.decode_lossy(
    "b7e99fdd62172a674513a477d8b4c4478cab2f726f5ba82ee32facb1",
  )
  let plain = @crypto.aes256_gcm_decrypt(
    gcm_key[:],
    gcm_nonce[:],
    ciphertext[:],
  )
  assert_eq(@base16.encode(plain[:]), "6d6f6f6e2d7061792d73646b")
}

///|
test "decrypts a reference vector with aad" {
  let ciphertext = @base16.decode_lossy(
    "b7e99fdd62172a674513a47771e1878e14baf60c811f8630e1e9506e",
  )
  let plain = @crypto.aes256_gcm_decrypt(
    gcm_key[:],
    gcm_nonce[:],
    ciphertext[:],
    aad=b"transaction"[:],
  )
  assert_eq(@base16.encode(plain[:]), "6d6f6f6e2d7061792d73646b")
}

///|
test "rejects a tampered tag" {
  let tampered = @base16.decode_lossy(
    "b7e99fdd62172a674513a477d8b4c4478cab2f726f5ba82ee32facb0",
  )
  let verdict : String = try
    @crypto.aes256_gcm_decrypt(gcm_key[:], gcm_nonce[:], tampered[:])
  catch {
    @crypto.Operation(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
}

///|
test "rejects aad mismatch" {
  let ciphertext = @base16.decode_lossy(
    "b7e99fdd62172a674513a47771e1878e14baf60c811f8630e1e9506e",
  )
  let verdict : String = try
    @crypto.aes256_gcm_decrypt(gcm_key[:], gcm_nonce[:], ciphertext[:])
  catch {
    @crypto.Operation(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
}

///|
test "rejects a wrong key" {
  let ciphertext = @base16.decode_lossy(
    "b7e99fdd62172a674513a477d8b4c4478cab2f726f5ba82ee32facb1",
  )
  let wrong = @base16.decode_lossy(
    "1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100",
  )
  let verdict : String = try
    @crypto.aes256_gcm_decrypt(wrong[:], gcm_nonce[:], ciphertext[:])
  catch {
    @crypto.Operation(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
}

///|
test "rejects a key that is not 32 bytes" {
  let verdict : String = try
    @crypto.aes256_gcm_decrypt(gcm_key[:][0:16], gcm_nonce[:], gcm_key[:])
  catch {
    @crypto.Operation(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
}
