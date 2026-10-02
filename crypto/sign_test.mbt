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

///|
// A second, independent key from test_keys/merchant_private_key_pkcs1.pem.
let other_n : Bytes = @base16.decode_lossy(
  "00c6bcd33defcfb7f5afa769cfde0c6baed421650a6005111d67a733e0c373677efb530c7f2583e4bb10f79abdf7c564b89d02d7a2ce50b3efc8f0abddc6fb1394a035695e43eb5d8fc4ff5c94582e9343c964d9463741d6ba25d74a464f8b8fe2c6e46de9f8b5d20fd6ff0ef07dc0717829e77cf20dd9aaa3a8a60c9758a194c5f727778c6b2485012ac8f796f37608b2e914734fca4a6f1e6432b2bdf3a36d695eb8965ec5492226a1eb4650cc39a6d34f7205c8ef2401ca896c7a536ecf84f9ca23ae0b4e6edb255ecb3b653a910c07d16067d56549d8b782e268be4642372bc933571b8bcb31c27c05ee2b961eae176df42ff484138bf3dde4ac0eb7705bab",
)

///|
let other_e : Bytes = @base16.decode_lossy("010001")

///|
let other_d : Bytes = @base16.decode_lossy(
  "05cdbd9181540a4a8775a91f88773788ada0ec9a06d1d1588fc55985c6aad7f3e4a626f045e530daf1a7304bce79d11875ee7f75e21b1a161af9b1ffbfddb05368f1bd37d9f03339fb2aa158c7ad53607bd347fa34872ef7f987c81f5a60c16acaf7d757971da02cf0d08400be323c14eb8c5b334ef7f34ebfeba3bfebb71d68a2837bba8623eac937ef994b56fa07337ffe12dc1ed945a28c06a3b9810a0a305c4948313b63c83511ce2b5fdc9a8f172b836eeea5908c6f79e2678ae33a338aa213d9ef6f10852696dd2a2bb30b953eecb953882df9b23c14f32c7648efe88807c47897231c7c1fb85a0f2c5c9ef0bd4eb629779866efc30222b2f6ba24a439",
)

///|
fn other_key() -> @rsa.PrivateKey {
  @rsa.PrivateKey::new(other_n[:], other_e[:], other_d[:]) catch {
    _ => abort("other fixture key must load")
  }
}

///|
test "verify accepts the openssl reference signature" {
  let ok = @crypto.verify_rsa_sha256(
    fixture_key().public(),
    b"moon-pay-sdk golden vector"[:],
    golden_signature[:],
  )
  assert_true(ok)
}

///|
test "verify rejects a tampered message" {
  let ok = @crypto.verify_rsa_sha256(
    fixture_key().public(),
    b"moon-pay-sdk golden vector!"[:],
    golden_signature[:],
  )
  assert_false(ok)
}

///|
test "verify rejects a tampered signature" {
  let tampered = @base16.decode_lossy(
    "7b5ddf2338d7a365195d049664afd6dd9ad482cf8f724ebc657b83bdf082b660f44d65cda72e379029e4400447a31fcf95dfadf6a76ca3034a4d869d652a960606d60c76ce48dcb93674e24bd089abe6d47e824c8cac900f5e576ceb2b9a8c7f1c0ef5e3c0d825b0ad65487dd2806a3ca1d9050ce03bacd041ded028bf565f5bcd7b8eace08e9a18e10e130fb6b9528a31b454a5f25c8082a18d88dfc43ffaff11f90e5c7469e2caa9c497135f1874ae76ccfbecf79d3b50c7005019e47280951950e7e99b3ea1d5fd7776f09e6d792b6c5fda2f9c6201a8d0b6fb13ed8731f5803105f5c38dfaa6be5e7beefe6c394ff1f70ecf9c1b1b426e9cbf8d15066faf",
  )
  let ok = @crypto.verify_rsa_sha256(
    fixture_key().public(),
    b"moon-pay-sdk golden vector"[:],
    tampered[:],
  )
  assert_false(ok)
}

///|
test "verify rejects a signature from a different key" {
  let sig = @crypto.sign_rsa_sha256(
    other_key(),
    b"moon-pay-sdk golden vector"[:],
  )
  let ok = @crypto.verify_rsa_sha256(
    fixture_key().public(),
    b"moon-pay-sdk golden vector"[:],
    sig[:],
  )
  assert_false(ok)
}

///|
test "verify accepts a signature from the matching key" {
  let sig = @crypto.sign_rsa_sha256(
    other_key(),
    b"moon-pay-sdk golden vector"[:],
  )
  let ok = @crypto.verify_rsa_sha256(
    other_key().public(),
    b"moon-pay-sdk golden vector"[:],
    sig[:],
  )
  assert_true(ok)
}
