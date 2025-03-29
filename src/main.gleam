import gleam/bit_array
import gleam/bytes_builder
import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import internal/file_server
import internal/response

import gleam/erlang/process
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import glisten

pub fn main() {
  // Ensures gleam doesn't complain about unused imports in stage 1 (feel free to remove this!)
  let _ = glisten.handler
  let _ = glisten.serve
  let _ = process.sleep_forever
  let _ = actor.continue
  let _ = None

  // You can use print statements as follows for debugging, they'll be visible when running tests.
  io.println("Logs from your program will appear here!")

  // Uncomment this block to pass the first stage
  //
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      let msg = case msg {
        glisten.Packet(packet) -> packet |> bit_array.to_string
        glisten.User(msg) -> msg
      }

      let assert Ok(bytes) =
        msg
        |> result.map(parse)
        |> result.map(handle_request)

      let assert Ok(_) = glisten.send(conn, bytes)

      actor.continue(state)
    })
    |> glisten.serve(4221)

  process.sleep_forever()
}

// fn tap(value, logger) {
//   logger(value)
//   value
// }

type Request {
  Request(
    method: String,
    path: String,
    headers: Dict(String, String),
    body: Option(String),
  )
}

fn parse(request_string) {
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

fn handle_request(request) {
  case request {
    Request(method: "GET", path: "/", ..) -> response.ok() |> response.format
    Request(method: "GET", path: "/echo/" <> str, headers: headers, ..) -> {
      let response = response.ok()

      let response = case
        headers
        |> dict.get("Accept-Encoding")
        |> result.map(string.contains(_, "gzip"))
      {
        Ok(True) -> response.content_encoding(response, "gzip")
        _ -> response
      }

      response
      |> response.content_type("text/plain")
      |> response.body(str)
      |> response.format
    }
    Request(method: "GET", path: "/user-agent", headers: headers, ..) ->
      case headers |> dict.get("User-Agent") {
        Ok(user_agent) -> {
          response.ok()
          |> response.content_type("text/plain")
          |> response.body(user_agent)
          |> response.format
        }
        // lol
        _ -> bytes_builder.new()
      }

    // files
    Request(method: "GET", path: "/files" <> filename, ..) -> {
      case file_server.serve(filename) {
        Error(_) -> response.not_found() |> response.format
        Ok(content) -> {
          response.ok()
          |> response.content_type("application/octet-stream")
          |> response.body(content)
          |> response.format
        }
      }
    }

    Request(
      method: "POST",
      path: "/files" <> filename,
      headers: _headers,
      body: content,
    ) -> {
      let assert Some(content) = content
      let assert Ok(_) = file_server.create(filename, content)

      response.created()
      |> response.format()
    }

    // not found
    _ -> {
      response.not_found()
      |> response.format
    }
  }
}
