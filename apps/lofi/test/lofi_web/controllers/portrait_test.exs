defmodule LofiWeb.PortraitTest do
  # the cosmos is shared state, so these run one at a time
  use LofiWeb.ConnCase, async: false

  import Lofi.AccountsFixtures

  setup do
    Eldritch.History.reset()
    Eldritch.Genesis.reset()
    Eldritch.Landscape.generate(rings: [2, 4])
    Eldritch.Genesis.flush()
    _keeper = user_fixture()
    {:ok, id} = Eldritch.Being.Owned.summon(user_fixture().id, %{"name" => "Gor Lop~Tome"})
    Eldritch.Genesis.flush()
    %{id: id}
  end

  test "every being in the world carries its portrait's address", %{conn: conn, id: id} do
    being =
      conn
      |> get(~p"/world")
      |> json_response(200)
      |> Map.fetch!("beings")
      |> Enum.find(&(&1["id"] == id))

    assert "/portraits/" <> rest = being["portrait"]
    assert rest =~ ~r/^#{id}\?v=[\w-]{12}$/
  end

  test "a being's portrait is an SVG, cached by its tag", %{conn: conn, id: id} do
    conn1 = get(conn, ~p"/portraits/#{id}")
    assert response(conn1, 200) =~ "<svg"
    assert response_content_type(conn1, :svg) =~ "image/svg+xml"
    assert response(conn1, 200) =~ "Gor Lop~Tome"
    [etag] = get_resp_header(conn1, "etag")

    assert build_conn()
           |> put_req_header("if-none-match", etag)
           |> get(~p"/portraits/#{id}")
           |> response(304)

    refute get(build_conn(), ~p"/portraits/#{id}?frame=0") |> response(200) =~
             "Gor Lop~Tome</text>"

    assert get(build_conn(), ~p"/portraits/nobody") |> response(404)
  end

  test "a name can be previewed before it is summoned", %{conn: conn} do
    svg = conn |> get(~p"/portraits/preview?name=Ulth the Patient") |> response(200)
    assert svg =~ "Ulth the Patient"

    assert svg ==
             build_conn() |> get(~p"/portraits/preview?name=Ulth the Patient") |> response(200)
  end

  test "its features and prompt are public", %{conn: conn, id: id} do
    assert %{
             "features" => %{"anatomy" => %{"eyes" => 3}},
             "prompt" => prompt,
             "url" => "/portraits/" <> _
           } =
             conn |> get(~p"/portraits/#{id}/features") |> json_response(200)

    assert prompt =~ "Gor Lop~Tome"
  end
end
