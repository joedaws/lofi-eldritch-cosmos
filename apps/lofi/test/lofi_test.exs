defmodule LofiTest do
  use ExUnit.Case
  use Plug.Test
  doctest Lofi

  @opts Lofi.Web.init([])

  setup_all do
    Eldritch.Simulation.initialize_systems()
    on_exit(fn -> Eldritch.Genesis.reset() end)
    :ok
  end

  defp call(method, path, body \\ nil) do
    conn =
      case body do
        nil -> conn(method, path)
        body -> conn(method, path, Poison.encode!(body)) |> put_req_header("content-type", "application/json")
      end

    conn = Lofi.Web.call(conn, @opts)
    {conn.status, Poison.decode!(conn.resp_body)}
  end

  test "greets the world" do
    assert Lofi.hello() == :world
  end

  test "ping" do
    assert {200, %{"message" => _}} = call(:get, "/ping")
  end

  test "serves the visualization" do
    conn = Lofi.Web.call(conn(:get, "/"), @opts)
    assert conn.status == 200
    assert conn.resp_body =~ "Lofi"
  end

  test "creating and fetching beings" do
    assert {200, %{"being_id" => plain}} = call(:post, "/being")

    assert {200, %{"being_id" => id}} =
             call(:post, "/being", %{"incantation" => %{"front" => "f", "back" => "b"}})

    assert {200, %{"id" => ^id, "components" => _}} = call(:get, "/being?id=#{id}")
    assert {404, _} = call(:get, "/being?id=nope")
    assert {400, _} = call(:post, "/being", %{"incantation" => %{"back" => "only"}})

    assert {200, %{"being_ids" => ids}} = call(:get, "/beings")
    assert plain in ids and id in ids
  end

  test "seeding, world snapshot, simulation controls" do
    assert {200, %{"nodes" => 7, "beings" => 3}} =
             call(:post, "/cosmos/seed", %{"reset" => true, "rings" => [2, 4], "beings" => 3})

    assert {200, %{"nodes" => nodes, "beings" => beings, "simulation" => sim}} =
             call(:get, "/world")

    assert length(nodes) == 7 and length(beings) == 3
    assert sim["running"] == false

    assert {200, %{"tick_ms" => 250}} = call(:post, "/simulation/speed", %{"tick_ms" => 250})
    assert {200, %{"running" => true}} = call(:post, "/simulation/start", %{})
    assert {200, %{"running" => false}} = call(:post, "/simulation/stop", %{})

    [being | _] = beings
    target = Enum.find(nodes, &(&1["id"] != being["at_node"]))
    assert {200, _} = call(:post, "/being/beckon", %{"id" => being["id"], "node_id" => target["id"]})
    assert {409, _} = call(:post, "/being/recall", %{"id" => being["id"], "answer" => "x"})
  end
end
