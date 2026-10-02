// Alipay OpenAPI client: page / wap payment redirects, order query,
// async notification signature verification.

///|
/// The canonical signing content of an Alipay request: every parameter
/// except `sign` and `sign_type`, sorted by key, joined as `k=v&` with no
/// trailing separator. Values are raw (not URL-encoded) here; encoding only
/// happens when the parameters travel.
pub fn build_sign_content(params : Array[(String, String)]) -> String {
  let filtered : Array[(String, String)] = []
  for pair in params {
    if pair.0 != "sign" && pair.0 != "sign_type" {
      filtered.push(pair)
    }
  }
  sort_pairs_by_key(filtered)
  let builder = StringBuilder(size_hint=64)
  for i, pair in filtered {
    if i > 0 {
      builder.write_string("&")
    }
    builder.write_string(pair.0)
    builder.write_string("=")
    builder.write_string(pair.1)
  }
  builder.to_string()
}

///|
/// In-place insertion sort by key. Deliberately not `Array::sort_by_key`:
/// the payment canonical form must be byte-order-stable, and a hand-rolled
/// insertion sort makes the ordering locally verifiable.
fn sort_pairs_by_key(params : Array[(String, String)]) -> Unit {
  for i in 1..<params.length() {
    let pair = params[i]
    let mut j = i - 1
    while j >= 0 && key_greater(params[j].0, pair.0) {
      params[j + 1] = params[j]
      j -= 1
    }
    params[j + 1] = pair
  }
}

///|
/// Byte-order (ASCIIbetical) comparison. The generic string comparison of
/// the core orders strings by length first, which is not what Alipay's
/// canonical form means by "sorted by key".
fn key_greater(a : String, b : String) -> Bool {
  let a_view = a
  let b_view = b
  let shared = if a_view.length() < b_view.length() {
    a_view.length()
  } else {
    b_view.length()
  }
  for i in 0..<shared {
    let ca = match a_view.get_char(i) {
      Some(c) => c.to_int()
      None => 0
    }
    let cb = match b_view.get_char(i) {
      Some(c) => c.to_int()
      None => 0
    }
    if ca != cb {
      return ca > cb
    }
  }
  a_view.length() > b_view.length()
}

///|
/// Sign the canonical content with the application private key (RSA2:
/// RSA PKCS#1 v1.5 over SHA-256) and return the base64 signature for the
/// `sign` parameter.
pub fn sign_params(
  private_key : @rsa.PrivateKey,
  params : Array[(String, String)],
) -> String raise @moon-pay-sdk.SdkError {
  let content = build_sign_content(params)
  let signature = @crypto.sign_rsa_sha256(private_key, @utf8.encode(content)[:])
  @base64.encode(signature[:])
}

///|
/// Format a Unix-milliseconds instant as Alipay's `timestamp` parameter:
/// Beijing time (UTC+8), `yyyy-MM-dd HH:mm:ss`.
pub fn format_beijing(ms : Int64) -> String {
  let secs = ms / 1000L + 8L * 3600L
  let days = secs / 86400L
  let rem = secs % 86400L
  let hour = rem / 3600L
  let minute = rem % 3600L / 60L
  let second = rem % 60L
  // Days-since-epoch to civil date (Howard Hinnant's algorithm).
  let z = days + 719468L
  let era = (if z >= 0L { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let day = doy - (153L * mp + 2L) / 5L + 1L
  let month = if mp < 10L { mp + 3L } else { mp - 9L }
  let year = if month <= 2L { y + 1L } else { y }
  "\{year}-\{pad2(month)}-\{pad2(day)} \{pad2(hour)}:\{pad2(minute)}:\{pad2(second)}"
}

///|
fn pad2(value : Int64) -> String {
  if value < 10L {
    "0\{value}"
  } else {
    "\{value}"
  }
}

///|
/// The system parameters every Alipay request carries (without `sign`).
pub fn system_params(
  config : Config,
  method~ : String,
  timestamp~ : String,
  notify_url? : String? = None,
  return_url? : String? = None,
) -> Array[(String, String)] {
  let params : Array[(String, String)] = [
    ("app_id", config.app_id),
    ("method", method),
    ("format", "JSON"),
    ("charset", "utf-8"),
    ("sign_type", "RSA2"),
    ("timestamp", timestamp),
    ("version", "1.0"),
  ]
  match notify_url {
    Some(url) => params.push(("notify_url", url))
    None => ()
  }
  match return_url {
    Some(url) => params.push(("return_url", url))
    None => ()
  }
  params
}
