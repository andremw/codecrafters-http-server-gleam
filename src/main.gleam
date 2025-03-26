import gleam/bytes_builder
import gleam/io

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
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(_msg, state, conn) {
      io.println("Received message!")

      let assert Ok(_) =
        "HTTP/1.1 200 OK\r\n\r\n"
        |> bytes_builder.from_string
        |> glisten.send(conn, _)

      actor.continue(state)
    })
    |> glisten.serve(4221)

  process.sleep_forever()
}
