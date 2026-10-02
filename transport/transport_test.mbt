///|
fn loopback_addr() -> @socket.Addr {
  // 2130706433 = 127.0.0.1 in network byte order; port 0 = ephemeral.
  @socket.Addr::parse("127.0.0.1:0") catch {
    _ => @socket.Addr::new(2130706433U, 0)
  }
}

///|
async test "http transport round-trips against a local server" {
  @async.with_task_group <| group => {
    let server = @http.Server::Server(loopback_addr())
    let port = server.addr.port()
    group.spawn_bg(no_wait=true, () => {
      server.run_forever(
        async fn(req, reader, conn) {
          let _ = reader.read_all()
          let echoed = match
            req.headers.get(@http.CaseInsensitiveString("x-test")) {
            Some(value) => value
            None => "none"
          }
          conn.send_response(200, "OK")
          conn <+ "echo:\{echoed}"
          conn.end_response()
        },
        allow_failure=true,
      )
    })
    let client : &@transport.Transport = @transport.HttpClient::new()
    let response = client.send({
      meth: Post,
      url: "http://127.0.0.1:\{port}/v3/pay/transactions/native",
      headers: [("X-Test", "yes")],
      body: b"ping",
    })
    server.close()
    assert_eq(response.status, 200)
    assert_eq(response.body, b"echo:yes")
  }
}

///|
async test "mock transport records requests and scripts responses" {
  let mock = @transport.MockTransport::new([
    {
      status: 200,
      headers: [("Content-Type", "application/json")],
      body: b"{}",
    },
  ])
  let transport : &@transport.Transport = mock
  let response = transport.send({
    meth: Get,
    url: "https://api.mch.weixin.qq.com/v3/certificates",
    headers: [],
    body: b"",
  })
  assert_eq(response.status, 200)
  assert_eq(mock.recorded().length(), 1)
  assert_eq(
    mock.recorded()[0].url,
    "https://api.mch.weixin.qq.com/v3/certificates",
  )
  assert_eq(mock.unused_responses(), 0)
  let verdict : String = try
    transport.send({
      meth: Get,
      url: "https://api.mch.weixin.qq.com/v3/certificates",
      headers: [],
      body: b"",
    })
  catch {
    @transport.Protocol(_) => "script exhausted"
    _ => "other error"
  } noraise {
    _ => "no error raised"
  }
  assert_eq(verdict, "script exhausted")
}
