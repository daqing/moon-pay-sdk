///|
/// Validate a WeChat order amount. Amounts travel as integer fen and must be
/// positive — zero and negatives are rejected before they reach the gateway.
pub fn validate_amount_fen(fen : Int) -> Unit raise SdkError {
  if fen <= 0 {
    raise Config("amount must be a positive number of fen, got \{fen}")
  }
}

///|
/// Format an amount in fen as the two-decimal yuan string Alipay expects in
/// `total_amount`: 8800 -> "88.00", 5 -> "0.05". The amount must be positive.
pub fn format_yuan(fen : Int) -> String raise SdkError {
  validate_amount_fen(fen)
  let yuan = fen / 100
  let cents = fen % 100
  "\{yuan}.\{if cents < 10 { "0\{cents}" } else { "\{cents}" }}"
}

///|
/// Parse the two-decimal yuan string Alipay returns in notifications and
/// answers into integer fen: "88.00" -> 8800. Anything but exactly two
/// decimals — one decimal, thousands separators, signs, blanks — is rejected,
/// so a mismatch always means a malformed amount, never a silent rounding.
pub fn parse_yuan_fen(text : StringView) -> Int raise SdkError {
  let text = text.to_owned()
  let parts = text.split(".").collect()
  if parts.length() != 2 {
    raise Config(
      "amount \"\{text}\" must have exactly two decimals, like 88.00",
    )
  }
  let yuan_part = parts[0]
  let cents_part = parts[1]
  if yuan_part.is_empty() || cents_part.length() != 2 {
    raise Config(
      "amount \"\{text}\" must have exactly two decimals, like 88.00",
    )
  }
  let yuan = digits_of(yuan_part, text)
  let cents = digits_of(cents_part, text)
  yuan * 100 + cents
}

///|
fn digits_of(text : StringView, original : String) -> Int raise SdkError {
  let mut value = 0
  for ch in text {
    let code = ch.to_int()
    if code < 0x30 || code > 0x39 {
      raise Config(
        "amount \"\{original}\" must contain digits only between separators",
      )
    }
    value = value * 10 + (code - 0x30)
  }
  value
}

///|

///|
fn contains_char(text : StringView, ch : Char) -> Bool {
  for c in text {
    if c == ch {
      return true
    }
  }
  false
}

///|
fn check_out_trade_no(
  out_trade_no : StringView,
  original : String,
  min_len~ : Int,
  max_len~ : Int,
  extra_chars~ : String,
) -> Unit raise SdkError {
  let len = out_trade_no.length()
  if len < min_len || len > max_len {
    raise Config(
      "out_trade_no must be \{min_len}-\{max_len} characters, got \{len}",
    )
  }
  for ch in out_trade_no {
    let ok = (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      contains_char(extra_chars, ch)
    if !ok {
      raise Config(
        "out_trade_no \"\{original}\" must use only letters, digits and \{extra_chars}",
      )
    }
  }
}

///|
/// Validate an out-trade number for WeChat Pay: 6-32 characters, letters,
/// digits and `-_|*`.
pub fn validate_wechat_out_trade_no(
  out_trade_no : StringView,
) -> Unit raise SdkError {
  check_out_trade_no(
    out_trade_no,
    out_trade_no.to_owned(),
    min_len=6,
    max_len=32,
    extra_chars="-_|*",
  )
}

///|
/// Validate an out-trade number for Alipay: at most 64 characters, letters,
/// digits, underscore and hyphen.
pub fn validate_alipay_out_trade_no(
  out_trade_no : StringView,
) -> Unit raise SdkError {
  check_out_trade_no(
    out_trade_no,
    out_trade_no.to_owned(),
    min_len=1,
    max_len=64,
    extra_chars="-_",
  )
}
