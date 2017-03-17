defmodule PhoenixHttp2Client do
  use GenServer

  def start_link(uri) do
    GenServer.start_link(__MODULE__, [uri])
  end

  def join_channel(pid, stream_id, topic) do
    send_event(pid, stream_id, topic, "phx_join")
  end

  def send_event(pid, stream_id, topic, event, payload \\ %{}) do
    data = %{topic: topic, event: event, payload: payload}
    send_json_data(pid, stream_id, data)
  end

  def send_json_data(pid, stream_id, data) do
    GenServer.call(pid, {:send_json_data, data, stream_id, [send_end_stream: false]})
  end

  def send_raw_data(pid, stream_id, data, opts \\ [send_end_stream: false]) do
    GenServer.call(pid, {:send_data, data, stream_id, opts})
  end

  def add_stream(pid) do
    GenServer.call(pid, :add_stream)
  end

  def init([uri]) do
    uri = URI.parse(uri)
    {:ok, pid} = connect(uri)
    {:ok, %{pid: pid, ref: 1, uri: uri}}
  end

  def handle_call({:send_json_data, data, stream_id, opts}, _reply, state) do
    data = Map.put_new(data, :ref, state.ref)
    send_body(state.pid, stream_id, Poison.encode!(data), opts)
    {:reply, :ok, %{state | ref: state.ref + 1}}
  end

  def handle_call({:send_data, data, stream_id, opts}, _reply, state) do
    send_body(state.pid, stream_id, data, opts)
    {:reply, :ok, state}
  end

  def handle_call(:add_stream, _reply, state) do
    path = "/socket/http2"
    {:ok, stream_id} = start_stream(state.pid, path, state.uri)
    {:reply, {:ok, stream_id}, state}
  end

  def handle_info({:RECV_DATA, stream_id, payload}, state) do
    require Logger
    case Poison.decode(payload) do
      {:ok, message} -> Logger.debug("received: #{inspect(message)} on #{stream_id}")
      _ -> Logger.warn("could not decode: #{inspect(payload)} on #{stream_id}")
    end
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp connect(%{host: host, port: port, scheme: scheme}) do
    transport = if scheme == "https", do: :ssl, else: :gen_tcp
    init_args = {:client, transport, String.to_charlist(host), port, [], :chatterbox.settings(:client)}
    :gen_fsm.start_link(:h2_connection, init_args, [])
  end

  defp start_stream(pid, path, %{host: host, scheme: scheme}) do
    headers = client_headers(path, host, scheme)
    stream_id = :h2_connection.new_stream(pid)
    :h2_connection.send_headers(pid, stream_id, headers)
    {:ok, stream_id}
  end

  defp send_body(pid, stream_id, message, opts) do
    :h2_connection.send_body(pid, stream_id, message, opts)
  end

  defp client_headers(path, host, scheme) do
    [
      {":method", "POST"},
      {":scheme", scheme},
      {":path", path},
      {":authority", host},
    ]
  end
end
