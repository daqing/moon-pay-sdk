///|
async test "random_bytes returns the requested length" {
  let a = @crypto.random_bytes(16)
  let b = @crypto.random_bytes(16)
  assert_eq(a.length(), 16)
  assert_true(a != b)
}

///|
async test "random_hex is 32 lowercase hex characters for 16 bytes" {
  let hex = @crypto.random_hex(16)
  assert_eq(hex.length(), 32)
  let mut all_lower_hex = true
  for ch in hex {
    let c = ch.to_int()
    let digit = (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x66)
    if !digit {
      all_lower_hex = false
    }
  }
  assert_true(all_lower_hex)
}

///|
async test "random_bytes rejects a negative length" {
  let verdict : String = try @crypto.random_bytes(-1) catch {
    @crypto.Random(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
}
