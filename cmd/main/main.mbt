///|
async fn main {
  let nonce = @crypto.random_hex(16)
  println("nonce: \{nonce}")
  println("native crypto smoke test passed")
}
