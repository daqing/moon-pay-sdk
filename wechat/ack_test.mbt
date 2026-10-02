///|
test "ack bodies are stable" {
  let (ok_status, ok_body) = @wechat.ack_success()
  inspect(ok_status, content="200")
  inspect(ok_body, content=(
    #|{"code":"SUCCESS","message":"成功"}
  ))
  let (fail_status, fail_body) = @wechat.ack_failure(message="order locked")
  inspect(fail_status, content="500")
  inspect(fail_body, content=(
    #|{"code":"FAIL","message":"order locked"}
  ))
}

///|
test "failure acks escape quotes in the message" {
  let (_, body) = @wechat.ack_failure(message="say \"hi\"")
  assert_eq(body, "{\"code\":\"FAIL\",\"message\":\"say \\\"hi\\\"\"}")
}
