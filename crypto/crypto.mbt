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

///|
pub impl Show for CryptoError with fn output(
  self : CryptoError,
  logger : &Logger,
) -> Unit {
  match self {
    Malformed(detail) => logger.write_string("malformed: \{detail}")
    Unsupported(detail) => logger.write_string("unsupported: \{detail}")
    Operation(detail) => logger.write_string("operation failed: \{detail}")
    Random(detail) => logger.write_string("random source: \{detail}")
  }
}

///|
pub extend CryptoError with Show::{output, to_string}
