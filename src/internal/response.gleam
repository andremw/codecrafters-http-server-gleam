import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None}
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

pub fn not_found() {
  Response(status_code: "404", headers: dict.new(), body: None)
}

pub fn format(response: Response) {
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

  top <> headers_line <> "\r\n\r\n"
}

fn get_status(status_code) {
  case status_code {
    "200" -> "OK"
    "201" -> "Created"
    "404" -> "Not Found"
    _ -> "WAT"
  }
}
