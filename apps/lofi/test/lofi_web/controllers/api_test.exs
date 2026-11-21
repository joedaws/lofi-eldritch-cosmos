defmodule LofiWeb.ApiTest do
  # the cosmos is shared state, so these run one at a time
  use LofiWeb.ConnCase, async: false

  import Lofi.AccountsFixtures

  setup do
    Eldritch.Genesis.reset()
    Eldritch.Landscape.generate(rings: [2, 4])
    Eldritch.Genesis.flush()
    # the first account becomes the keeper; make that explicit so the
    # people created in each test are ordinary
    %{keeper: user_fixture()}
  end

  # the page sends the CSRF token it gets from /api/me; tests skip that dance
  defp api(conn), do: put_private(conn, :plug_skip_csrf_protection, true)

  defp log_in(conn, user), do: conn |> log_in_user(user) |> api()


  test "anyone may watch", %{conn: conn} do
    assert %{"message" => _} = conn |> get(~p"/ping") |> json_response(200)
    assert %{"nodes" => nodes, "beings" => [], "simulation" => _} = conn |> get(~p"/world") |> json_response(200)
    assert length(nodes) == 7
    assert %{"user" => nil, "csrf_token" => _} = conn |> get(~p"/api/me") |> json_response(200)
    assert conn |> get(~p"/being?id=nope") |> json_response(404)
  end

  test "the page is served at /", %{conn: conn} do
    assert conn |> get(~p"/") |> response(200) =~ "Lofi Eldritch Cosmos"
  end

  test "writes need a signed-in person", %{conn: conn} do
    conn = api(conn)
    assert conn |> post(~p"/api/my/being", %{}) |> json_response(401)
    assert conn |> post(~p"/being/recall", %{"id" => "x", "answer" => "y"}) |> json_response(401)
    assert conn |> post(~p"/cosmos/seed", %{}) |> json_response(401)
  end

  test "writes without a CSRF token are refused", %{conn: conn} do
    # Phoenix's test conns skip CSRF checks unless told otherwise
    conn = conn |> log_in_user(user_fixture()) |> put_private(:plug_skip_csrf_protection, false)
    assert_error_sent 403, fn -> post(conn, ~p"/api/my/being", %{}) end
  end

  test "a person summons and tends their one being", %{conn: conn} do
    user = user_fixture()
    conn = log_in(conn, user)

    resp =
      conn
      |> post(~p"/api/my/being", %{
        "name" => "Gor Lop~Tome",
        "cards" => [%{"front" => "capital of Peru", "back" => "Lima"}],
        "temperament" => %{"generosity" => 80}
      })
      |> json_response(201)

    id = resp["being_id"]
    assert resp["being"]["temperament"]["generosity"] == 80
    assert conn |> post(~p"/api/my/being", %{}) |> json_response(422)

    me = conn |> get(~p"/api/me") |> json_response(200)
    assert me["user"]["display_name"] == user.display_name
    refute me["user"]["is_admin"]
    assert me["being"]["id"] == id
    assert [%{"front" => "capital of Peru", "back" => "Lima"}] = me["being"]["cards"]

    assert %{"temperament" => %{"wanderlust" => 10}} =
             conn |> put(~p"/api/my/temperament", %{"wanderlust" => 10}) |> json_response(200)

    %{"card" => card} = conn |> post(~p"/api/my/cards", %{"front" => "7 × 8", "back" => "56"}) |> json_response(201)
    assert conn |> put(~p"/api/my/cards/#{card["id"]}", %{"front" => "7 × 9", "back" => "63"}) |> json_response(200)
    assert conn |> delete(~p"/api/my/cards/#{card["id"]}") |> json_response(200)
    assert conn |> delete(~p"/api/my/cards/#{card["id"]}") |> json_response(404)

    # the world names the owner, never their email
    being = conn |> get(~p"/world") |> json_response(200) |> Map.fetch!("beings") |> Enum.find(&(&1["id"] == id))
    assert being["owner"] == user.display_name
    assert being["mine"]
    refute Map.has_key?(being, "owner_id")

    # the raw entity does not leak the deck
    entity = conn |> get(~p"/being?id=#{id}") |> json_response(200)
    deck = entity["components"] |> Map.values() |> Enum.find(&(&1["name"] == "deck"))
    assert deck["value"] == %{"cards" => 1}

    # beckoning: once, then the cooldown
    node = Eldritch.query("nodes")["node_ids"] |> List.delete(being["at_node"]) |> hd()
    assert conn |> post(~p"/being/beckon", %{"id" => id, "node_id" => node}) |> json_response(200)
    assert %{"retry_in_ms" => _} = conn |> post(~p"/being/beckon", %{"id" => id, "node_id" => node}) |> json_response(429)
  end

  test "others cannot tend your being", %{conn: conn} do
    owner = user_fixture()
    {:ok, id} = Eldritch.Being.Owned.summon(owner.id, %{})
    stranger = log_in(build_conn(), user_fixture())
    node = hd(Eldritch.query("nodes")["node_ids"])

    assert stranger |> post(~p"/being/beckon", %{"id" => id, "node_id" => node}) |> json_response(403)
    assert stranger |> post(~p"/being/recall", %{"id" => id, "answer" => "x"}) |> json_response(403)

    being = stranger |> get(~p"/world") |> json_response(200) |> Map.fetch!("beings") |> Enum.find(&(&1["id"] == id))
    refute being["mine"] or being["can_answer"]
    assert being["incantation"]["front"] == nil
    _ = conn
  end

  test "only the keeper runs the cosmos", %{conn: conn, keeper: keeper_user} do
    assert keeper_user.is_admin
    person = log_in(conn, user_fixture())
    assert person |> post(~p"/simulation/start", %{}) |> json_response(403)
    assert person |> post(~p"/cosmos/reset", %{}) |> json_response(403)

    keeper = log_in(build_conn(), keeper_user)
    assert %{"running" => true} = keeper |> post(~p"/simulation/start", %{}) |> json_response(200)
    assert %{"tick_ms" => 250} = keeper |> post(~p"/simulation/speed", %{"tick_ms" => 250}) |> json_response(200)
    assert %{"running" => false} = keeper |> post(~p"/simulation/stop", %{}) |> json_response(200)

    assert %{"nodes" => 7, "beings" => 3} =
             keeper
             |> post(~p"/cosmos/seed", %{"reset" => true, "rings" => [2, 4], "beings" => 3})
             |> json_response(200)

    assert %{"being_id" => _} = keeper |> post(~p"/being", %{"name" => "Commoner"}) |> json_response(200)
  end
end
