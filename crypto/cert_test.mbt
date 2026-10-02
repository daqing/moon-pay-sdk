///|
// Fixture certificate from test_keys/, regenerated per test_keys/README.md.
let platform_certificate_pem : String =
  #|-----BEGIN CERTIFICATE-----
  #|MIIDZTCCAk2gAwIBAgIUTkLWPgbjlp9zYOiS8Ri4b52Ks9owDQYJKoZIhvcNAQEL
  #|BQAwQjEjMCEGA1UEAwwabW9vbi1wYXktc2RrIHRlc3QgcGxhdGZvcm0xGzAZBgNV
  #|BAoMEm1vb24tcGF5LXNkayB0ZXN0czAeFw0yNjEwMDIwMDAxMTRaFw0zNjA5Mjkw
  #|MDAxMTRaMEIxIzAhBgNVBAMMGm1vb24tcGF5LXNkayB0ZXN0IHBsYXRmb3JtMRsw
  #|GQYDVQQKDBJtb29uLXBheS1zZGsgdGVzdHMwggEiMA0GCSqGSIb3DQEBAQUAA4IB
  #|DwAwggEKAoIBAQDy/08KDz8vcYNL/P170YJ+5hn7S4mz7ZiiT45/p48CyWK69Vna
  #|R0lmaHrE8b9VQJWLifQiiJW44IXw4DutPWw+e/kO/Oxm716yvxC682FPbBfjMA2w
  #|TfxMT1ZDBPx8X5dgqTb1N05jkjsuz+ME2jw4V+4B98onFxnJUj/dMuoQa4fDrIj1
  #|1iDVpSI4t+qX/2KzFvP3xDZcb+rXlELXrnLQ2CTVxJrPIaS0/syKXCuC7d6ApurV
  #|bl4rk059hjyFvcC/2i/85UzRB3iE8oJJ8bSXYKsUCmoO9yoFV4nHY5pz34pcIGw2
  #|uJ6fcZiJKXh3YacD36Vul63D4KxjQvSDh/zBAgMBAAGjUzBRMB0GA1UdDgQWBBR0
  #|VxVpjvmLhiAHktYqxbkquibdvjAfBgNVHSMEGDAWgBR0VxVpjvmLhiAHktYqxbkq
  #|uibdvjAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQC5R4FcHitJ
  #|RGK94W9vjyRt8glBgoOCEz40VKAsgXNCSIV9mUkswLTU/HnjhpTg3O6vlNulykk1
  #|3CwpvW98oUIyj/ENnJKzOIHvgHnSF5kYCRohAgjHd/xPbpT2J3tgoI7ggN6SMkeI
  #|aeHFKIDlyRYAlYW+GCekNPFqvLS+ytoaGt6u4h0GpOW/WAethOxAelMks7YWnRCL
  #|RTHf+SF2eqG8G9kVMXYT3vvDcG6l6uMHwz7llV8YIXYjCSIAV7mhqskDkBFhQzvW
  #|bCgRK5M65ay7GYGaJcmWeBAC8hI2bP5y5I3eMJ7fCH0hEeVC8EH/bIOUTEujcDQ2
  #|XVu9fdnUmGsS
  #|-----END CERTIFICATE-----

///|
// The platform signing key behind the certificate, from
// test_keys/platform_private_key.pem.
let platform_n : Bytes = @base16.decode_lossy(
  "00f2ff4f0a0f3f2f71834bfcfd7bd1827ee619fb4b89b3ed98a24f8e7fa78f02c962baf559da474966687ac4f1bf5540958b89f4228895b8e085f0e03bad3d6c3e7bf90efcec66ef5eb2bf10baf3614f6c17e3300db04dfc4c4f564304fc7c5f9760a936f5374e63923b2ecfe304da3c3857ee01f7ca271719c9523fdd32ea106b87c3ac88f5d620d5a52238b7ea97ff62b316f3f7c4365c6fead79442d7ae72d0d824d5c49acf21a4b4fecc8a5c2b82edde80a6ead56e5e2b934e7d863c85bdc0bfda2ffce54cd1077884f28249f1b49760ab140a6a0ef72a055789c7639a73df8a5c206c36b89e9f71988929787761a703dfa56e97adc3e0ac6342f48387fcc1",
)

///|
let platform_e : Bytes = @base16.decode_lossy("010001")

///|
let platform_d : Bytes = @base16.decode_lossy(
  "1ba4b6b9a6bd61e8d06e7313e52392ec5bc1e5e8147cbf114799b454ca5b870e20e8b2e3ab64c3b15e3e652c393f7a0ee92662fb10bdb39ffb2cc95d909a35b7b003c7d4371288b5a5b0fdb6bedc399c4ae5620094a77285bddacada04dd2344c5ceca3d4032ef39e1f8b3d698253987915d36a5193eb42e8f4c078ee2ed64bb961f8900724485d9cfe67e1e7360deedaadbc79b32fb70f2d4c95d48afe184fb0de4b566f8355f1fdaea8e884a85919f1d2e1163c5692d70aefc0ac89c9f3b137e301621b1c7377f39f677c773f7322d194b79da2852bdac47f19c3a39e7922de2a25463661c536c0845d0f8e0933e6cb2ab9574ee99759a9ffbb6d96aeb97bf",
)

///|
fn platform_key() -> @rsa.PrivateKey {
  @rsa.PrivateKey::new(platform_n[:], platform_e[:], platform_d[:]) catch {
    _ => abort("platform fixture key must load")
  }
}

///|
test "certificate exposes its serial in lowercase hex" {
  let cert = @crypto.load_certificate_pem(platform_certificate_pem)
  assert_eq(
    @crypto.certificate_serial_hex(cert),
    "4e42d63e06e3969f7360e892f118b86f9d8ab3da",
  )
}

///|
test "certificate public key verifies a signature made by the platform key" {
  let cert = @crypto.load_certificate_pem(platform_certificate_pem)
  let pub_key = @crypto.certificate_public_key(cert)
  let sig = @crypto.sign_rsa_sha256(platform_key(), b"platform payload"[:])
  assert_true(
    @crypto.verify_rsa_sha256(pub_key, b"platform payload"[:], sig[:]),
  )
}

///|
test "a garbage certificate is rejected" {
  let verdict : String = try @crypto.load_certificate_pem("hello") catch {
    @crypto.Malformed(_) => "malformed"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "malformed")
}
