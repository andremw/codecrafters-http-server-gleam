import gleam/bit_array
import gleam/bytes_builder
import gleam/int
import gleam/io
import gleam/result
import gleam/string

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
        |> result.map(to_request_parts)
        |> result.try(parse)
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

fn to_request_parts(request_string) {
  request_string |> string.split("\r\n")
}

type Request {
  Request(method: String, path: String)
}

fn parse(request_parts) {
  case request_parts {
    [request_line, ..] ->
      case request_line |> string.split(" ") {
        [method, path, ..] -> Ok(Request(method, path))
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn handle_request(request) {
  case request {
    Request(method: "GET", path: "/") -> "HTTP/1.1 200 OK\r\n\r\n"
    Request(method: "GET", path: "/echo/" <> str) ->
      "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: "
      <> str |> string.byte_size |> int.to_string
      <> "\r\n\r\n"
      <> str
    _ -> "HTTP/1.1 404 Not Found\r\n\r\n"
  }
}
