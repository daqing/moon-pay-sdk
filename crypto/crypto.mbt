///|
/// Key, certificate or ciphertext material that cannot be used as given.
pub(all) suberror CryptoError {
  /// PEM or DER does not parse, or is not the structure expected.
  Malformed(String)
  /// Parses, but is not supported here: an encrypted private key, a
  /// non-RSA public key.
  Unsupported(String)
  /// A primitive refused the value: wrong size, failed authentication.
  Operation(String)
  /// The entropy source could not be read.
  Random(String)
}
