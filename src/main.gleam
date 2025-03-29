import gleam/bit_array
import gleam/bytes_builder
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import internal/file_server

import gleam/erlang/process
import gleam/option.{None}
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
        |> result.map(bytes_builder.from_string)

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
  Request(method: String, path: String, headers: Dict(String, String))
}

fn parse(request_string) {
  let assert [top, ..] = request_string |> string.split("\r\n\r\n")
  let assert [request_line, ..headers] = top |> string.split("\r\n")
  let assert [method, path, ..] = request_line |> string.split(" ")

  let headers =
    headers
    |> list.map(fn(header_string) {
      let assert [name, value] = header_string |> string.split(": ")
      #(name, value)
    })
    |> dict.from_list

  Request(method, path, headers)
}

fn handle_request(request) {
  case request {
    Request(method: "GET", path: "/", ..) -> "HTTP/1.1 200 OK\r\n\r\n"
    Request(method: "GET", path: "/echo/" <> str, ..) ->
      "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: "
      <> str |> string.byte_size |> int.to_string
      <> "\r\n\r\n"
      <> str
    Request(method: "GET", path: "/user-agent", headers: headers) ->
      case headers |> dict.get("User-Agent") {
        Ok(user_agent) -> {
          let size = user_agent |> string.byte_size |> int.to_string
          "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: "
          <> size
          <> "\r\n\r\n"
          <> user_agent
        }
        _ -> "bla"
      }
    Request(method: "GET", path: "/files" <> filename, ..) -> {
      case file_server.serve(filename) {
        Error(_) -> "HTTP/1.1 404 Not Found\r\n\r\n"
        Ok(content) -> {
          let size = content |> string.byte_size |> int.to_string

          "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: "
          <> size
          <> "\r\n\r\n"
          <> content
        }
      }
    }
    _ -> "HTTP/1.1 404 Not Found\r\n\r\n"
  }
}
