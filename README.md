# PhoenixHttp2Client

Example HTTP2 client for Phoenix channels all input will be logged to debug.

This is based off of the chatterbox client in [grpc-elixir][3]

For use with [phoenix_cowboy2_example][1] which is using the
[http2-transport][2] branch of phoenix_cowboy2.

[1]: https://github.com/VoiceLayer/phoenix_cowboy2_example/tree/feat/http2-transport
[2]: https://github.com/VoiceLayer/phoenix_cowboy2/tree/feat/http2-transport
[3]: https://github.com/tony612/grpc-elixir/blob/ec4534bc1df6e1b93181b6ed3d9449494fee061c/lib/grpc/adapter/chatterbox/client.ex

## Usage

Start with `iex -S mix`

    {:ok, pid} = PhoenixHttp2Client.start_link("https://localhost:4001")
    {:ok, stream_id} = PhoenixHttp2Client.add_stream(pid)
    PhoenixHttp2Client.join_channel(pid, stream_id, "room:lobby")
    PhoenixHttp2Client.send_event(pid, stream_id, "room:lobby", "shout", %{test: "message"})
