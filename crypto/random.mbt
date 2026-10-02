///|
/// Cryptographic random bytes from the operating system entropy pool
/// (/dev/urandom on Linux and macOS).
pub async fn random_bytes(len : Int) -> Bytes raise CryptoError {
  if len < 0 {
    raise Random("negative byte count \{len}")
  }
  let file = @fs.open("/dev/urandom", mode=ReadOnly) catch {
    e => raise Random("cannot open /dev/urandom: \{e}")
  }
  defer file.close()
  file.read_exactly(len) catch {
    e => raise Random("cannot read /dev/urandom: \{e}")
  }
}

///|
/// A lowercase-hex random string, two characters per byte — the shape of
/// WeChat Pay's nonce_str.
pub async fn random_hex(byte_len : Int) -> String raise CryptoError {
  let bytes = random_bytes(byte_len)
  @base16.encode(bytes[:])
}
