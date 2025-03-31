import gleam/bytes_builder.{type BytesBuilder}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub opaque type Response {
  Response(
    status_code: String,
    headers: Dict(String, String),
    body: Option(BytesBuilder),
  )
}

pub fn ok() {
  Response(status_code: "200", headers: dict.new(), body: None)
}

pub fn created() {
  Response(status_code: "201", headers: dict.new(), body: None)
}

pub fn not_found() {
  Response(status_code: "404", headers: dict.new(), body: None)
}

pub fn content_type(response, value) {
  insert_header(response, "Content-Type", value)
}

pub fn content_encoding(response, value) {
  insert_header(response, "Content-Encoding", value)
}

fn insert_header(response, header, value) {
  Response(..response, headers: dict.insert(response.headers, header, value))
}

pub fn body(response, body) {
  Response(..response, body: Some(body |> bytes_builder.from_string))
}

pub fn format(response: Response) {
  let response = content_length(response)
  let response = gzip_if_necessary(response)

  let top =
    "HTTP/1.1 "
    <> response.status_code
    <> " "
    <> get_status(response.status_code)

  let headers_line =
    response.headers
    |> dict.to_list
    |> list.map(fn(header) {
      let #(name, value) = header

      "\r\n" <> name <> ": " <> value
    })
    |> string.join("")

  let body = response.body |> option.unwrap(bytes_builder.new())

  top
  |> bytes_builder.from_string
  |> bytes_builder.append_string(headers_line)
  |> bytes_builder.append_string("\r\n\r\n")
  |> bytes_builder.append_builder(body)
}

fn get_status(status_code) {
  case status_code {
    "200" -> "OK"
    "201" -> "Created"
    "404" -> "Not Found"
    _ -> "WAT"
  }
}

fn content_length(response: Response) {
  case response.body {
    None -> response
    Some(body) ->
      insert_header(
        response,
        "Content-Length",
        body |> bytes_builder.byte_size |> int.to_string,
      )
  }
}

fn gzip_if_necessary(response: Response) {
  let needs_gzip =
    response.headers
    |> dict.get("Content-Encoding")
    |> result.map(string.split(_, " "))
    |> result.map(list.any(_, fn(encoding) { encoding == "gzip" }))
    |> result.unwrap(False)

  case response.body, needs_gzip {
    Some(body), True -> {
      let bytes =
        body
        |> bytes_builder.to_bit_array
        |> gzip
        |> bytes_builder.from_bit_array
      Response(..response, body: Some(bytes))
      // recalculate content_length
      |> content_length
    }
    _, False -> response
    None, True -> response
  }
}

@external(erlang, "zlib", "gzip")
fn gzip(data: BitArray) -> BitArray
