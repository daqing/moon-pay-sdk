///|
fn valid_config() -> @alipay.Config {
  @alipay.Config::new(
    app_id="2021000000000000",
    private_key_pem="-----BEGIN RSA PRIVATE KEY-----",
    alipay_public_key_pem="-----BEGIN PUBLIC KEY-----",
  )
}

///|
test "a valid config passes validation and defaults to the prod gateway" {
  let config = valid_config()
  @alipay.Config::validate(config)
  assert_eq(config.gateway_url, "https://openapi.alipay.com/gateway.do")
}

///|
test "the gateway can point at the sandbox or a mock server" {
  let config = @alipay.Config::new(
    app_id="2021000000000000",
    private_key_pem="-----BEGIN RSA PRIVATE KEY-----",
    alipay_public_key_pem="-----BEGIN PUBLIC KEY-----",
    gateway_url="https://openapi-sandbox.dl.alipaydev.com/gateway.do",
  )
  @alipay.Config::validate(config)
}

///|
test "empty required fields are rejected with the field name" {
  let cases : Array[(String, @alipay.Config)] = [
    (
      "app_id",
      @alipay.Config::new(
        app_id="",
        private_key_pem="pem",
        alipay_public_key_pem="pub",
      ),
    ),
    (
      "private_key_pem",
      @alipay.Config::new(
        app_id="2021000000000000",
        private_key_pem="",
        alipay_public_key_pem="pub",
      ),
    ),
    (
      "alipay_public_key_pem",
      @alipay.Config::new(
        app_id="2021000000000000",
        private_key_pem="pem",
        alipay_public_key_pem="",
      ),
    ),
  ]
  for case in cases {
    let verdict : String = try @alipay.Config::validate(case.1) catch {
      @moon-pay-sdk.Config(message) => message
      _ => "other error"
    } noraise {
      _ => "no error raised"
    }
    assert_true(verdict.has_prefix(case.0))
  }
}

///|
test "a gateway url without a scheme is rejected" {
  let config = @alipay.Config::new(
    app_id="2021000000000000",
    private_key_pem="pem",
    alipay_public_key_pem="pub",
    gateway_url="openapi.alipay.com/gateway.do",
  )
  let verdict : String = try @alipay.Config::validate(config) catch {
    @moon-pay-sdk.Config(message) => message
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(verdict.has_prefix("gateway_url"))
}
