///|
async fn main {
  let random = @tls.rand_bytes(16)
  println("rand_bytes(16) ok, first byte: \{random[0].to_int()}")
  @async.sleep(100)
  println("moonbitlang/async native smoke test passed")
}
