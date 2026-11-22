defmodule Lofi.Portrait.Renderer do
  @moduledoc """
  Turns a being's portrait features (`Lofi.Portrait.Features`) into an image.

  Renderers must be deterministic enough to cache: the same features should
  give the same portrait (or at least the same being). Options include
  `frame: false` to leave out the frame and name plate.
  """

  @callback render(features :: map(), opts :: keyword()) ::
              {:ok, image :: iodata(), content_type :: String.t()} | {:error, term()}
end
