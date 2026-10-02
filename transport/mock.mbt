///|
/// A scriptable transport for offline tests: every request is recorded, and
/// responses are popped from the script in order.
pub(all) struct MockTransport {
  responses : Array[Response]
  requests : Array[Request]
}

///|
pub fn MockTransport::new(responses : Array[Response]) -> MockTransport {
  { responses, requests: [], }
}

///|
/// The requests this mock has served, oldest first.
pub fn MockTransport::recorded(self : MockTransport) -> Array[Request] {
  self.requests
}

///|
pub fn MockTransport::unused_responses(self : MockTransport) -> Int {
  self.responses.length()
}

///|
pub impl Transport for MockTransport with fn send(
  self : MockTransport,
  request : Request,
) -> Response raise TransportError {
  self.requests.push(request)
  match self.responses.pop() {
    Some(response) => response
    None => raise Protocol("no scripted response left for \{request.url}")
  }
}

///|
pub extend MockTransport with Transport::{send}
