///|
// The plaintext payment result a TRANSACTION.SUCCESS notification carries.
let payment_resource_json : String = "{\"out_trade_no\":\"hack-20261001-0001\",\"transaction_id\":\"4200001234\",\"trade_state\":\"SUCCESS\",\"amount\":{\"total\":100,\"payer_total\":100,\"currency\":\"CNY\",\"payer_currency\":\"CNY\"}}"

///|
let notification_nonce : Bytes = b"abc123def456"

///|
// The full callback: envelope JSON whose resource is the encrypted payment
// result, with signature headers made by the platform key.
fn notification_callback(
  api_v3_key : String,
  aad : String,
  declared_aad? : String = "",
) -> (Array[(String, String)], Bytes) {
  let declared_aad = if declared_aad == "" { aad } else { declared_aad }
  let ciphertext = gcm_seal(
    api_v3_key, notification_nonce, payment_resource_json, aad,
  )
  let envelope : Json = {
    "id": "evt-1",
    "event_type": "TRANSACTION.SUCCESS",
    "summary": "支付成功",
    "resource_type": "encrypt-resource",
    "resource": {
      "algorithm": "AEAD_AES_256_GCM",
      "ciphertext": @base64.encode(ciphertext[:]),
      "nonce": "abc123def456",
      "associated_data": declared_aad,
    },
  }
  let text = @moon-pay-sdk.encode_json(envelope)
  (signed_callback_headers("1600000000", "cb-nonce", text), @utf8.encode(text))
}

///|
async test "a payment notification verifies, decrypts and parses" {
  let (client, mock) = mock_client([certs_response()])
  let (headers, body) = notification_callback(test_api_v3_key, "transaction")
  let notification = client.parse_notification(headers, body)
  assert_eq(notification.event_type(), "TRANSACTION.SUCCESS")
  assert_eq(notification.summary(), Some("支付成功"))
  assert_eq(notification.out_trade_no(), "hack-20261001-0001")
  assert_eq(notification.transaction_id(), "4200001234")
  assert_true(notification.trade_state() is Success)
  assert_eq(notification.total_fen(), 100)
  assert_eq(notification.payer_fen(), Some(100))
  // The raw decrypted resource stays reachable for unknown fields.
  let amount = @moon-pay-sdk.object_field(notification.resource(), "amount")
  assert_eq(@moon-pay-sdk.string_field(amount, "currency"), "CNY")
  assert_eq(@moon-pay-sdk.int_field(amount, "payer_total"), 100)
  // Exactly one certificate fetch.
  assert_eq(mock.recorded().length(), 1)
}

///|
async test "a notification encrypted under another key fails authentication" {
  let (client, _) = mock_client([certs_response()])
  let (headers, body) = notification_callback(
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "transaction",
  )
  let verdict : String = try client.parse_notification(headers, body) catch {
    @moon-pay-sdk.Crypto(_) => "crypto failure"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "crypto failure")
}

///|
async test "a notification with wrong associated data fails authentication" {
  let (client, _) = mock_client([certs_response()])
  let (headers, body) = notification_callback(
    test_api_v3_key,
    "transaction",
    declared_aad="wrong-aad",
  )
  let verdict : String = try client.parse_notification(headers, body) catch {
    @moon-pay-sdk.Crypto(_) => "crypto failure"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "crypto failure")
}

///|
async test "a tampered notification body never reaches decryption" {
  let (client, _) = mock_client([certs_response()])
  let (headers, _) = notification_callback(test_api_v3_key, "transaction")
  let verdict : String = try
    client.parse_notification(
      headers, b"{\"id\":\"evt-1\",\"event_type\":\"TRANSACTION.SUCCESS\",\"summary\":\"s\",\"resource_type\":\"encrypt-resource\",\"resource\":{}}",
    )
  catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "callback signature verification failed")
}
