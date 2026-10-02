///|
/// Percent-encode a parameter value for the redirect URL: unreserved
/// characters stay literal, everything else becomes %XX over its UTF-8
/// bytes.
pub fn percent_encode(text : StringView) -> String {
  let builder = StringBuilder(size_hint=text.length() * 3)
  for ch in text {
    let code = ch.to_int()
    if (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A) ||
      (code >= 0x30 && code <= 0x39) ||
      code == 0x2D ||
      code == 0x5F ||
      code == 0x2E ||
      code == 0x7E {
      builder.write_char(ch)
    } else {
      let encoded = @utf8.encode(ch.to_string())
      for byte in encoded {
        builder.write_string("%")
        let high = byte.to_int() >> 4
        let low = byte.to_int() & 0x0F
        builder.write_string(hex_digit(high))
        builder.write_string(hex_digit(low))
      }
    }
  }
  builder.to_string()
}

///|
fn hex_digit(value : Int) -> String {
  let digits = "0123456789ABCDEF"
  let ch = match digits.get_char(value) {
    Some(c) => c
    None => '?'
  }
  String::make(1, ch)
}

///|
/// Build the redirect URL for a signed parameter set: the gateway URL, then
/// every parameter URL-encoded, with the signature appended last.
pub fn build_pay_url(
  config : Config,
  params : Array[(String, String)],
  signature : String,
) -> String {
  let builder = StringBuilder(size_hint=512)
  builder.write_string(config.gateway_url)
  for i, pair in params {
    builder.write_string(if i == 0 { "?" } else { "&" })
    builder.write_string(percent_encode(pair.0))
    builder.write_string("=")
    builder.write_string(percent_encode(pair.1))
  }
  builder.write_string("&sign=")
  builder.write_string(percent_encode(signature))
  builder.to_string()
}

///|
/// Decode a percent-encoded parameter value: %XX sequences become their
/// bytes, `+` becomes a space, and the bytes are read back as UTF-8.
pub fn percent_decode(text : StringView) -> String raise @moon-pay-sdk.SdkError {
  let bytes : Array[Byte] = []
  let view = text
  let mut i = 0
  while i < view.length() {
    let ch = view.get_char(i)
    let ch = match ch {
      Some(c) => c
      None => abort("index within length")
    }
    if ch == '%' {
      let high = hex_value_of(view, i + 1)
      let low = hex_value_of(view, i + 2)
      bytes.push(((high << 4) | low).to_byte())
      i += 3
    } else if ch == '+' {
      bytes.push(b' ')
      i += 1
    } else {
      let encoded = @utf8.encode(ch.to_string())
      for byte in encoded {
        bytes.push(byte)
      }
      i += 1
    }
  }
  let collected = Bytes::from_array(bytes)
  @utf8.decode(collected[:]) catch {
    _ => raise @moon-pay-sdk.Config("decoded bytes are not valid UTF-8")
  }
}

///|
fn hex_value_of(
  view : StringView,
  index : Int,
) -> Int raise @moon-pay-sdk.SdkError {
  let ch = view.get_char(index)
  let ch = match ch {
    Some(c) => c
    None => raise @moon-pay-sdk.Config("percent encoding ends early")
  }
  let code = ch.to_int()
  if code >= 0x30 && code <= 0x39 {
    code - 0x30
  } else if code >= 0x41 && code <= 0x46 {
    code - 0x41 + 10
  } else if code >= 0x61 && code <= 0x66 {
    code - 0x61 + 10
  } else {
    raise @moon-pay-sdk.Config("invalid percent encoding")
  }
}
