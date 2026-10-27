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
///
/// With `--project <dir>` the command instead drives WeChat DevTools over
/// its automation port, runs `wx.login` inside the real project and just
/// prints the fresh code — hand it to the webdemo mini-program panel,
/// which exchanges it for the openid and places the order:
///
///     moon run cmd/wxlogin -- --project ~/mini-programs/demo
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
      OptionArg(
        "project",
        long="project",
        about="mini-program project dir: drive WeChat DevTools to grab a real wx.login code automatically",
      ),
      OptionArg(
        "cli",
        long="cli",
        about="WeChat DevTools cli binary (falls back to $WXPAY_DEVTOOLS_CLI, then the macOS default)",
      ),
    ],
  ).parse()
  let project = match matches.values {
    { "project": [value], .. } => Some(value)
    _ => None
  }
  let cli_flag = match matches.values {
    { "cli": [value], .. } => Some(value)
    _ => None
  }
  match project {
    Some(project) if !project.is_empty() =>
      return run_auto_mode(cli_flag, project)
    _ => ()
  }
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

///|
/// Default DevTools cli location (matches what miniprogram-automator
/// resolves: the Windows cli.bat when present, else the macOS bundle).
async fn default_cli_path() -> String {
  let windows = "C:/Program Files (x86)/Tencent/微信web开发者工具/cli.bat"
  if @fs.exists(windows) {
    windows
  } else {
    "/Applications/wechatwebdevtools.app/Contents/MacOS/cli"
  }
}

///|
/// Automation mode: launch WeChat DevTools with its automation port,
/// run `wx.login` inside the real project and print the fresh code. No
/// appid/secret needed here — webdemo does the openid exchange and the
/// order with this code.
async fn run_auto_mode(cli_flag : String?, project_path : String) -> Unit {
  let cli_path = match cli_flag {
    Some(path) if !path.is_empty() => path
    _ =>
      match @env.get_env_var("WXPAY_DEVTOOLS_CLI") {
        Some(path) if !path.is_empty() => path
        _ => default_cli_path()
      }
  }
  if !@fs.exists(cli_path) {
    fail(
      "DevTools cli not found at \{cli_path} — pass --cli <path> or set WXPAY_DEVTOOLS_CLI",
    )
  }
  if !@fs.exists(project_path) {
    fail("mini-program project not found: \{project_path}")
  }
  println(
    "fetching a fresh wx.login code from the DevTools project \{project_path}",
  )
  launch_devtools(cli_path~, project_path~, port=DEFAULT_AUTO_PORT)
  let automator = Automator::connect("ws://127.0.0.1:\{DEFAULT_AUTO_PORT}")
  let code = try
    @async.with_timeout(
      60_000,
      () => grab_code(automator),
      error=Timeout("wx.login via DevTools timed out after 60s"),
    )
  catch {
    e => {
      automator.close()
      println("")
      println("automation failed: \{e}")
      fail("wxlogin aborted")
    }
  } noraise {
    code => {
      automator.close()
      code
    }
  }
  print_code(code, project_path)
}

///|
/// Liveness probe, then the login call itself.
async fn grab_code(automator : Automator) -> String {
  let _ = automator.get_info()
  let result = automator.call_wx_method("login")
  login_code_from(result)
}

///|
/// The automation port miniprogram-automator uses by default.
const DEFAULT_AUTO_PORT : Int32 = 9420

///|
/// Print the grabbed code plus the fastest way to turn it into an order.
fn print_code(code : String, project_path : String) -> Unit {
  println("")
  println("wx.login ok — fresh code from the DevTools project:")
  println("  project : \{project_path}")
  println("  code    : \{code}")
  println("")
  println("next: paste it into the webdemo mini-program panel, or POST it:")
  println(
    "  curl -X POST 'http://127.0.0.1:1943/api/wechat/miniapp/orders?amount_yuan=0.01&js_code=\{code}'",
  )
  println(
    "(single use, expires in 5 minutes; the IDE stays open — rerun for another code)",
  )
}
