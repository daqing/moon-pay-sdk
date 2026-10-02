///|
/// Why JSON could not be read the way the caller expected. Field access
/// errors name the field; parse errors carry the underlying position detail.
pub(all) suberror JsonError {
  /// The text is not valid JSON.
  Invalid(String)
  /// The object does not contain the field.
  Missing(String)
  /// The field exists but is not the requested type.
  WrongType(String, String)
}

///|
pub impl Show for JsonError with fn output(self : JsonError, logger : &Logger) -> Unit {
  match self {
    Invalid(detail) => logger.write_string("invalid json: \{detail}")
    Missing(key) => logger.write_string("field \"\{key}\" is missing")
    WrongType(key, expected) =>
      logger.write_string("field \"\{key}\" is not \{expected}")
  }
}

///|
pub extend JsonError with Show::{output, to_string}

///|
/// Parse JSON text, with the parse failure re-wrapped as `JsonError::Invalid`.
pub fn parse_json(text : StringView) -> Json raise JsonError {
  @json.parse(text) catch {
    e => raise Invalid("\{e}")
  }
}

///|
/// Parse JSON text, returning `None` instead of raising on malformed input.
pub fn try_parse_json(text : StringView) -> Json? {
  try @json.parse(text) catch {
    _ => None
  } noraise {
    json => Some(json)
  }
}

///|
/// Serialize a JSON value (compact form).
pub fn encode_json(json : Json) -> String {
  json.stringify()
}

///|
fn field(json : Json, key : String) -> Json raise JsonError {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(value) => value
        None => raise Missing(key)
      }
    _ => raise Missing(key)
  }
}

///|
/// The string value of an object field.
pub fn string_field(json : Json, key : String) -> String raise JsonError {
  match field(json, key) {
    String(value) => value
    _ => raise WrongType(key, "string")
  }
}

///|
/// The integer value of an object field. JSON numbers that carry a fraction
/// are rejected rather than truncated.
pub fn int_field(json : Json, key : String) -> Int raise JsonError {
  let number = match field(json, key) {
    Number(number, ..) => number
    _ => raise WrongType(key, "number")
  }
  if number != number.trunc() {
    raise WrongType(key, "integer")
  }
  number.to_int()
}

///|
/// The boolean value of an object field.
pub fn bool_field(json : Json, key : String) -> Bool raise JsonError {
  match field(json, key) {
    True => true
    False => false
    _ => raise WrongType(key, "bool")
  }
}

///|
/// The array value of an object field.
pub fn array_field(json : Json, key : String) -> Array[Json] raise JsonError {
  match field(json, key) {
    Array(value) => value
    _ => raise WrongType(key, "array")
  }
}

///|
/// The nested object value of an object field, kept as JSON so field reads
/// chain: `int_field(object_field(json, "amount"), "total")`.
pub fn object_field(json : Json, key : String) -> Json raise JsonError {
  let value = field(json, key)
  match value {
    Object(_) => value
    _ => raise WrongType(key, "object")
  }
}
