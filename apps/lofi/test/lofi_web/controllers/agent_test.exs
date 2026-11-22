defmodule LofiWeb.AgentTest do
  # the cosmos is shared state, so these run one at a time
  use LofiWeb.ConnCase, async: false

  import Lofi.AccountsFixtures
  alias Lofi.Accounts

  setup do
    Eldritch.History.reset()
    Eldritch.Genesis.reset()
    Eldritch.Landscape.generate(rings: [2, 4])
    Eldritch.Genesis.flush()
    _keeper = user_fixture()
    person = user_fixture()

    {:ok, being} =
      Eldritch.Being.Owned.summon(person.id, %{
        "name" => "Gor Lop~Tome",
        "cards" => [%{"front" => "capital of Peru", "back" => "Lima"}]
      })

    Eldritch.Genesis.flush()
    {:ok, token, _} = Accounts.create_agent_token(person, "Claude")
    %{person: person, being: being, token: token}
  end

  defp agent(token), do: build_conn() |> put_req_header("authorization", "Bearer " <> token)

  defp rpc(token, method, params \\ %{}, id \\ 1) do
    agent(token)
    |> put_req_header("content-type", "application/json")
    |> post(~p"/mcp", Jason.encode!(%{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}))
  end

  defp tool(token, name, args \\ %{}) do
    %{"result" => result} = token |> rpc("tools/call", %{"name" => name, "arguments" => args}) |> json_response(200)
    result
  end

  defp make_due(being) do
    Cosmos.Entity.Server.update_component(Cosmos.Entity.Cache.server_process(being), "deck", fn c ->
      %{c | value: %{"cards" => Enum.map(c.value["cards"], &%{&1 | "due_at" => 0})}}
    end)

    Eldritch.System.Remind.update_components(Eldritch.System.Remind)
    Eldritch.Genesis.flush()
  end

  describe "tokens" do
    test "are shown once, stored only as a hash, and stop working when revoked", %{person: person, token: token} do
      assert "lofi_agent_" <> _ = token
      [stored] = Accounts.list_agent_tokens(person)
      refute stored.token_hash == token
      assert {%{id: id}, %{name: "Claude"}} = Accounts.get_user_by_agent_token(token)
      assert id == person.id

      {:ok, _} = Accounts.revoke_agent_token(person, stored.id)
      assert Accounts.get_user_by_agent_token(token) == nil
      assert agent(token) |> get(~p"/api/agent/being") |> json_response(401)
    end

    test "only their owner can revoke them", %{person: person} do
      [stored] = Accounts.list_agent_tokens(person)
      assert Accounts.revoke_agent_token(user_fixture(), stored.id) == {:error, :not_found}
    end

    test "at most ten at a time", %{person: person} do
      for i <- 2..10, do: {:ok, _, _} = Accounts.create_agent_token(person, "bot #{i}")
      assert Accounts.create_agent_token(person, "one too many") == {:error, :too_many_tokens}
    end

    test "requests without a valid token are refused" do
      conn = build_conn() |> get(~p"/api/agent/being")
      assert json_response(conn, 401)
      assert get_resp_header(conn, "www-authenticate") != []
      assert agent("lofi_agent_nope") |> post(~p"/mcp", %{}) |> json_response(401)
    end
  end

  describe "the JSON api" do
    test "shows the person's being, deck, whisper and accuracy", %{token: token, being: being} do
      assert %{"result" => %{"id" => ^being, "name" => "Gor Lop~Tome", "grace_left_ms" => grace}} =
               agent(token) |> get(~p"/api/agent/being") |> json_response(200)

      assert grace > 0

      assert %{"result" => [%{"front" => "capital of Peru", "back" => "Lima", "box" => 1}]} =
               agent(token) |> get(~p"/api/agent/cards") |> json_response(200)

      assert %{"result" => nil} = agent(token) |> get(~p"/api/agent/whispering") |> json_response(200)
      make_due(being)
      assert %{"result" => %{"front" => "capital of Peru", "back" => "Lima"}} =
               agent(token) |> get(~p"/api/agent/whispering") |> json_response(200)

      {:ok, _} = Eldritch.Being.recall(being, "Cusco", Accounts.get_user_by_agent_token(token) |> elem(0) |> Map.get(:id))

      assert %{"result" => [%{"front" => "capital of Peru", "answers" => 1, "right" => 0}]} =
               agent(token) |> get(~p"/api/agent/accuracy") |> json_response(200)

      assert %{"result" => [%{"kind" => "answer"} | _]} = agent(token) |> get(~p"/api/agent/history") |> json_response(200)
      assert %{"result" => [_ | _]} = agent(token) |> get(~p"/api/agent/events") |> json_response(200)
      assert %{"result" => %{"simulation" => _, "places" => 7}} = agent(token) |> get(~p"/api/agent/overview") |> json_response(200)
      assert %{"result" => %{"explanation" => text}} = agent(token) |> get(~p"/api/agent/explain?topic=grace") |> json_response(200)
      assert text =~ "3 days"
    end

    test "edits the deck, and the person's history says it was their agent", %{token: token, person: person} do
      %{"result" => %{"id" => id}} =
        agent(token) |> post(~p"/api/agent/cards", %{"front" => "7 × 8", "back" => "56"}) |> json_response(201)

      assert agent(token) |> put(~p"/api/agent/cards/#{id}", %{"front" => "7 × 9", "back" => "63"}) |> json_response(200)
      assert agent(token) |> delete(~p"/api/agent/cards/#{id}") |> json_response(200)
      assert %{"error" => "no such card"} = agent(token) |> delete(~p"/api/agent/cards/#{id}") |> json_response(422)

      vias = person.id |> Eldritch.History.interactions() |> Enum.map(& &1["data"]["via"]) |> Enum.reject(&is_nil/1)
      assert vias == ["agent: Claude", "agent: Claude", "agent: Claude"]
    end

    test "an agent sees only its own person's being" do
      other = user_fixture()
      {:ok, other_token, _} = Accounts.create_agent_token(other, "other bot")

      assert %{"result" => nil} = agent(other_token) |> get(~p"/api/agent/being") |> json_response(200)
      assert %{"result" => []} = agent(other_token) |> get(~p"/api/agent/cards") |> json_response(200)
      overview = agent(other_token) |> get(~p"/api/agent/overview") |> json_response(200)
      refute Jason.encode!(overview) =~ "capital of Peru"
    end
  end

  describe "the MCP server" do
    test "initializes, negotiating the protocol version", %{token: token} do
      %{"result" => result} =
        token
        |> rpc("initialize", %{"protocolVersion" => "2025-03-26", "capabilities" => %{}, "clientInfo" => %{"name" => "test"}})
        |> json_response(200)

      assert result["protocolVersion"] == "2025-03-26"
      assert result["capabilities"]["tools"]
      assert result["serverInfo"]["name"] == "lofi-eldritch-cosmos"
      assert result["instructions"] =~ "cannot answer"

      %{"result" => %{"protocolVersion" => latest}} =
        token |> rpc("initialize", %{"protocolVersion" => "1999-01-01"}) |> json_response(200)

      assert latest == "2025-06-18"
    end

    test "accepts notifications without a reply", %{token: token} do
      conn =
        agent(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/mcp", Jason.encode!(%{"jsonrpc" => "2.0", "method" => "notifications/initialized"}))

      assert response(conn, 202) == ""
    end

    test "lists its tools, none of which answers whispers", %{token: token} do
      %{"result" => %{"tools" => tools}} = token |> rpc("tools/list") |> json_response(200)
      names = Enum.map(tools, & &1["name"])

      for n <- ~w(my_being my_cards whispering_now card_accuracy recent_history what_befell_my_being cosmos_overview explain add_card rewrite_card burn_card),
          do: assert(n in names)

      refute Enum.any?(names, &(&1 =~ ~r/answer|recall/))
      assert Enum.all?(tools, &(&1["inputSchema"]["type"] == "object"))
      assert Enum.find(tools, &(&1["name"] == "burn_card"))["annotations"]["destructiveHint"]
    end

    test "calls tools", %{token: token} do
      result = tool(token, "my_cards")
      refute result["isError"]
      assert %{"result" => [%{"front" => "capital of Peru"}]} = result["structuredContent"]
      assert [%{"type" => "text", "text" => text}] = result["content"]
      assert text =~ "capital of Peru"

      assert %{"structuredContent" => %{"result" => %{"front" => "7 × 8"}}} =
               tool(token, "add_card", %{"front" => "7 × 8", "back" => "56"})

      assert length(tool(token, "my_cards")["structuredContent"]["result"]) == 2
    end

    test "reports tool failures as tool errors, and unknown things as protocol errors", %{token: token} do
      assert %{"isError" => true, "content" => [%{"text" => "a card needs a front"}]} = tool(token, "add_card", %{"front" => ""})

      assert %{"error" => %{"code" => -32602}} =
               token |> rpc("tools/call", %{"name" => "answer_whisper"}) |> json_response(200)

      assert %{"error" => %{"code" => -32601}} = token |> rpc("resources/list") |> json_response(200)
      assert %{"result" => %{}} = token |> rpc("ping") |> json_response(200)
      assert agent(token) |> get(~p"/mcp") |> response(405)
    end
  end

  describe "settings" do
    test "a person creates a token (shown once) and revokes it", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      page = conn |> post(~p"/users/settings/agent-tokens", %{"agent_token" => %{"name" => "My tutor"}}) |> html_response(200)
      [plain] = Regex.run(~r/lofi_agent_[A-Za-z0-9_-]+/, page)
      assert page =~ "claude mcp add"
      assert page =~ "My tutor"
      assert {%{id: id}, _} = Accounts.get_user_by_agent_token(plain)
      assert id == user.id

      # never shown again
      refute conn |> get(~p"/users/settings") |> html_response(200) =~ plain

      [token] = Accounts.list_agent_tokens(user)
      conn |> delete(~p"/users/settings/agent-tokens/#{token.id}") |> redirected_to()
      assert Accounts.get_user_by_agent_token(plain) == nil
    end
  end
end
