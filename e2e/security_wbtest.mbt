///|
// T7.4 security negatives, consolidated: every attack below must be
// rejected with a distinct, clear error. The individual cases live next to
// their features; this suite proves the whole set in one place and pins the
// exact rejection reasons.

///|
// One signed callback body plus its headers, reusable for tampering.
fn valid_wechat_callback() -> (Array[(String, String)], Bytes) {
  notification_callback()
}

///|
fn wechat_client_for_security() -> @wechat.Client {
  let responses : Array[@transport.Response] = [
    { status: 200, headers: [], body: @utf8.encode(certificates_body()), },
  ]
  let mock = @transport.MockTransport::new(responses)
  @wechat.Client::new(
    config=@wechat.Config::new(
      appid="wx8888888888888888",
      mchid="1900000000",
      serial_no="TEST-SERIAL",
      private_key_pem=merchant_private_key_pem,
      api_v3_key=test_api_v3_key,
      base_url="https://api.mch.weixin.qq.com",
    ),
    transport=mock,
    now_ms=() => 1600000000000L,
    verify_responses=false,
  ) catch {
    e => abort("client must build: \{e}")
  }
}

///|
async test "wechat rejects each attack with a distinct reason" {
  // 1. Replayed callback: a genuine callback re-submitted 10 minutes later.
  let client = wechat_client_for_security()
  let (replay_headers, replay_body) = valid_wechat_callback()
  let stale_headers : Array[(String, String)] = []
  for pair in replay_headers {
    if pair.0 == "Wechatpay-Timestamp" {
      stale_headers.push((pair.0, "1599999400"))
    } else {
      stale_headers.push(pair)
    }
  }
  let replay : String = try
    client.verify_callback(stale_headers, replay_body)
  catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(replay.has_prefix("callback timestamp is "))
  assert_true(replay.contains("replay"))
  // 2. Unknown serial: the signature names a certificate we never issued.
  let unknown_headers : Array[(String, String)] = []
  for pair in replay_headers {
    if pair.0 == "Wechatpay-Serial" {
      unknown_headers.push((pair.0, "cafebabe"))
    } else {
      unknown_headers.push(pair)
    }
  }
  let unknown : String = try
    client.verify_callback(unknown_headers, replay_body)
  catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(unknown.contains("unknown even after refresh"))
  // 3. Tampered body: the signature no longer covers what is sent.
  let tampered : String = try
    client.verify_callback(
      replay_headers, b"{\"id\":\"evt-e2e\",\"event_type\":\"TRANSACTION.SUCCESS\"}",
    )
  catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(tampered, "callback signature verification failed")
}

///|
async test "wechat rejects a notification encrypted under the wrong key" {
  let client = wechat_client_for_security()
  // A body whose resource was sealed with a different APIv3 key.
  let wrong_key_resource = "{\"out_trade_no\":\"e2e-0001\"}"
  let cipher = @gcm.Gcm::new(
    @aes.Cipher::new(@utf8.encode("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")[:]) catch {
      _ => abort("cipher must init")
    },
  ) catch {
    _ => abort("gcm must init")
  }
  let sealed = cipher.seal(
    nonce=b"abc123def456",
    plain=@utf8.encode(wrong_key_resource)[:],
    aad=@utf8.encode("transaction")[:],
  )
  let ciphertext_b64 = @base64.encode(sealed[:])
  let text = "{\"id\":\"evt-e2e\",\"event_type\":\"TRANSACTION.SUCCESS\",\"resource_type\":\"encrypt-resource\",\"resource\":{\"algorithm\":\"AEAD_AES_256_GCM\",\"ciphertext\":\"" +
    ciphertext_b64 +
    "\",\"nonce\":\"abc123def456\",\"associated_data\":\"transaction\"}}"
  let message = "1600000000" + "\n" + "e2e-nonce" + "\n" + text + "\n"
  let signature = @crypto.sign_rsa_sha256(
    platform_key(),
    @utf8.encode(message)[:],
  )
  let headers : Array[(String, String)] = [
    ("Wechatpay-Serial", platform_serial),
    ("Wechatpay-Timestamp", "1600000000"),
    ("Wechatpay-Nonce", "e2e-nonce"),
    ("Wechatpay-Signature", @base64.encode(signature[:])),
  ]
  let verdict : String = try
    client.verify_callback(headers, @utf8.encode(text))
  catch {
    @moon-pay-sdk.Crypto(_) => "crypto failure"
    e => "other error: " + e.to_string()
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "crypto failure")
}

///|
async test "alipay rejects an amount that does not match the local order" {
  let mock = @transport.MockTransport::new([])
  let client = @alipay.Client::new(
    config=@alipay.Config::new(
      app_id="2021000000000000",
      private_key_pem=merchant_private_key_pem,
      alipay_public_key_pem=merchant_public_key_pem,
    ),
    transport=mock,
  ) catch {
    e => abort("client must build: \{e}")
  }
  // Properly signed by the "provider", but for a different amount.
  let unsigned : Array[(String, String)] = [
    ("app_id", "2021000000000000"),
    ("trade_status", "TRADE_SUCCESS"),
    ("out_trade_no", "e2e-0002"),
    ("trade_no", "2026100299999"),
    ("total_amount", "0.01"),
    ("sign_type", "RSA2"),
  ]
  let signature = @alipay.sign_params(app_private_key(), unsigned)
  let form : Array[(String, String)] = []
  for pair in unsigned {
    form.push((@alipay.percent_encode(pair.0), @alipay.percent_encode(pair.1)))
  }
  form.push(("sign", @alipay.percent_encode(signature)))
  let notify = client.verify_notify(form)
  // The signature is valid, so the rejection happens at reconciliation.
  assert_false(notify.amount_matches(8800))
  assert_eq(notify.total_fen(), 1)
}
