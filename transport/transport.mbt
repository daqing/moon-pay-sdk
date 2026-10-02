///|
/// The HTTP methods the payment providers need.
pub(all) enum Method {
  Get
  Post
}

///|
/// A payment-provider HTTP request.
pub(all) struct Request {
  meth : Method
  url : String
  headers : Array[(String, String)]
  body : Bytes
}

///|
/// A payment-provider HTTP response.
pub(all) struct Response {
  status : Int
  headers : Array[(String, String)]
  body : Bytes
}

///|
/// Why a transport round trip failed.
pub(all) suberror TransportError {
  /// The request never reached the peer: DNS, connect, or socket failure.
  Network(String)
  /// The peer answered with something that is not usable HTTP.
  Protocol(String)
}

///|
pub impl Show for TransportError with fn output(
  self : TransportError,
  logger : &Logger,
) -> Unit {
  match self {
    Network(detail) => logger.write_string("network: \{detail}")
    Protocol(detail) => logger.write_string("protocol: \{detail}")
  }
}

///|
pub extend TransportError with Show::{output, to_string}

///|
/// The HTTP boundary of the SDK. Clients depend on this interface, never on
/// concrete HTTP calls, so every client behaviour is testable offline against
/// a mock.
pub(open) trait Transport {
  async fn send(Self, Request) -> Response raise TransportError
}
