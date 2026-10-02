///|
// Key material from test_keys/, regenerated per test_keys/README.md.
test "rsa sign and verify round trip through mooncrypt" {
  let n = @base16.decode_lossy(
    "0097cc6754ea9a6141ab9129aabf86ee883ad2c2f79c85d267e45a3114b68d8fc948613ddabb50f863926de8f6efd50e40df11f141bd1c2a9a9fabd216ef142678171c716f7ec1d411c3dea521a815fbe4ccf0e08d80d2a15e08c7e1ec0a746befe91d10cc5ca66f43bba6e0b99fab297d8282ec3de0c57849e99082d06d87e31e61fa679b8d8820b2e2ed5285c71fff5ad756731a0eca255d25c9efa4ca2695b1a3d839da1854696f61bc5e9ac77fc9438f3d0db3df9df83e552a00d87e5f4d1e9689f80b27fd725c49f26ba1c92868d64312712da16d66f696d420251ef8ac2833476041804943e2bffb42334583dd7f42168b9199f7c7a78a0e38cd9e22c3eb",
  )
  let e = @base16.decode_lossy("010001")
  let d = @base16.decode_lossy(
    "05790cf803f5fe9aaa5a5df90b8061ba39fb5e4f24c40862ceda0244aa68ee8305ca87bb354a0537e5d01e4d9a3656c0b7aa2dc613d0dfa7afd3b7368a211d054864074cf5f226b8b5e9f6e48095bba808a1889f0c1821519819c8c744ab3a3703486a7ccbbc59179a9238d8f31798892f6593ff3920357c33610e990027483a17cfd27fb0e103e560ad3ee5fb60e7b3f3018caff2e60f8a8b241193eabb1fa38b7b199ba0da456965573d1b920c1a50fe836f21fb009c2e7c7c08bdb76a674570f8d13adc43209ac17ca5a6a4c4623c20c5c2da0487a0c3e1d2de2e6ef5617eb4d14f29d1b796eca31ec73d7ce41ad6e1129641fee19a5c447b12ecb98215fd",
  )
  let key = @rsa.PrivateKey::new(n[:], e[:], d[:])
  let message = b"moon-pay-sdk round trip"
  let sig = key.sign(message[:])
  assert_eq(sig.length(), 256)
  assert_true(key.public().verify(message[:], sig[:]))
  assert_false(key.public().verify(b"tampered message"[:], sig[:]))
}
