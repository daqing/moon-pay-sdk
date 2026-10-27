///|
/// `wxlogin` — the server-side half of the mini-program login flow that
/// WeChat Pay JSAPI checkout needs.
///
/// `wx.login` codes are minted inside the WeChat client only (a real
/// device or WeChat DevTools); no server API can create one from appid and
/// secret. Give this command a fresh code plus the mini-program's
/// credentials, and it performs the exchange (`GET /sns/jscode2session`)
/// and prints the payer `openid` a JSAPI order needs:
///
///     moon run cmd/wxlogin -- --appid wx1234567890abcdef --secret SECRET --code 081Ab2Cd3Ef4Gh5
///
/// Missing values fall back to `WXPAY_APPID` / `WXPAY_APP_SECRET` (the
/// same variables cmd/webdemo uses) and finally to an interactive prompt.
async fn main {
  let matches = @argparse.Command(
    "wxlogin",
    about="Exchange a wx.login code for the openid used in WeChat mini-program payment (code2session)",
    options=[
      OptionArg(
        "appid",
        long="appid",
        about="mini-program AppID (falls back to $WXPAY_APPID, then a prompt)",
      ),
      OptionArg(
        "secret",
        long="secret",
        about="mini-program AppSecret (falls back to $WXPAY_APP_SECRET, then a prompt)",
      ),
      OptionArg(
        "code",
        long="code",
        about="fresh js_code from wx.login (single use, expires in 5 minutes)",
      ),
    ],
  ).parse()
  let appid_flag = match matches.values {
    { "appid": [value], .. } => Some(value)
    _ => None
  }
  let secret_flag = match matches.values {
    { "secret": [value], .. } => Some(value)
    _ => None
  }
  let code_flag = match matches.values {
    { "code": [value], .. } => Some(value)
    _ => None
  }
  let appid = resolve(appid_flag, "WXPAY_APPID", "mini-program AppID")
  let secret = resolve(
    secret_flag, "WXPAY_APP_SECRET", "mini-program AppSecret",
  )
  let js_code = match code_flag {
    Some(code) if !code.is_empty() => code
    _ => {
      print_how_to_get_code()
      resolve(None, "", "wx.login code")
    }
  }
  let config = @miniprogram.Config::new(app_id=appid, app_secret=secret)
  let session = try
    @miniprogram.code2session_with(
      config~,
      transport=@transport.HttpClient::new(),
      js_code~,
    )
  catch {
    Api(api) => {
      println("")
      println("WeChat rejected the exchange: \{api.code} — \{api.message}")
      println("hint: \{errcode_hint(api.code)}")
      fail("wxlogin aborted")
    }
    e => {
      println("")
      println("code2session failed: \{e}")
      fail("wxlogin aborted")
    }
  } noraise {
    session => session
  }
  print_session(session)
}

///|
/// First non-empty source wins: explicit flag, then the environment, then
/// an interactive prompt reading one line from stdin.
async fn resolve(flag : String?, env_name : String, label : String) -> String {
  match flag {
    Some(value) if !value.is_empty() => return value
    _ => ()
  }
  if env_name != "" {
    match @env.get_env_var(env_name) {
      Some(value) if !value.is_empty() => return value
      _ => ()
    }
  }
  println("\{label} (paste and press Enter):")
  match @stdio.stdin.read_until("\n") {
    Some(line) =>
      match line.trim().to_owned() {
        "" => fail("\{label} is required")
        value => value
      }
    None => fail("\{label} is required (stdin closed)")
  }
}

///|
/// The code cannot be fetched by any server-side API — it is minted inside
/// the WeChat client. Point the developer at the fastest ways to get one.
fn print_how_to_get_code() -> Unit {
  println("")
  println("A wx.login code can only be produced by the WeChat client —")
  println("no server-side API mints one from appid/secret. Fastest paths:")
  println(
    "  1. WeChat DevTools console:  wx.login().then(res => console.log(res.code))",
  )
  println("  2. Or call wx.login() inside your mini program and log res.code.")
  println("Codes are single-use and expire within 5 minutes.")
  println("Re-run with --code <CODE>, or paste one below.")
}

///|
/// Print the exchange result: everything a JSAPI order needs.
fn print_session(session : @miniprogram.Session) -> Unit {
  println("")
  println("code2session ok — payer identity for JSAPI payment:")
  println("  openid      : \{session.openid()}")
  println(
    "  session_key : \{session.session_key()}  (keep server-side; payment only needs openid)",
  )
  match session.unionid() {
    Some(unionid) => println("  unionid     : \{unionid}")
    None =>
      println(
        "  unionid     : (absent — app not bound to an open-platform account)",
      )
  }
  println("")
  println("next: place a JSAPI order with this openid, e.g.")
  println(
    "  client.pay_with_openid(out_trade_no=..., total=..., description=..., notify_url=..., openid=\"\{session.openid()}\")",
  )
}

///|
/// A one-line explanation for the login error codes seen in practice.
fn errcode_hint(code : String) -> String {
  match code {
    "40029" =>
      "the code is invalid, already used, or expired — grab a fresh one from wx.login"
    "40013" => "the appid is invalid"
    "41004" | "40125" => "the appsecret is missing or wrong"
    "45011" => "rate limited by WeChat — wait a minute and retry"
    "-1" => "WeChat system busy — retry shortly"
    _ => "see WeChat's global return code list"
  }
}
