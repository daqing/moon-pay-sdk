///|
async test "fetch_login_code drives the automator protocol end to end" {
  let server = @http.Server(
    @socket.Addr::parse("127.0.0.1:19421"),
    reuse_addr=true,
  )
  @async.with_task_group(group => {
    group.spawn_bg(
      () => serve_mock_devtools(server),
      no_wait=true,
      allow_failure=true,
    )
    // Connect eagerly inside the group: the moment the endpoint answers,
    // fetch a code, verify it, and shut the endpoint down.
    let code = try fetch_when_ready(server) catch {
      e => {
        server.close()
        abort("fetch_login_code failed against the mock: \{e}")
      }
    } noraise {
      code => {
        server.close()
        code
      }
    }
    assert_eq(code, "081Ab2CdTESTCODE")
  })
}

///|
/// Poll the endpoint briefly, then run the full login fetch against it.
async fn fetch_when_ready(server : @http.Server) -> String {
  let endpoint = "ws://127.0.0.1:19421"
  for i in 0..<50 {
    let up = try {
      let probe = @websocket.Conn::connect(endpoint)
      probe.close()
      true
    } catch {
      _ => {
        @async.sleep(100)
        false
      }
    } noraise {
      ok => ok
    }
    if up {
      return @wxlogin.fetch_login_code(endpoint~)
    }
    let _ = i
  }
  server.close()
  abort("mock devtools endpoint never came up")
}

///|
/// A stand-in for the DevTools automation endpoint: accepts the WebSocket
/// upgrade and answers `Tool.getInfo` / `App.callWxMethod` with the same
/// shapes real DevTools sends.
async fn serve_mock_devtools(server : @http.Server) -> Unit {
  server.run_forever((request, _body, conn) => {
    let ws = @websocket.from_http_server(request, conn)
    defer ws.close()
    for ;; {
      let message = ws.recv()
      let text = @utf8.decode_lossy(message.read_all().binary()[:])
      let json = match @moon-pay-sdk.try_parse_json(text) {
        Some(json) => json
        None => continue
      }
      let fields = match json {
        Object(fields) => fields
        _ => continue
      }
      let id = match fields.get("id") {
        Some(String(id)) => id
        _ => continue
      }
      let api = match fields.get("method") {
        Some(String(api)) => api
        _ => continue
      }
      let result : Json = if api == "Tool.getInfo" {
        { "SDKVersion": "3.14.0" }
      } else if api == "App.callWxMethod" {
        { "code": "081Ab2CdTESTCODE", "errMsg": "login:ok" }
      } else {
        Json::empty_object()
      }
      let response : Json = { "id": id, "result": result }
      ws.send_text(response.stringify())
    }
  })
}
