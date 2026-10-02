///|
// An EC (non-RSA) public key: loading it must be a typed rejection, not a
// crash — callers need to tell "wrong key type" apart from "corrupt data".
let ec_public_key_pem : String =
  #|-----BEGIN PUBLIC KEY-----
  #|MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAETb5BN7F2EPJAJnTo2LX6rcgur7wt
  #|JqRoy2lTUlgmZs7URzNLTo8r2eTQQtvodgDZ7cFkddlLsSXhLJGVmnW82A==
  #|-----END PUBLIC KEY-----

///|
test "a non-RSA public key is reported as unsupported" {
  let verdict : String = try
    @crypto.load_public_key_pem(ec_public_key_pem)
  catch {
    @crypto.Unsupported(_) => "unsupported"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "unsupported")
}

///|
test "a pkcs8 envelope with broken inner der is rejected" {
  // A well-formed PKCS#8 envelope whose OCTET STRING payload is garbage.
  let broken = "-----BEGIN PRIVATE KEY-----\nMBagMBsGCSqGSIb3DQEJAzEoBBQACgAAAAAAAAAAAAAAAAAAAAAAAAA=\n-----END PRIVATE KEY-----"
  let verdict : String = try @crypto.load_private_key_pem(broken) catch {
    @crypto.Malformed(_) => "malformed"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "malformed")
}

///|
test "an rsa key whose inner fields are unusable is an operation error" {
  // PKCS#1 structure with a zero modulus: parses, but the key is refused.
  let zero_modulus = "-----BEGIN RSA PRIVATE KEY-----\nMC0CAQACCQAAAAAAAAAAAAIDAQABAgMA/////wAAAAAAAAAAAAAAAAAAAAAAAAA=\n-----END RSA PRIVATE KEY-----"
  let verdict : String = try @crypto.load_private_key_pem(zero_modulus) catch {
    @crypto.Operation(_) => "operation refused"
    @crypto.Malformed(_) => "malformed"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(verdict == "operation refused" || verdict == "malformed")
}

///|
test "gcm ciphertext shorter than the tag is rejected as an operation" {
  let key : Bytes = @base16.decode_lossy(
    "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
  )
  let nonce : Bytes = @base16.decode_lossy("00112233445566778899aabb")
  let verdict : String = try
    @crypto.aes256_gcm_decrypt(key[:], nonce[:], b"tiny"[:])
  catch {
    @crypto.Operation(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
}

///|
test "every crypto error variant renders its layer" {
  inspect(
    @crypto.CryptoError::Malformed("bad pem").to_string(),
    content=(
      #|malformed: bad pem
    ),
  )
  inspect(
    @crypto.CryptoError::Unsupported("ec keys").to_string(),
    content=(
      #|unsupported: ec keys
    ),
  )
  inspect(
    @crypto.CryptoError::Operation("tag mismatch").to_string(),
    content=(
      #|operation failed: tag mismatch
    ),
  )
  inspect(
    @crypto.CryptoError::Random("device gone").to_string(),
    content=(
      #|random source: device gone
    ),
  )
}

///|
test "an EC certificate's key is reported as unsupported" {
  let ec_cert = "-----BEGIN CERTIFICATE-----\nMIIBeTCCAR+gAwIBAgIUX8qWkuN4PSruNMj9diyaRlzYDGAwCgYIKoZIzj0EAwIw\nEjEQMA4GA1UEAwwHZWMtdGVzdDAeFw0yNjEwMDIwMzAzNTlaFw0yNjExMDEwMzAz\nNTlaMBIxEDAOBgNVBAMMB2VjLXRlc3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNC\nAARNvkE3sXYQ8kAmdOjYtfqtyC6vvC0mpGjLaVNSWCZmztRHM0tOjyvZ5NBC2+h2\nANntwWR12UuxJeEskZWadbzYo1MwUTAdBgNVHQ4EFgQUQa6BnpyDbHCYGO6XvSYB\noUtcticwHwYDVR0jBBgwFoAUQa6BnpyDbHCYGO6XvSYBoUtcticwDwYDVR0TAQH/\nBAUwAwEB/zAKBggqhkjOPQQDAgNIADBFAiEA22nDTMd6H9LO5W3T66QRWp/Omxpr\n5xU3yJvuzrGQmowCIBnsSqQMGx/XlUtkNzYarrQroc4bK3PzF2sVotJbWiXN\n-----END CERTIFICATE-----"
  let cert = @crypto.load_certificate_pem(ec_cert)
  let verdict : String = try @crypto.certificate_public_key(cert) catch {
    @crypto.Unsupported(_) => "unsupported"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "unsupported")
}

///|
test "a pkcs8 key with an empty algorithm identifier is rejected" {
  let broken = "-----BEGIN PRIVATE KEY-----\nMAwCAQAwAAQFaGVsbG8=\n-----END PRIVATE KEY-----"
  let verdict : String = try @crypto.load_private_key_pem(broken) catch {
    @crypto.Malformed(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "empty algorithm identifier")
}

///|
test "a pkcs8 key whose algorithm is not an oid is rejected" {
  let broken = "-----BEGIN PRIVATE KEY-----\nMA8CAQAwAwEB/wQFaGVsbG8=\n-----END PRIVATE KEY-----"
  let verdict : String = try @crypto.load_private_key_pem(broken) catch {
    @crypto.Malformed(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "algorithm OID: Malformed(not an OBJECT IDENTIFIER)")
}
