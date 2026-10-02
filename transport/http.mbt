///|
/// Transport over moonbitlang/async HTTP(S) — the implementation the real
/// clients use. Payment gateways are HTTPS-only, but the loopback tests
/// exercise the same code path over plain HTTP.
pub struct HttpClient {}

///|
pub fn HttpClient::new() -> HttpClient {
  HttpClient::{ }
}

///|
fn to_header_map(headers : Array[(String, String)]) -> @http.Headers {
  let map : @http.Headers = Map([])
  for pair in headers {
    map.set(@http.CaseInsensitiveString(pair.0), pair.1)
  }
  map
}

///|
fn from_header_map(headers : @http.Headers) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  for key, value in headers {
    pairs.push((key.to_string(), value))
  }
  pairs
}

///|
fn method_of(meth : Method) -> @http.RequestMethod {
  match meth {
    Get => @http.Get
    Post => @http.Post
  }
}

///|
pub impl Transport for HttpClient with fn send(
  _self : HttpClient,
  request : Request,
) -> Response raise TransportError {
  let (response, body) = @http.request(
    request.url,
    method_of(request.meth),
    to_header_map(request.headers),
    request.body,
  ) catch {
    e => raise Network("\{e}")
  }
  {
    status: response.code,
    headers: from_header_map(response.headers),
    body: body.binary(),
  }
}

///|
pub extend HttpClient with Transport::{send}
