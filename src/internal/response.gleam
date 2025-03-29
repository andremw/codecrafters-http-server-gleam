import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub opaque type Response {
  Response(
    status_code: String,
    headers: Dict(String, String),
    body: Option(String),
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

fn insert_header(response, header, value) {
  Response(..response, headers: dict.insert(response.headers, header, value))
}

pub fn body(response, body) {
  Response(..response, body: Some(body))
}

pub fn format(response: Response) {
  let response = content_length(response)

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

  let body = response.body |> option.unwrap("")

  top <> headers_line <> "\r\n\r\n" <> body
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
        body |> string.byte_size |> int.to_string,
      )
  }
}
