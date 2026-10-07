///|
/// A minimal web app for manually integration-testing moon-pay-sdk's WeChat
/// Pay Native (QR) checkout and Alipay page (desktop website) checkout
/// against the real gateways. It serves one page per gateway:
///
/// - `/` (WeChat): create an order, render the returned `code_url` as a QR
///   code and poll until WeChat Pay reports the order paid.
/// - `/alipay`: create a page-pay order (`alipay.trade.page.pay`) and
///   redirect the browser to the returned cashier URL; when Alipay redirects
///   back to `/alipay?alipay_order=<out_trade_no>` the page resumes polling.
///
/// Each page is enabled only when its gateway's credentials are present, so
/// the app runs with either gateway alone. Credentials come from WXPAY_* /
/// ALIPAY_* environment variables so none of them live in this repository.
///
/// Run from the repository root:
///
///     moon run cmd/webdemo
///
/// then open <http://127.0.0.1:1943> (WeChat) or
/// <http://127.0.0.1:1943/alipay> (Alipay).

///|
/// One order this app has placed, keyed by out_trade_no.
priv struct OrderRec {
  amount_fen : Int
  mut notify_seen : Bool
}

///|
priv struct App {
  wechat : @wechat.Client?
  notify_url : String
  alipay : @alipay.Client?
  alipay_notify_url : String
  orders : Map[String, OrderRec]
  mut seq : Int
}

///|
const LISTEN_PORT : Int = 1943

///|
async fn main {
  let wechat = load_wechat()
  let alipay = load_alipay()
  if wechat is None && alipay is None {
    return
  }
  if wechat is None {
    println("note: WeChat Pay page disabled (WXPAY_* incomplete)")
  }
  if alipay is None {
    println("note: Alipay page disabled (ALIPAY_* incomplete)")
  }
  let (wechat_client, notify_url) = match wechat {
    Some((client, notify_url)) => (Some(client), notify_url)
    None => (None, "")
  }
  let (alipay_client, alipay_notify_url) = match alipay {
    Some((client, notify_url)) => (Some(client), notify_url)
    None => (None, "")
  }
  let app : App = {
    wechat: wechat_client,
    notify_url,
    alipay: alipay_client,
    alipay_notify_url,
    orders: Map([]),
    seq: 0,
  }
  let index_html = read_asset("cmd/webdemo/assets/index.html")
  let alipay_html = read_asset("cmd/webdemo/assets/alipay.html")
  let qrcode_js = read_asset("cmd/webdemo/assets/qrcode.js")
  let server = @http.Server::Server(
    @socket.Addr::parse("0.0.0.0:\{LISTEN_PORT}") catch {
      _ => @socket.Addr::new(0U, LISTEN_PORT)
    },
  )
  let port = server.addr.port()
  println("listening on http://127.0.0.1:\{port} — open it in a browser")
  server.run_forever(
    async fn(req, reader, conn) {
      route(app, index_html, alipay_html, qrcode_js, req, reader, conn)
    },
    allow_failure=true,
  ) catch {
    e => println("server stopped: \{e}")
  }
}

///|
/// Read the WXPAY_* credentials from the environment, print what is missing,
/// and build the WeChat Pay client. Returns None when the page stays
/// disabled.
async fn load_wechat() -> (@wechat.Client, String)? {
  let missing : Array[String] = []
  let appid = require_env("WXPAY_APPID", missing)
  let mchid = require_env("WXPAY_MCHID", missing)
  let serial_no = require_env("WXPAY_SERIAL_NO", missing)
  let api_v3_key = require_env("WXPAY_API_V3_KEY", missing)
  let private_key_pem = load_pem_env("WXPAY_PRIVATE_KEY", missing)
  let base_url = match @env.get_env_var("WXPAY_BASE_URL") {
    Some(url) => url
    None => "https://api.mch.weixin.qq.com"
  }
  let notify_url = match @env.get_env_var("WXPAY_NOTIFY_URL") {
    Some(url) => url
    None => "https://example.com/moon-pay-sdk/wechat/notify"
  }
  // Public-key mode (公钥模式): the merchant-console WeChat Pay public key
  // and its PUB_KEY_ID_... serial, both optional (certificate mode omits them).
  let pubkey : (String, String)? = match
    (
      @env.get_env_var("WXPAY_PUBLIC_KEY"),
      @env.get_env_var("WXPAY_PUBLIC_KEY_ID"),
    ) {
    (Some(raw), Some(id)) =>
      if id == "" {
        missing.push("WXPAY_PUBLIC_KEY_ID (set but empty)")
        None
      } else if raw == "" {
        missing.push("WXPAY_PUBLIC_KEY (set but empty)")
        None
      } else if raw.has_prefix("-----BEGIN") {
        Some((raw, id))
      } else {
        match read_file_text(raw) {
          Some(pem) => Some((pem, id))
          None => {
            missing.push(
              "WXPAY_PUBLIC_KEY (not a PEM and not a readable file: \{raw})",
            )
            None
          }
        }
      }
    (Some(_), None) => {
      missing.push(
        "WXPAY_PUBLIC_KEY_ID (required when WXPAY_PUBLIC_KEY is set)",
      )
      None
    }
    (None, Some(_)) => {
      missing.push(
        "WXPAY_PUBLIC_KEY (required when WXPAY_PUBLIC_KEY_ID is set)",
      )
      None
    }
    (None, None) => None
  }
  if missing.length() > 0 ||
    appid is None ||
    mchid is None ||
    serial_no is None ||
    api_v3_key is None ||
    private_key_pem is None {
    println("webdemo needs WeChat Pay merchant credentials; set:")
    for name in missing {
      println("  \{name}")
    }
    println(
      "WXPAY_APPID / WXPAY_MCHID / WXPAY_SERIAL_NO / WXPAY_API_V3_KEY take the merchant",
    )
    println(
      "values from the WeChat Pay merchant console; WXPAY_PRIVATE_KEY is either the",
    )
    println(
      "API-certificate private key in PEM or a path to the PEM file. Optional:",
    )
    println("WXPAY_BASE_URL (default production), WXPAY_NOTIFY_URL.")
    println(
      "Optional public-key mode (公钥模式): WXPAY_PUBLIC_KEY is the console's",
    )
    println(
      "pub_key.pem (PEM text or file path) and WXPAY_PUBLIC_KEY_ID its serial,",
    )
    println("e.g. PUB_KEY_ID_25566888 — set both or neither.")
    println(
      "Note: variables must be exported (export WXPAY_...) — a shell variable",
    )
    println(
      "without `export` is invisible to the webdemo, and a sourced file must",
    )
    println("be re-sourced after editing.")
    return None
  }
  let (pub_pem, pub_id) = match pubkey {
    Some((pem, id)) => (pem, id)
    None => ("", "")
  }
  let config = @wechat.Config::new(
    appid=appid.unwrap(),
    mchid=mchid.unwrap(),
    serial_no=serial_no.unwrap(),
    private_key_pem=private_key_pem.unwrap(),
    api_v3_key=api_v3_key.unwrap(),
    base_url~,
    platform_public_key_pem=pub_pem,
    platform_public_key_id=pub_id,
  )
  let client = @wechat.Client::new(
    config~,
    transport=@transport.HttpClient::new(),
  ) catch {
    e => {
      println("wechat client construction failed: \{e}")
      return None
    }
  }
  println("appid      : \{appid.unwrap()}")
  println("mchid      : \{mchid.unwrap()}")
  println("base_url   : \{base_url}")
  println("notify_url : \{notify_url}")
  if pub_pem == "" {
    println("verify mode: platform certificates (/v3/certificates)")
  } else {
    println("verify mode: public-key mode (\{pub_id})")
  }
  Some((client, notify_url))
}

///|
/// Read the ALIPAY_* credentials the same way as the WeChat ones and build
/// the Alipay client. Returns None when the page stays disabled.
async fn load_alipay() -> (@alipay.Client, String)? {
  let missing : Array[String] = []
  let appid = require_env("ALIPAY_APPID", missing)
  let private_key_pem = load_pem_env("ALIPAY_PRIVATE_KEY", missing)
  let alipay_public_key_pem = load_pem_env("ALIPAY_PUBLIC_KEY", missing)
  let gateway_url = match @env.get_env_var("ALIPAY_GATEWAY_URL") {
    Some(url) => url
    None => "https://openapi.alipay.com/gateway.do"
  }
  let notify_url = match @env.get_env_var("ALIPAY_NOTIFY_URL") {
    Some(url) => url
    None => "https://example.com/moon-pay-sdk/alipay/notify"
  }
  if missing.length() > 0 ||
    appid is None ||
    private_key_pem is None ||
    alipay_public_key_pem is None {
    println("Alipay page disabled; to enable it set:")
    for name in missing {
      println("  \{name}")
    }
    println("ALIPAY_APPID is the open-platform web-application id (2021...),")
    println(
      "ALIPAY_PRIVATE_KEY the application private key in PEM (text or file path),",
    )
    println(
      "ALIPAY_PUBLIC_KEY the Alipay public key shown in the open-platform console",
    )
    println(
      "(公钥模式) — not your own application public key; PEM text or file path.",
    )
    println(
      "Optional: ALIPAY_GATEWAY_URL (default production), ALIPAY_NOTIFY_URL.",
    )
    println(
      "Note: variables must be exported (export ALIPAY_...) — a shell variable",
    )
    println(
      "without `export` is invisible to the webdemo, and a sourced file must",
    )
    println("be re-sourced after editing.")
    return None
  }
  let config = @alipay.Config::new(
    app_id=appid.unwrap(),
    private_key_pem=private_key_pem.unwrap(),
    alipay_public_key_pem=alipay_public_key_pem.unwrap(),
    gateway_url~,
  )
  let client = @alipay.Client::new(
    config~,
    transport=@transport.HttpClient::new(),
  ) catch {
    e => {
      println("alipay client construction failed: \{e}")
      return None
    }
  }
  println("alipay appid      : \{appid.unwrap()}")
  println("alipay gateway    : \{gateway_url}")
  println("alipay notify_url : \{notify_url}")
  Some((client, notify_url))
}

///|
/// Read a required variable; the missing list distinguishes an absent name
/// from one exported with an empty value, and both leave `None` behind.
fn require_env(name : String, missing : Array[String]) -> String? {
  match @env.get_env_var(name) {
    Some(value) =>
      if value == "" {
        missing.push("\{name} (set but empty)")
        None
      } else {
        Some(value)
      }
    None => {
      missing.push(name)
      None
    }
  }
}

///|
/// Read a PEM-valued variable: inline PEM text, or a path to a PEM file.
async fn load_pem_env(name : String, missing : Array[String]) -> String? {
  match @env.get_env_var(name) {
    Some(raw) =>
      if raw == "" {
        missing.push("\{name} (set but empty)")
        None
      } else if raw.has_prefix("-----BEGIN") {
        Some(raw)
      } else {
        match read_file_text(raw) {
          Some(pem) => Some(pem)
          None => {
            missing.push("\{name} (not a PEM and not a readable file: \{raw})")
            None
          }
        }
      }
    None => {
      missing.push(name)
      None
    }
  }
}

///|
/// Read a UTF-8 text file, returning None instead of aborting.
async fn read_file_text(path : String) -> String? {
  let data = try @fs.read_file(path) catch {
    _ => None
  } noraise {
    data => Some(data)
  }
  match data {
    Some(data) => {
      let text : String = try @utf8.decode(data.binary()[:]) catch {
        _ => ""
      } noraise {
        text => text
      }
      if text == "" {
        None
      } else {
        Some(text)
      }
    }
    None => None
  }
}

///|
/// Read a repository asset; the webdemo is useless without them, so abort.
async fn read_asset(path : String) -> String {
  match read_file_text(path) {
    Some(text) => text
    None =>
      abort(
        "cannot read asset \{path} — run the webdemo from the repository root",
      )
  }
}

///|
async fn route(
  app : App,
  index_html : String,
  alipay_html : String,
  qrcode_js : String,
  req : @http.Request,
  reader : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let path = req.path
  if req.meth is @http.Post && path == "/api/wechat/notify" {
    let body = reader.read_all().binary()
    handle_notify(app, req, body, conn)
    return
  }
  if req.meth is @http.Post && path == "/api/alipay/notify" {
    let body = reader.read_all().binary()
    handle_alipay_notify(app, body, conn)
    return
  }
  // Drain the body so keep-alive connections stay in sync.
  let _ = reader.read_all()
  if req.meth is @http.Get &&
    (path == "/" || path.has_prefix("/?") || path == "/index.html") {
    respond_text(conn, 200, "text/html; charset=utf-8", index_html)
  } else if req.meth is @http.Get &&
    (path == "/alipay" || path.has_prefix("/alipay?")) {
    respond_text(conn, 200, "text/html; charset=utf-8", alipay_html)
  } else if req.meth is @http.Get && path == "/assets/qrcode.js" {
    respond_text(conn, 200, "text/javascript; charset=utf-8", qrcode_js)
  } else if req.meth is @http.Get && path == "/api/config" {
    handle_config(app, conn)
  } else if req.meth is @http.Post &&
    (path == "/api/orders" || path.has_prefix("/api/orders?")) {
    handle_create_order(app, req, conn)
  } else if req.meth is @http.Post &&
    (
      path == "/api/wechat/jsapi/orders" ||
      path.has_prefix("/api/wechat/jsapi/orders?")
    ) {
    handle_create_jsapi_order(app, req, conn)
  } else if req.meth is @http.Get && path.has_prefix("/api/orders/") {
    handle_query(app, path, conn)
  } else if req.meth is @http.Post &&
    (path == "/api/alipay/orders" || path.has_prefix("/api/alipay/orders?")) {
    handle_create_alipay_order(app, req, conn)
  } else if req.meth is @http.Get && path.has_prefix("/api/alipay/orders/") {
    handle_alipay_query(app, path, conn)
  } else {
    respond_text(conn, 404, "text/plain; charset=utf-8", "not found\n")
  }
}

///|
/// GET /api/config — which gateway pages are enabled.
async fn handle_config(app : App, conn : @http.ServerConnection) -> Unit {
  respond_json(conn, 200, {
    "wechat": app.wechat is Some(_),
    "alipay": app.alipay is Some(_),
  })
}

///|
/// POST /api/orders?amount_yuan=0.01 — place a Native (QR) order and return
/// its code_url for the page to render.
async fn handle_create_order(
  app : App,
  req : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  let client = match app.wechat {
    Some(client) => client
    None => {
      respond_json(conn, 503, {
        "error": "WeChat Pay is not configured (set WXPAY_* and restart)",
      })
      return
    }
  }
  let yuan = match query_param(req.path, key="amount_yuan") {
    Some(yuan) => yuan
    None => "0.01"
  }
  let fen : Int = try @moon-pay-sdk.parse_yuan_fen(yuan) catch {
    _ => 0
  } noraise {
    fen => fen
  }
  if fen <= 0 {
    respond_json(conn, 400, { "error": "bad amount_yuan: \{yuan}" })
    return
  }
  let out_trade_no = next_out_trade_no(app)
  let order : @wechat.NativeOrder? = try
    client.native_order(
      out_trade_no~,
      total=fen,
      description="moon-pay-sdk integration test",
      notify_url=app.notify_url,
    )
  catch {
    e => {
      println("native_order failed: \{e}")
      None
    }
  } noraise {
    order => Some(order)
  }
  match order {
    Some(order) => {
      app.orders.set(out_trade_no, { amount_fen: fen, notify_seen: false, })
      println(
        "order \{out_trade_no} \{yuan} yuan, code_url \{order.code_url()}",
      )
      respond_json(conn, 200, {
        "out_trade_no": out_trade_no,
        "amount_fen": fen,
        "code_url": order.code_url(),
      })
    }
    None =>
      respond_json(conn, 502, {
        "error": "placing the order failed (see server log)",
      })
  }
}

///|
/// POST /api/wechat/jsapi/orders?amount_yuan=0.01&openid=o… — place a JSAPI
/// order for payment inside WeChat and return the signed wx.requestPayment
/// parameter set. The order is polled through /api/orders/<out_trade_no>
/// like a Native order.
async fn handle_create_jsapi_order(
  app : App,
  req : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  let client = match app.wechat {
    Some(client) => client
    None => {
      respond_json(conn, 503, {
        "error": "WeChat Pay is not configured (set WXPAY_* and restart)",
      })
      return
    }
  }
  let yuan = match query_param(req.path, key="amount_yuan") {
    Some(yuan) => yuan
    None => "0.01"
  }
  let fen : Int = try @moon-pay-sdk.parse_yuan_fen(yuan) catch {
    _ => 0
  } noraise {
    fen => fen
  }
  if fen <= 0 {
    respond_json(conn, 400, { "error": "bad amount_yuan: \{yuan}" })
    return
  }
  let openid = match query_param(req.path, key="openid") {
    Some(openid) if openid != "" => openid
    _ => {
      respond_json(conn, 400, {
        "error": "openid is required (the payer's openid under this appid)",
      })
      return
    }
  }
  let out_trade_no = next_out_trade_no(app)
  let order : @wechat.JsapiOrder? = try
    client.jsapi_order(
      out_trade_no~,
      total=fen,
      description="moon-pay-sdk integration test",
      notify_url=app.notify_url,
      openid~,
    )
  catch {
    e => {
      println("jsapi_order failed: \{e}")
      None
    }
  } noraise {
    order => Some(order)
  }
  match order {
    Some(order) => {
      let params = client.jsapi_pay_params(prepay_id=order.prepay_id()) catch {
        e => {
          println("jsapi_pay_params failed: \{e}")
          respond_json(conn, 502, {
            "error": "signing the pay params failed (see server log)",
          })
          return
        }
      }
      app.orders.set(out_trade_no, { amount_fen: fen, notify_seen: false, })
      println(
        "jsapi order \{out_trade_no} \{yuan} yuan, prepay_id \{order.prepay_id()}",
      )
      respond_json(conn, 200, {
        "out_trade_no": out_trade_no,
        "amount_fen": fen,
        "prepay_id": order.prepay_id(),
        "pay_params": {
          "appId": params.app_id(),
          "timeStamp": params.timestamp(),
          "nonceStr": params.nonce_str(),
          "package": params.pay_package(),
          "signType": params.sign_type(),
          "paySign": params.pay_sign(),
        },
      })
    }
    None =>
      respond_json(conn, 502, {
        "error": "placing the order failed (see server log)",
      })
  }
}

///|
/// GET /api/orders/<out_trade_no> — query WeChat Pay for the live trade
/// state so the page can poll without a publicly reachable notify URL.
async fn handle_query(
  app : App,
  path : String,
  conn : @http.ServerConnection,
) -> Unit {
  let client = match app.wechat {
    Some(client) => client
    None => {
      respond_json(conn, 503, {
        "error": "WeChat Pay is not configured (set WXPAY_* and restart)",
      })
      return
    }
  }
  let out_trade_no = path["/api/orders/".length():].to_owned()
  let rec = match app.orders.get(out_trade_no) {
    Some(rec) => rec
    None => {
      respond_json(conn, 404, { "error": "unknown out_trade_no" })
      return
    }
  }
  let status : @wechat.OrderStatus? = try
    client.query_order(out_trade_no~)
  catch {
    e => {
      println("query_order failed: \{e}")
      None
    }
  } noraise {
    status => Some(status)
  }
  let status = match status {
    Some(status) => status
    None => {
      respond_json(conn, 502, { "error": "query failed (see server log)" })
      return
    }
  }
  let success_time = match status.success_time() {
    Some(time) => time
    None => ""
  }
  let body : Json = {
    "out_trade_no": status.out_trade_no(),
    "trade_state": trade_state_wire(status.trade_state()),
    "total_fen": status.total_fen(),
    "success_time": success_time,
    "notify_seen": rec.notify_seen,
  }
  respond_json(conn, 200, body)
}

///|
/// POST /api/wechat/notify — WeChat Pay's signed callback. Verify, decrypt,
/// remember, and acknowledge so the gateway stops retrying.
async fn handle_notify(
  app : App,
  req : @http.Request,
  body : Bytes,
  conn : @http.ServerConnection,
) -> Unit {
  let client = match app.wechat {
    Some(client) => client
    None => {
      let (status, ack) = @wechat.ack_failure(message="wechat not configured")
      respond_json_raw(conn, status, ack)
      return
    }
  }
  let headers : Array[(String, String)] = []
  for key, value in req.headers {
    headers.push((key.to_string(), value))
  }
  let notification : @wechat.Notification? = try
    client.verify_callback(headers, body)
  catch {
    e => {
      println("notify rejected: \{e}")
      let (status, ack) = @wechat.ack_failure(
        message="verification failed: \{e}",
      )
      respond_json_raw(conn, status, ack)
      None
    }
  } noraise {
    notification => Some(notification)
  }
  match notification {
    Some(notification) => {
      let out_trade_no = notification.out_trade_no()
      match app.orders.get(out_trade_no) {
        Some(rec) => {
          rec.notify_seen = true
          if notification.total_fen() != rec.amount_fen {
            println(
              "notify amount mismatch for \{out_trade_no}: \{notification.total_fen()} fen, expected \{rec.amount_fen}",
            )
          }
        }
        None => println("notify for unknown order \{out_trade_no}")
      }
      println(
        "notify verified: \{out_trade_no} \{notification.event_type()} \{trade_state_wire(notification.trade_state())}",
      )
      let (status, ack) = @wechat.ack_success()
      respond_json_raw(conn, status, ack)
    }
    None => ()
  }
}

///|
/// POST /api/alipay/orders?amount_yuan=0.01 — build the signed redirect URL
/// for a page-pay order (alipay.trade.page.pay).
async fn handle_create_alipay_order(
  app : App,
  req : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  let client = match app.alipay {
    Some(client) => client
    None => {
      respond_json(conn, 503, {
        "error": "Alipay is not configured (set ALIPAY_* and restart)",
      })
      return
    }
  }
  let yuan = match query_param(req.path, key="amount_yuan") {
    Some(yuan) => yuan
    None => "0.01"
  }
  let fen : Int = try @moon-pay-sdk.parse_yuan_fen(yuan) catch {
    _ => 0
  } noraise {
    fen => fen
  }
  if fen <= 0 {
    respond_json(conn, 400, { "error": "bad amount_yuan: \{yuan}" })
    return
  }
  let out_trade_no = next_out_trade_no(app)
  let return_url = "http://\{request_host(req)}/alipay?alipay_order=\{out_trade_no}"
  let pay_url : String? = try
    client.page_pay_url(
      out_trade_no~,
      total_fen=fen,
      subject="moon-pay-sdk integration test",
      notify_url=app.alipay_notify_url,
      return_url~,
    )
  catch {
    e => {
      println("page_pay_url failed: \{e}")
      None
    }
  } noraise {
    url => Some(url)
  }
  match pay_url {
    Some(url) => {
      app.orders.set(out_trade_no, { amount_fen: fen, notify_seen: false, })
      println(
        "alipay order \{out_trade_no} \{yuan} yuan, return_url \{return_url}",
      )
      respond_json(conn, 200, {
        "out_trade_no": out_trade_no,
        "amount_fen": fen,
        "pay_url": url,
      })
    }
    None =>
      respond_json(conn, 502, {
        "error": "building the pay URL failed (see server log)",
      })
  }
}

///|
/// GET /api/alipay/orders/<out_trade_no> — query Alipay for the live trade
/// state so the page can poll without a publicly reachable notify URL.
async fn handle_alipay_query(
  app : App,
  path : String,
  conn : @http.ServerConnection,
) -> Unit {
  let client = match app.alipay {
    Some(client) => client
    None => {
      respond_json(conn, 503, {
        "error": "Alipay is not configured (set ALIPAY_* and restart)",
      })
      return
    }
  }
  let out_trade_no = path["/api/alipay/orders/".length():].to_owned()
  let rec = match app.orders.get(out_trade_no) {
    Some(rec) => rec
    None => {
      respond_json(conn, 404, { "error": "unknown out_trade_no" })
      return
    }
  }
  let status : @alipay.OrderStatus? = try
    client.query_order(out_trade_no~)
  catch {
    e => {
      println("alipay query_order failed: \{e}")
      None
    }
  } noraise {
    status => Some(status)
  }
  let status = match status {
    Some(status) => status
    None => {
      respond_json(conn, 502, { "error": "query failed (see server log)" })
      return
    }
  }
  let send_pay_date = match status.send_pay_date() {
    Some(date) => date
    None => ""
  }
  let body : Json = {
    "out_trade_no": status.out_trade_no(),
    "trade_status": trade_status_wire(status.trade_status()),
    "total_fen": status.total_fen(),
    "send_pay_date": send_pay_date,
    "notify_seen": rec.notify_seen,
  }
  respond_json(conn, 200, body)
}

///|
/// POST /api/alipay/notify — Alipay's signed async notification. Verify the
/// RSA2 signature and app_id, remember, and answer "success" so Alipay stops
/// retrying.
async fn handle_alipay_notify(
  app : App,
  body : Bytes,
  conn : @http.ServerConnection,
) -> Unit {
  let client = match app.alipay {
    Some(client) => client
    None => {
      respond_text(conn, 200, "text/plain; charset=utf-8", "failure\n")
      return
    }
  }
  let text = @utf8.decode_lossy(body[:])
  let form = @alipay.parse_form_params(text)
  let notify : @alipay.NotifyResult? = try client.verify_notify(form) catch {
    e => {
      println("alipay notify rejected: \{e}")
      None
    }
  } noraise {
    notify => Some(notify)
  }
  match notify {
    Some(notify) => {
      let out_trade_no = notify.out_trade_no()
      match app.orders.get(out_trade_no) {
        Some(rec) => {
          rec.notify_seen = true
          if !notify.amount_matches(rec.amount_fen) {
            println(
              "alipay notify amount mismatch for \{out_trade_no}: \{notify.total_amount()}, expected \{rec.amount_fen} fen",
            )
          }
        }
        None => println("alipay notify for unknown order \{out_trade_no}")
      }
      println(
        "alipay notify verified: \{out_trade_no} \{trade_status_wire(notify.trade_status())}",
      )
      respond_text(
        conn,
        200,
        "text/plain; charset=utf-8",
        @alipay.ack_success(),
      )
    }
    None => respond_text(conn, 200, "text/plain; charset=utf-8", "failure\n")
  }
}

///|
/// The Host header the browser used, so the Alipay return URL lands back on
/// the same origin; falls back to the local listener.
fn request_host(req : @http.Request) -> String {
  for key, value in req.headers {
    let name = key.to_string()
    if name == "Host" || name == "host" {
      return value
    }
  }
  "127.0.0.1:\{LISTEN_PORT}"
}

///|
fn next_out_trade_no(app : App) -> String {
  app.seq = app.seq + 1
  "IT\{@async.now()}\{pad(app.seq, 4)}"
}

///|
fn pad(n : Int, width : Int) -> String {
  let s = n.to_string()
  let mut zeros = ""
  let mut left = width - s.length()
  while left > 0 {
    zeros = zeros + "0"
    left = left - 1
  }
  zeros + s
}

///|
/// Map a TradeState back to the wire string the gateway uses.
fn trade_state_wire(state : @wechat.TradeState) -> String {
  match state {
    @wechat.Success => "SUCCESS"
    @wechat.Refund => "REFUND"
    @wechat.NotPay => "NOTPAY"
    @wechat.Closed => "CLOSED"
    @wechat.Revoked => "REVOKED"
    @wechat.UserPaying => "USERPAYING"
    @wechat.PayError => "PAYERROR"
    @wechat.Unknown(s) => s
  }
}

///|
/// Map a TradeStatus back to the wire string the gateway uses.
fn trade_status_wire(status : @alipay.TradeStatus) -> String {
  match status {
    WaitBuyerPay => "WAIT_BUYER_PAY"
    TradeClosed => "TRADE_CLOSED"
    TradeSuccess => "TRADE_SUCCESS"
    TradeFinished => "TRADE_FINISHED"
    Unknown(s) => s
  }
}

///|
fn query_param(path : String, key~ : String) -> String? {
  let start = match path.find("?") {
    Some(i) => i
    None => return None
  }
  let mut rest = path[start + 1:].to_owned()
  while rest != "" {
    let piece = match rest.find("&") {
      Some(i) => {
        let head = rest[:i].to_owned()
        rest = rest[i + 1:].to_owned()
        head
      }
      None => {
        let head = rest
        rest = ""
        head
      }
    }
    let prefix = "\{key}="
    if piece.has_prefix(prefix) {
      return Some(piece[prefix.length():].to_owned())
    }
  }
  None
}

///|
async fn respond_json(
  conn : @http.ServerConnection,
  status : Int,
  body : Json,
) -> Unit {
  respond_text(
    conn,
    status,
    "application/json; charset=utf-8",
    @moon-pay-sdk.encode_json(body),
  )
}

///|
async fn respond_json_raw(
  conn : @http.ServerConnection,
  status : Int,
  body : String,
) -> Unit {
  respond_text(conn, status, "application/json; charset=utf-8", body)
}

///|
async fn respond_text(
  conn : @http.ServerConnection,
  status : Int,
  content_type : String,
  body : String,
) -> Unit {
  conn
  ..send_response(status, "OK", extra_headers={ "Content-Type": content_type })
  ..write_string(body)
  .end_response()
}
