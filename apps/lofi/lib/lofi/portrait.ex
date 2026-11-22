defmodule Lofi.Portrait do
  @moduledoc """
  Portraits of beings.

  A portrait is drawn from a being's *features* (`Lofi.Portrait.Features`):

    * its **anatomy** comes from its name alone, so a being keeps its face
      all its life, and a name can be previewed before it is summoned;
    * its **mood** comes from its state, coarsely bucketed so the portrait
      changes when something meaningful changes (hunger, lack, a loosened
      knot, mourning, fading) and not on every tick.

  A renderer (`Lofi.Portrait.Renderer`) turns features into an image. The
  default, `Lofi.Portrait.Svg`, draws procedurally and needs nothing.
  `Lofi.Portrait.ImageModel` is the scaffold for an AI image model: it builds
  a prompt (`Lofi.Portrait.Prompt`) and caches what the model returns, and
  falls back to the SVG until a model is configured:

      config :lofi, Lofi.Portrait, renderer: Lofi.Portrait.ImageModel
      config :lofi, Lofi.Portrait.ImageModel, generate: {MyImageApi, :generate}
  """
  alias Lofi.Portrait.{Features, Prompt, Svg}

  @doc "Features of a being (a `Eldritch.World.being_view/2` map) or of a bare name"
  defdelegate features(being_or_name), to: Features, as: :from

  @doc "A text prompt describing the portrait, for image models (and agents)"
  defdelegate prompt(features), to: Prompt, as: :build

  @doc """
  Renders features with the configured renderer, falling back to the SVG.
  Returns `{iodata, content_type}`.
  """
  def render(features, opts \\ []) do
    renderer = Keyword.get(opts, :renderer, renderer())

    case renderer.render(features, opts) do
      {:ok, image, content_type} ->
        {image, content_type}

      {:error, _reason} when renderer != Svg ->
        {:ok, image, content_type} = Svg.render(features, opts)
        {image, content_type}
    end
  end

  def renderer(), do: Application.get_env(:lofi, __MODULE__, [])[:renderer] || Svg

  @doc "A short tag that changes whenever the portrait would (for ETags and URLs)"
  def tag(features) do
    {features, renderer()}
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 12)
  end

  @doc "Where the page finds a being's current portrait"
  def url(%{"id" => id} = being_view),
    do: "/portraits/#{id}?v=#{being_view |> features() |> tag()}"
end
