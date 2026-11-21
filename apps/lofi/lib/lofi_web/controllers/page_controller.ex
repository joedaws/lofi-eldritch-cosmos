defmodule LofiWeb.PageController do
  use LofiWeb, :controller

  # the visualization is a single static page that talks to the JSON api
  def home(conn, _params) do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Application.app_dir(:lofi, "priv/static/index.html"))
  end
end
