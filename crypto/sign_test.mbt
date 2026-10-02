///|
// Fixture key from test_keys/, regenerated per test_keys/README.md.
let fixture_n : Bytes = @base16.decode_lossy(
  "0097cc6754ea9a6141ab9129aabf86ee883ad2c2f79c85d267e45a3114b68d8fc948613ddabb50f863926de8f6efd50e40df11f141bd1c2a9a9fabd216ef142678171c716f7ec1d411c3dea521a815fbe4ccf0e08d80d2a15e08c7e1ec0a746befe91d10cc5ca66f43bba6e0b99fab297d8282ec3de0c57849e99082d06d87e31e61fa679b8d8820b2e2ed5285c71fff5ad756731a0eca255d25c9efa4ca2695b1a3d839da1854696f61bc5e9ac77fc9438f3d0db3df9df83e552a00d87e5f4d1e9689f80b27fd725c49f26ba1c92868d64312712da16d66f696d420251ef8ac2833476041804943e2bffb42334583dd7f42168b9199f7c7a78a0e38cd9e22c3eb",
)

///|
let fixture_e : Bytes = @base16.decode_lossy("010001")

///|
let fixture_d : Bytes = @base16.decode_lossy(
  "05790cf803f5fe9aaa5a5df90b8061ba39fb5e4f24c40862ceda0244aa68ee8305ca87bb354a0537e5d01e4d9a3656c0b7aa2dc613d0dfa7afd3b7368a211d054864074cf5f226b8b5e9f6e48095bba808a1889f0c1821519819c8c744ab3a3703486a7ccbbc59179a9238d8f31798892f6593ff3920357c33610e990027483a17cfd27fb0e103e560ad3ee5fb60e7b3f3018caff2e60f8a8b241193eabb1fa38b7b199ba0da456965573d1b920c1a50fe836f21fb009c2e7c7c08bdb76a674570f8d13adc43209ac17ca5a6a4c4623c20c5c2da0487a0c3e1d2de2e6ef5617eb4d14f29d1b796eca31ec73d7ce41ad6e1129641fee19a5c447b12ecb98215fd",
)

///|
fn fixture_key() -> @rsa.PrivateKey {
  @rsa.PrivateKey::new(fixture_n[:], fixture_e[:], fixture_d[:]) catch {
    _ => abort("fixture key must load")
  }
}

///|
// Reference signature produced by:
//   printf 'moon-pay-sdk golden vector' > msg.txt
//   openssl dgst -sha256 -sign test_keys/merchant_private_key.pem \
//     -out golden.sig msg.txt
let golden_signature : Bytes = @base16.decode_lossy(
  "7b5ddf2338d7a365195d049664afd6dd9ad482cf8f724ebc657b83bdf082b660f44d65cda72e379029e4400447a31fcf95dfadf6a76ca3034a4d869d652a960606d60c76ce48dcb93674e24bd089abe6d47e824c8cac900f5e576ceb2b9a8c7f1c0ef5e3c0d825b0ad65487dd2806a3ca1d9050ce03bacd041ded028bf565f5bcd7b8eace08e9a18e10e130fb6b9528a31b454a5f25c8082a18d88dfc43ffaff11f90e5c7469e2caa9c497135f1874ae76ccfbecf79d3b50c7005019e47280951950e7e99b3ea1d5fd7776f09e6d792b6c5fda2f9c6201a8d0b6fb13ed8731f5803105f5c38dfaa6be5e7beefe6c394ff1f70ecf9c1b1b426e9cbf8d15066fae",
)

///|
test "sign matches the openssl reference signature" {
  let sig = @crypto.sign_rsa_sha256(
    fixture_key(),
    b"moon-pay-sdk golden vector"[:],
  )
  assert_eq(sig.length(), 256)
  assert_eq(sig, golden_signature)
}

///|
test "signing is deterministic" {
  let a = @crypto.sign_rsa_sha256(
    fixture_key(),
    b"moon-pay-sdk golden vector"[:],
  )
  let b = @crypto.sign_rsa_sha256(
    fixture_key(),
    b"moon-pay-sdk golden vector"[:],
  )
  assert_eq(a, b)
}
