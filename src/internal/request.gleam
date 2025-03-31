import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option}
import gleam/string

pub type Request {
  Request(
    method: String,
    path: String,
    headers: Dict(String, String),
    body: Option(String),
  )
}

pub fn parse(request_string) {
  let assert [top, body] = request_string |> string.split("\r\n\r\n")
  let assert [request_line, ..headers_line] = top |> string.split("\r\n")
  let assert [method, path, ..] = request_line |> string.split(" ")

  let headers = parse_headers(headers_line)

  let body = body |> string.split("\r\n") |> list.first |> option.from_result

  Request(method, path, headers, body)
}

fn parse_headers(headers_line) {
  headers_line
  |> list.map(fn(header_string) {
    let assert [name, value] = header_string |> string.split(": ")
    #(name, value)
  })
  |> dict.from_list
}
