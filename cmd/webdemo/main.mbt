///|
/// A minimal web app for manually integration-testing moon-pay-sdk's WeChat
/// Pay Native (QR) checkout against the real gateway. It serves one page that
/// creates an order, renders the returned `code_url` as a QR code and polls
/// until WeChat Pay reports the order paid. Credentials come from WXPAY_*
/// environment variables so none of them live in this repository.
///
/// Run from the repository root:
///
///     moon run cmd/webdemo
///
/// then open <http://127.0.0.1:1943> and scan the QR code with WeChat.

///|
/// One order this app has placed, keyed by out_trade_no.
priv struct OrderRec {
  amount_fen : Int
  mut notify_seen : Bool
}

///|
priv struct App {
  client : @wechat.Client
  notify_url : String
  orders : Map[String, OrderRec]
  mut seq : Int
}

///|
const LISTEN_PORT : Int = 1943

///|
async fn main {
  let app = match load_app() {
    Some(app) => app
    None => return
  }
  let index_html = read_asset("cmd/webdemo/assets/index.html")
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
      route(app, index_html, qrcode_js, req, reader, conn)
    },
    allow_failure=true,
  ) catch {
    e => println("server stopped: \{e}")
  }
}

///|
/// Read credentials from the environment, print what is missing, and build
/// the WeChat Pay client. Returns None when the app cannot start.
async fn load_app() -> App? {
  let missing : Array[String] = []
  let appid = require_env("WXPAY_APPID", missing)
  let mchid = require_env("WXPAY_MCHID", missing)
  let serial_no = require_env("WXPAY_SERIAL_NO", missing)
  let api_v3_key = require_env("WXPAY_API_V3_KEY", missing)
  let private_key_pem = match @env.get_env_var("WXPAY_PRIVATE_KEY") {
    Some(raw) =>
      if raw == "" {
        missing.push("WXPAY_PRIVATE_KEY (set but empty)")
        None
      } else if raw.has_prefix("-----BEGIN") {
        Some(raw)
      } else {
        match read_file_text(raw) {
          Some(pem) => Some(pem)
          None => {
            missing.push(
              "WXPAY_PRIVATE_KEY (not a PEM and not a readable file: \{raw})",
            )
            None
          }
        }
      }
    None => {
      missing.push("WXPAY_PRIVATE_KEY")
      None
    }
  }
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
  Some({ client, notify_url, orders: Map([]), seq: 0, })
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
  // Drain the body so keep-alive connections stay in sync.
  let _ = reader.read_all()
  if req.meth is @http.Get && (path == "/" || path == "/index.html") {
    respond_text(conn, 200, "text/html; charset=utf-8", index_html)
  } else if req.meth is @http.Get && path == "/assets/qrcode.js" {
    respond_text(conn, 200, "text/javascript; charset=utf-8", qrcode_js)
  } else if req.meth is @http.Post &&
    (path == "/api/orders" || path.has_prefix("/api/orders?")) {
    handle_create_order(app, req, conn)
  } else if req.meth is @http.Get && path.has_prefix("/api/orders/") {
    handle_query(app, path, conn)
  } else {
    respond_text(conn, 404, "text/plain; charset=utf-8", "not found\n")
  }
}

///|
/// POST /api/orders?amount_yuan=0.01 — place a Native (QR) order and return
/// its code_url for the page to render.
async fn handle_create_order(
  app : App,
  req : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
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
    app.client.native_order(
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
/// GET /api/orders/<out_trade_no> — query WeChat Pay for the live trade
/// state so the page can poll without a publicly reachable notify URL.
async fn handle_query(
  app : App,
  path : String,
  conn : @http.ServerConnection,
) -> Unit {
  let out_trade_no = path["/api/orders/".length():].to_owned()
  let rec = match app.orders.get(out_trade_no) {
    Some(rec) => rec
    None => {
      respond_json(conn, 404, { "error": "unknown out_trade_no" })
      return
    }
  }
  let status : @wechat.OrderStatus? = try
    app.client.query_order(out_trade_no~)
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
  let headers : Array[(String, String)] = []
  for key, value in req.headers {
    headers.push((key.to_string(), value))
  }
  let notification : @wechat.Notification? = try
    app.client.verify_callback(headers, body)
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
