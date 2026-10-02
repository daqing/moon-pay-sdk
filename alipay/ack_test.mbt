///|
test "the ack body is exactly success" {
  inspect(
    @alipay.ack_success(),
    content=(
      #|success
    ),
  )
}
