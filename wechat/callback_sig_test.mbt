///|
// Seconds for the pinned client clock.
let pinned_now_seconds : Int64 = 1600000000L

///|
fn callback_message(
  timestamp : String,
  nonce : String,
  body : String,
) -> String {
  "\{timestamp}\n\{nonce}\n\{body}\n"
}

///|
// Build callback headers whose signature is made by the platform key.
fn signed_callback_headers(
  timestamp : String,
  nonce : String,
  body : String,
) -> Array[(String, String)] {
  let message = callback_message(timestamp, nonce, body)
  let signature = @crypto.sign_rsa_sha256(
    platform_key(),
    @utf8.encode(message)[:],
  )
  [
    ("Wechatpay-Serial", platform_serial),
    ("Wechatpay-Timestamp", timestamp),
    ("Wechatpay-Nonce", nonce),
    ("Wechatpay-Signature", @base64.encode(signature[:])),
  ]
}

///|
async test "a valid callback signature verifies against fetched certs" {
  let (client, mock) = mock_client([certs_response()])
  let body = "{\"id\":\"evt-1\"}"
  let headers = match
    @wechat.callback_headers_of(
      signed_callback_headers("1600000000", "cb-nonce", body),
    ) {
    Some(headers) => headers
    None => abort("headers must extract")
  }
  client.verify_callback_signature(headers~, body~)
  assert_eq(mock.recorded().length(), 1)
}

///|
async test "a tampered callback body fails verification" {
  let (client, _) = mock_client([certs_response()])
  let headers = match
    @wechat.callback_headers_of(
      signed_callback_headers("1600000000", "cb-nonce", "{\"id\":\"evt-1\"}"),
    ) {
    Some(headers) => headers
    None => abort("headers must extract")
  }
  let verdict : String = try
    client.verify_callback_signature(
      headers~,
      body="{\"id\":\"evt-1-TAMPERED\"}",
    )
  catch {
    @moon-pay-sdk.Network(_) => "rejected"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected")
}

///|
async test "an old callback timestamp is rejected as a replay" {
  let (client, _) = mock_client([certs_response()])
  // Signed 10 minutes ago; the pinned clock reads 1600000000.
  let headers = match
    @wechat.callback_headers_of(
      signed_callback_headers("1599999400", "cb-nonce", "{\"id\":\"evt-1\"}"),
    ) {
    Some(headers) => headers
    None => abort("headers must extract")
  }
  let verdict : String = try
    client.verify_callback_signature(headers~, body="{\"id\":\"evt-1\"}")
  catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(detail_mentions_replay(verdict))
}

///|
fn detail_mentions_replay(detail : String) -> Bool {
  detail.has_prefix("callback timestamp is ") && detail.contains("replay")
}

///|
async test "callbacks missing a header set are rejected" {
  let (client, _) = mock_client([certs_response()])
  let headers = signed_callback_headers("1600000000", "cb-nonce", "{}")
  let partial : Array[(String, String)] = []
  for i in 0..<(headers.length() - 1) {
    partial.push(headers[i])
  }
  assert_eq(@wechat.callback_headers_of(partial) is None, true)
}

///|
async test "api responses are signature-verified when enabled" {
  // Script order (popped from the back): the signed order answer first, then
  // the certificate list it triggers for verification.
  let order_body = "{\"code_url\":\"weixin://wxpay/bizpayurl?pr=resp\"}"
  let timestamp = "1600000000"
  let nonce = "resp-nonce"
  let message = callback_message(timestamp, nonce, order_body)
  let signature = @crypto.sign_rsa_sha256(
    platform_key(),
    @utf8.encode(message)[:],
  )
  let signed_response : @transport.Response = {
    status: 200,
    headers: [
      ("Wechatpay-Serial", platform_serial),
      ("Wechatpay-Timestamp", timestamp),
      ("Wechatpay-Nonce", nonce),
      ("Wechatpay-Signature", @base64.encode(signature[:])),
    ],
    body: @utf8.encode(order_body),
  }
  let mock = @transport.MockTransport::new([certs_response(), signed_response])
  let client = @wechat.Client::new(
    config=@wechat.Config::new(
      appid="wx8888888888888888",
      mchid="1900000000",
      serial_no="TEST-SERIAL",
      private_key_pem=merchant_pem,
      api_v3_key=test_api_v3_key,
      base_url="https://api.mch.weixin.qq.com",
    ),
    transport=mock,
    now_ms=() => pinned_now_seconds * 1000L,
  ) catch {
    e => abort("client must build: \{e}")
  }
  let order = client.native_order(
    out_trade_no="hack-20261001-0001",
    total=100,
    description="x",
    notify_url="https://example.com/cb",
  )
  assert_eq(order.code_url(), "weixin://wxpay/bizpayurl?pr=resp")
  // The certificate fetch plus the order call.
  assert_eq(mock.recorded().length(), 2)
}

///|
async test "a tampered API response signature fails the request" {
  let order_body = "{\"code_url\":\"weixin://wxpay/bizpayurl?pr=resp\"}"
  let timestamp = "1600000000"
  let nonce = "resp-nonce"
  let message = callback_message(timestamp, nonce, order_body)
  let signature = @crypto.sign_rsa_sha256(
    platform_key(),
    @utf8.encode(message)[:],
  )
  // Corrupt the last signature byte before encoding.
  let corrupt = signature[:].to_array()
  corrupt[corrupt.length() - 1] = corrupt[corrupt.length() - 1] ^ b'\x01'
  let sig_text = @base64.encode(Bytes::from_array(corrupt))
  let tampered : @transport.Response = {
    status: 200,
    headers: [
      ("Wechatpay-Serial", platform_serial),
      ("Wechatpay-Timestamp", timestamp),
      ("Wechatpay-Nonce", nonce),
      ("Wechatpay-Signature", sig_text),
    ],
    body: @utf8.encode(order_body),
  }
  let mock = @transport.MockTransport::new([certs_response(), tampered])
  let client = @wechat.Client::new(
    config=@wechat.Config::new(
      appid="wx8888888888888888",
      mchid="1900000000",
      serial_no="TEST-SERIAL",
      private_key_pem=merchant_pem,
      api_v3_key=test_api_v3_key,
      base_url="https://api.mch.weixin.qq.com",
    ),
    transport=mock,
    now_ms=() => pinned_now_seconds * 1000L,
  ) catch {
    e => abort("client must build: \{e}")
  }
  let verdict : String = try
    client.native_order(
      out_trade_no="hack-20261001-0001",
      total=100,
      description="x",
      notify_url="https://example.com/cb",
    )
  catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "response signature verification failed")
}
