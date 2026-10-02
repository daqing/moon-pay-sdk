///|
/// A structured error reported by a payment provider: WeChat v3 answers with
/// a JSON body carrying `code` and `message`, Alipay with an error code in
/// the response form.
pub(all) struct ApiError {
  code : String
  message : String
  http_status : Int?
}

///|
pub fn ApiError::new(
  code~ : String,
  message~ : String,
  http_status? : Int? = None,
) -> ApiError {
  { code, message, http_status, }
}

///|
/// The one error type every public SDK function raises. Provider rejections
/// keep their structured code; everything else names its layer.
pub(all) suberror SdkError {
  /// The provider answered and refused the request.
  Api(ApiError)
  /// The request never got a usable answer from the network.
  Network(String)
  /// Signing, verification or decryption failed.
  Crypto(@crypto.CryptoError)
  /// Configuration or call arguments are invalid.
  Config(String)
}

///|
pub impl Show for SdkError with fn output(self : SdkError, logger : &Logger) -> Unit {
  match self {
    Api(api) =>
      match api.http_status {
        Some(status) =>
          logger.write_string(
            "api error \{api.code} (http \{status}): \{api.message}",
          )
        None => logger.write_string("api error \{api.code}: \{api.message}")
      }
    Network(detail) => logger.write_string("network error: \{detail}")
    Crypto(detail) => logger.write_string("crypto error: \{detail}")
    Config(detail) => logger.write_string("config error: \{detail}")
  }
}

///|
pub extend SdkError with Show::{output, to_string}
