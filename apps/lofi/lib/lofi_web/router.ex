defmodule LofiWeb.Router do
  use LofiWeb, :router

  import LofiWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LofiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  # JSON for the visualization. It shares the browser session, so writes
  # carry the CSRF token the page receives from GET /api/me.
  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :fetch_current_scope_for_user
  end

  pipeline :signed_in do
    plug LofiWeb.Plugs.RequireUser
  end

  pipeline :admin do
    plug LofiWeb.Plugs.RequireUser
    plug LofiWeb.Plugs.RequireAdmin
  end

  scope "/", LofiWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Anyone may watch the cosmos
  scope "/", LofiWeb do
    pipe_through :api

    get "/ping", CosmosController, :ping
    get "/world", CosmosController, :world
    get "/beings", CosmosController, :beings
    get "/nodes", CosmosController, :nodes
    get "/being", CosmosController, :being
    get "/simulation", CosmosController, :simulation
    get "/api/me", MeController, :show
  end

  # Signed-in people tend their own being (and the commons)
  scope "/", LofiWeb do
    pipe_through [:api, :signed_in]

    post "/being/recall", BeingController, :recall
    post "/being/beckon", BeingController, :beckon

    post "/api/my/being", MyBeingController, :create
    put "/api/my/temperament", MyBeingController, :temperament
    post "/api/my/cards", MyBeingController, :add_card
    put "/api/my/cards/:card_id", MyBeingController, :update_card
    delete "/api/my/cards/:card_id", MyBeingController, :delete_card

    get "/api/my/history", HistoryController, :show
    get "/api/my/history/export", HistoryController, :export
  end

  # Only the admin runs the cosmos itself
  scope "/", LofiWeb do
    pipe_through [:api, :admin]

    post "/being", BeingController, :create
    post "/being/incantation", BeingController, :incantation
    post "/simulation/start", CosmosController, :start
    post "/simulation/stop", CosmosController, :stop
    post "/simulation/speed", CosmosController, :speed
    post "/cosmos/seed", CosmosController, :seed
    post "/cosmos/reset", CosmosController, :reset
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:lofi, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", LofiWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", LofiWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", LofiWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
