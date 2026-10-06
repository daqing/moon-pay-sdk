///|
// The APIv3 key must be exactly 32 characters — 32 'a's here.
let valid_api_v3_key : String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

///|
fn valid_config() -> @wechat.Config {
  @wechat.Config::new(
    appid="wx8888888888888888",
    mchid="1900000000",
    serial_no="TEST-SERIAL",
    private_key_pem="-----BEGIN PRIVATE KEY-----",
    api_v3_key=valid_api_v3_key,
  )
}

///|
test "a valid config passes validation and defaults to the prod gateway" {
  let config = valid_config()
  @wechat.Config::validate(config)
  assert_eq(config.base_url, "https://api.mch.weixin.qq.com")
}

///|
test "the base url can point at a sandbox or mock server" {
  let config = @wechat.Config::new(
    appid="wx8888888888888888",
    mchid="1900000000",
    serial_no="TEST-SERIAL",
    private_key_pem="-----BEGIN PRIVATE KEY-----",
    api_v3_key=valid_api_v3_key,
    base_url="http://127.0.0.1:49002",
  )
  @wechat.Config::validate(config)
  assert_eq(config.base_url, "http://127.0.0.1:49002")
}

///|
test "empty required fields are rejected with the field name" {
  let cases : Array[(String, @wechat.Config)] = [
    (
      "appid",
      @wechat.Config::new(
        appid="",
        mchid="1900000000",
        serial_no="S",
        private_key_pem="pem",
        api_v3_key=valid_api_v3_key,
      ),
    ),
    (
      "mchid",
      @wechat.Config::new(
        appid="wx1",
        mchid="",
        serial_no="S",
        private_key_pem="pem",
        api_v3_key=valid_api_v3_key,
      ),
    ),
    (
      "serial_no",
      @wechat.Config::new(
        appid="wx1",
        mchid="1900000000",
        serial_no="",
        private_key_pem="pem",
        api_v3_key=valid_api_v3_key,
      ),
    ),
    (
      "private_key_pem",
      @wechat.Config::new(
        appid="wx1",
        mchid="1900000000",
        serial_no="S",
        private_key_pem="",
        api_v3_key=valid_api_v3_key,
      ),
    ),
  ]
  for case in cases {
    let verdict : String = try @wechat.Config::validate(case.1) catch {
      @moon-pay-sdk.Config(message) => message
      _ => "other error"
    } noraise {
      _ => "no error raised"
    }
    assert_true(verdict.has_prefix(case.0))
  }
}

///|
test "a wrong api_v3_key length is rejected with both lengths" {
  let config = @wechat.Config::new(
    appid="wx1",
    mchid="1900000000",
    serial_no="S",
    private_key_pem="pem",
    api_v3_key="too-short",
  )
  let verdict : String = try @wechat.Config::validate(config) catch {
    @moon-pay-sdk.Config(message) => message
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "api_v3_key must be 32 characters, got 9")
}

///|
test "a base url without a scheme is rejected" {
  let config = @wechat.Config::new(
    appid="wx1",
    mchid="1900000000",
    serial_no="S",
    private_key_pem="pem",
    api_v3_key=valid_api_v3_key,
    base_url="api.mch.weixin.qq.com",
  )
  let verdict : String = try @wechat.Config::validate(config) catch {
    @moon-pay-sdk.Config(message) => message
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_true(verdict.has_prefix("base_url"))
}

///|
test "stray whitespace in merchant identifiers is rejected" {
  let cases : Array[(String, @wechat.Config)] = [
    (
      "appid",
      @wechat.Config::new(
        appid=" wx8888888888888888",
        mchid="1900000000",
        serial_no="S",
        private_key_pem="pem",
        api_v3_key=valid_api_v3_key,
      ),
    ),
    (
      "mchid",
      @wechat.Config::new(
        appid="wx1",
        mchid="1900000000 ",
        serial_no="S",
        private_key_pem="pem",
        api_v3_key=valid_api_v3_key,
      ),
    ),
    (
      "serial_no",
      @wechat.Config::new(
        appid="wx1",
        mchid="1900000000",
        serial_no="5C37C246C82F80008697C83D8F8761F99D773410 ",
        private_key_pem="pem",
        api_v3_key=valid_api_v3_key,
      ),
    ),
  ]
  for case in cases {
    let verdict : String = try @wechat.Config::validate(case.1) catch {
      @moon-pay-sdk.Config(message) => message
      _ => "other error"
    } noraise {
      _ => "no error raised"
    }
    assert_true(verdict.has_prefix(case.0))
    assert_true(verdict.contains("whitespace"))
  }
}
