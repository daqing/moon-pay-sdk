///|
/// Automation of WeChat DevTools over the `miniprogram-automator` wire
/// protocol. This speaks the same WebSocket JSON as the official npm
/// package: requests are `{id, method, params}`, answers are
/// `{id, result}` or `{id, error: {message}}`; unsolicited events carry a
/// `method` but no `id`.
///
/// Calls are strictly one-in-flight: `send` writes a request, then drains
/// frames until the answer with the matching id shows up, dropping any
/// events along the way. That mirrors how this SDK uses the protocol
/// (probe, then one `wx.login`) and keeps the plumbing synchronous.
pub struct Automator {
  ws : @websocket.Conn
  mut seq : Int32
}

///|
/// The single error kind of the automation layer.
pub suberror Automation {
  /// The DevTools cli could not start or the project window never opened.
  Launch(String)
  /// The WebSocket handshake or a request write failed.
  Connect(String)
  /// DevTools answered with a protocol error or an unusable payload.
  Protocol(String)
  /// The automation endpoint never came up, or a call never answered.
  Timeout(String)
}

///|
pub impl Show for Automation with fn output(self : Automation, logger : &Logger) -> Unit {
  match self {
    Launch(detail) => logger.write_string("devtools launch: \{detail}")
    Connect(detail) => logger.write_string("connect: \{detail}")
    Protocol(detail) => logger.write_string("protocol: \{detail}")
    Timeout(detail) => logger.write_string("timeout: \{detail}")
  }
}

///|
/// `{}` — the params every request without extras carries.
fn empty_params() -> Json {
  Json::empty_object()
}

///|
/// Connect to a DevTools automation endpoint (`ws://127.0.0.1:9420`).
pub async fn Automator::connect(endpoint : String) -> Automator {
  let ws = @websocket.Conn::connect(endpoint)
  { ws, seq: 0, }
}

///|
/// Send one protocol request and await its answer. Frames that carry no
/// matching id (server-pushed events) are skipped.
pub async fn Automator::send(
  self : Automator,
  api~ : String,
  params~ : Json = empty_params(),
) -> Json {
  self.seq += 1
  let id = "\{self.seq}"
  let request : Json = { "id": id, "method": api, "params": params }
  self.ws.send_text(request.stringify()) catch {
    e => raise Connect("sending \{api} failed: \{e}")
  }
  // DevTools can take a while on a cold launch; be patient per call.
  for ;; {
    let frame = @async.with_timeout_opt(120_000, () => self.ws.recv())
    let frame = match frame {
      Some(frame) => frame
      None =>
        raise Timeout(
          "\{api}: no answer after 120s — is the DevTools project window open?",
        )
    }
    let text = @utf8.decode_lossy(frame.read_all().binary()[:])
    let json = match @moon-pay-sdk.try_parse_json(text) {
      Some(json) => json
      None => continue
    }
    let fields = match json {
      Object(fields) => fields
      _ => continue
    }
    let frame_id = match fields.get("id") {
      Some(String(frame_id)) => frame_id
      _ => continue
    }
    if frame_id != id {
      continue
    }
    match fields.get("error") {
      Some(error) => {
        let detail = match error {
          String(text) => text
          Object(_) =>
            @moon-pay-sdk.string_field(error, "message") catch {
              _ => @moon-pay-sdk.encode_json(error)
            }
          _ => @moon-pay-sdk.encode_json(error)
        }
        raise Protocol("\{api}: \{detail}")
      }
      None =>
        return match fields.get("result") {
          Some(result) => result
          None => empty_params()
        }
    }
  }
}

///|
/// `Tool.getInfo` — base info about the connected DevTools session; used
/// as a liveness probe before the real call.
pub async fn Automator::get_info(self : Automator) -> Json {
  self.send(api="Tool.getInfo")
}

///|
/// `App.callWxMethod` — invoke one `wx.*` API inside the running
/// mini program and return the method's own result object.
pub async fn Automator::call_wx_method(self : Automator, api : String) -> Json {
  let params : Json = { "method": api, "args": [] }
  let answer = self.send(api="App.callWxMethod", params~)
  match answer {
    Object(fields) =>
      match fields.get("result") {
        Some(result) => result
        None => answer
      }
    _ => answer
  }
}

///|
/// Close the socket; DevTools and its project window stay open.
pub async fn Automator::close(self : Automator) -> Unit {
  self.ws.send_close() catch {
    _ => ()
  }
  self.ws.close()
}

///|
/// Read `res.code` out of a wx.login result.
pub fn login_code_from(result : Json) -> String raise {
  @moon-pay-sdk.string_field(result, "code") catch {
    _ =>
      raise Protocol(
        "wx.login returned no code: \{@moon-pay-sdk.encode_json(result)}",
      )
  }
}

///|
/// Launch DevTools itself: `<cli> auto --project <path> --auto-port <port>
/// [--trust-project]` — the exact argv miniprogram-automator's launcher
/// sends. The cli output streams through with a `[devtools cli]` prefix;
/// the call returns once the automation port answers a WebSocket probe.
pub async fn launch_devtools(
  cli_path~ : String,
  project_path~ : String,
  port~ : Int32,
  trust_project~ : Bool = true,
) -> Unit {
  let args = ["auto", "--project", project_path, "--auto-port", "\{port}"]
  if trust_project {
    args.push("--trust-project")
  }
  let (stdout_reader, child_stdout) = @process.read_from_process(shared=true)
  let (stderr_reader, child_stderr) = @process.read_from_process(shared=true)
  let _ = @async.with_task_group(group => {
    group.spawn_bg(
      () => pipe_to_prefix(stdout_reader),
      no_wait=true,
      allow_failure=true,
    )
    group.spawn_bg(
      () => pipe_to_prefix(stderr_reader),
      no_wait=true,
      allow_failure=true,
    )
    // Fire and forget: the cli hands the request to the IDE and exits fast;
    // the IDE then opens the project window and the automation port.
    try
      @process.spawn_orphan(
        cli_path,
        args[:],
        stdout=child_stdout,
        stderr=child_stderr,
      )
    catch {
      e => raise Launch("failed to start \{cli_path}: \{e}")
    } noraise {
      _ => ()
    }
    0
  })
  println("launching: \{cli_path} \{args.join(" ")}")
  let endpoint = "ws://127.0.0.1:\{port}"
  for i in 0..<60 {
    let probe = @async.with_timeout_opt(2_000, () => {
      try {
        let ws = @websocket.Conn::connect(endpoint)
        ws.close()
        true
      } catch {
        _ => false
      } noraise {
        ok => ok
      }
    })
    match probe {
      Some(true) => {
        println("automation port \{port} is up")
        return
      }
      _ => ()
    }
    if i % 4 == 3 {
      println("waiting for DevTools automation port \{port} ... (\{i + 1})")
    }
    @async.sleep(500)
  }
  raise Timeout(
    "DevTools automation port \{port} never opened within 30s — ensure the IDE is logged in, the service port is enabled in its security settings, and the project path is correct",
  )
}

///|
/// Stream one child output pipe to the terminal, line by line. Started
/// detached, so it is cancelled with its task group — the child's pipes
/// close with the process either way.
async fn pipe_to_prefix(reader : @process.ReadFromProcess) -> Unit {
  defer reader.close()
  for ;; {
    let line = reader.read_until("\n")
    match line {
      Some(line) =>
        match line.trim().to_owned() {
          "" => ()
          text => println("[devtools cli] \{text}")
        }
      None => break
    }
  }
  // Flush an unterminated tail line the line reader could not deliver.
  let tail = reader.read_all()
  let text = @utf8.decode_lossy(tail.binary()[:])
  match text.trim().to_owned() {
    "" => ()
    text => println("[devtools cli] \{text}")
  }
}

///|
/// One-shot automation: connect, probe, call `wx.login`, return
/// `res.code`. The whole flow is bounded by a 120s timeout.
pub async fn fetch_login_code(endpoint~ : String) -> String {
  @async.with_timeout(
    120_000,
    () => {
      let automator = Automator::connect(endpoint)
      defer automator.close()
      let _ = automator.get_info()
      let result = automator.call_wx_method("login")
      login_code_from(result)
    },
    error=Timeout("wx.login via DevTools timed out after 120s"),
  )
}
