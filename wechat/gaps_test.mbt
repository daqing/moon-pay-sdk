///|
// T7.2 gap coverage: one error path per public method that earlier suites
// did not exercise. Happy paths live in the method-specific test files.

///|
async test "h5 order surfaces provider errors as Api errors" {
  let (client, _) = mock_client([
    {
      status: 400,
      headers: [],
      body: b"{\"code\":\"PARAM_ERROR\",\"message\":\"scene_info invalid\"}",
    },
  ])
  let err : @moon-pay-sdk.SdkError = try
    client.h5_order(
      out_trade_no="hack-20261001-0002",
      total=100,
      description="x",
      notify_url="https://example.com/cb",
      payer_client_ip="203.0.113.7",
    )
  catch {
    e => e
  } noraise {
    _ => abort("expected an error")
  }
  assert_eq("\{err}", "api error PARAM_ERROR (http 400): scene_info invalid")
}

///|
async test "query by transaction id rejects an empty id locally" {
  let (client, mock) = mock_client([])
  let verdict : String = try client.query_order_by_id(transaction_id="") catch {
    @moon-pay-sdk.Config(_) => "rejected locally"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "rejected locally")
  assert_eq(mock.recorded().length(), 0)
}

///|
async test "a callback without the Wechatpay-* headers is rejected" {
  let (client, _) = mock_client([certs_response()])
  let verdict : String = try
    client.verify_callback([("Content-Type", "application/json")], b"{}")
  catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "callback is missing the Wechatpay-* signature headers")
}

///|
async test "a certificate list without data is a network error" {
  let (client, _) = mock_client([
    { status: 200, headers: [], body: b"{\"unexpected\":true}", },
  ])
  let verdict : String = try
    client.platform_public_key("4e42d63e06e3969f7360e892f118b86f9d8ab3da")
  catch {
    @moon-pay-sdk.Network(detail) => detail
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(verdict.has_prefix("certificate list is malformed"))
}
