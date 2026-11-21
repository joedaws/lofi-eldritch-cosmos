defmodule LofiWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LofiWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="desk">
      <nav class="topnav" aria-label="Account">
        <a href={~p"/"} class="home">← back to the cosmos</a>
        <%= if @current_scope do %>
          <span class="who">{@current_scope.user.display_name}</span>
          <a href={~p"/users/settings"}>Settings</a>
          <.form for={%{}} action={~p"/users/log-out"} method="delete" class="inline">
            <button type="submit" class="linkish">Log out</button>
          </.form>
        <% else %>
          <a href={~p"/users/register"}>Register</a>
          <a href={~p"/users/log-in"}>Log in</a>
        <% end %>
      </nav>
      <main class="win">
        <div class="bar"><span class="box"></span><span class="title">Lofi Eldritch Cosmos</span></div>
        <div class="pane">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
