defmodule Lofi.Portrait.ImageModel do
  @moduledoc """
  Scaffold for portraits painted by an AI image model.

  Not used unless configured. It turns features into a prompt
  (`Lofi.Portrait.Prompt`), asks the configured `generate` function for an
  image, and keeps the result on disk, so each distinct portrait (one name in
  one mood) is generated once:

      config :lofi, Lofi.Portrait, renderer: Lofi.Portrait.ImageModel
      config :lofi, Lofi.Portrait.ImageModel,
        generate: {MyImageApi, :generate},   # (prompt, seed) -> {:ok, png} | {:error, _}
        dir: "/var/lib/lofi-eldritch-cosmos/portraits"

  Until then (or when generation fails) `Lofi.Portrait.render/2` falls back
  to the SVG. Generation runs inside the request; for a slow model, move it
  to a background job and serve the SVG until the image is ready.
  """
  @behaviour Lofi.Portrait.Renderer

  @impl true
  def render(features, _opts) do
    config = Application.get_env(:lofi, __MODULE__, [])

    case config[:generate] do
      {mod, fun} when is_atom(mod) and is_atom(fun) -> generate(features, mod, fun, config)
      _ -> {:error, :not_configured}
    end
  end

  defp generate(features, mod, fun, config) do
    path = Path.join(dir(config), Lofi.Portrait.tag(features) <> ".png")

    case File.read(path) do
      {:ok, png} ->
        {:ok, png, "image/png"}

      {:error, _} ->
        with {:ok, png} <-
               apply(mod, fun, [Lofi.Portrait.prompt(features), features["anatomy"]["seed"]]) do
          File.mkdir_p!(Path.dirname(path))
          File.write!(path, png)
          {:ok, png, "image/png"}
        end
    end
  end

  defp dir(config),
    do: config[:dir] || Path.join(Application.fetch_env!(:cosmos, :local_db_dir), "portraits")
end
