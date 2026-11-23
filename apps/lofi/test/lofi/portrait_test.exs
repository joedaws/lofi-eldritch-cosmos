defmodule Lofi.PortraitTest do
  use ExUnit.Case, async: true

  alias Lofi.Portrait
  alias Lofi.Portrait.{Features, ImageModel, Svg}

  defp parse!(svg) do
    {doc, _} =
      svg |> IO.iodata_to_binary() |> String.to_charlist() |> :xmerl_scan.string(quiet: true)

    doc
  end

  @calm %{
    "name" => "Gor Lop~Tome",
    "status" => "alive",
    "ichor" => 120,
    "psyche" => %{"lack" => 30}
  }

  test "a name always gives the same mask, and its parts are its eyes" do
    assert Features.anatomy("Gor Lop~Tome") == Features.anatomy("  gor lop~tome ")
    assert Features.anatomy("Gor Lop~Tome")["eyes"] == 3
    assert Features.anatomy("Ulth")["eyes"] == 1
    assert Features.anatomy("a b c d e f g h i")["eyes"] == 7

    faces = for n <- ~w(Ulth Qeb Kol Hask Vrin Sable Ithikka Morrow), do: Features.anatomy(n)

    assert faces
           |> Enum.map(&{&1["mask"], &1["crest"], &1["mouth"]})
           |> Enum.uniq()
           |> length() > 4
  end

  test "its mood follows its state, and changes the portrait's tag" do
    calm = Portrait.features(@calm)
    starving = Portrait.features(%{@calm | "ichor" => 5})
    faded = Portrait.features(Map.put(@calm, "status", "faded"))

    assert calm["anatomy"] == faded["anatomy"]
    assert starving["mood"]["vigor"] == 0
    assert faded["mood"]["faded"]
    assert Portrait.tag(calm) == Portrait.tag(Portrait.features(@calm))
    assert length(Enum.uniq(Enum.map([calm, starving, faded], &Portrait.tag/1))) == 3
    # a tick's worth of ichor does not
    assert Portrait.tag(calm) == Portrait.tag(Portrait.features(%{@calm | "ichor" => 121}))
  end

  test "every mask in every mood is well-formed SVG" do
    moods = [
      %{},
      %{"status" => "faded", "desire" => "bone"},
      %{
        "ichor" => 200,
        "desire" => "blood",
        "incantation" => %{"awaiting" => true},
        "psyche" => %{
          "lack" => 100,
          "registers" => %{"real" => 0.7, "symbolic" => 0.1, "imaginary" => 0.2},
          "unknotted" => "real"
        }
      },
      %{
        "ichor" => 3,
        "temperament" => %{"wanderlust" => 100, "sociability" => 0},
        "psyche" => %{
          "registers" => %{"imaginary" => 0.6, "real" => 0.2, "symbolic" => 0.2},
          "symptom" => %{},
          "objet_a" => "papyrus"
        }
      },
      %{"psyche" => %{"registers" => %{"symbolic" => 0.6, "real" => 0.2, "imaginary" => 0.2}}}
    ]

    for i <- 1..120, mood <- moods do
      name = "Being<&\"#{i}\"> #{rem(i, 7)}~#{div(i, 9)}"
      f = Portrait.features(Map.put(mood, "name", name))
      {:ok, svg, "image/svg+xml"} = Svg.render(f, [])
      text = IO.iodata_to_binary(svg)
      refute text =~ "NaN"
      parse!(svg)
      {:ok, bare, _} = Svg.render(f, frame: false)
      parse!(bare)
    end
  end

  test "every mask carries every crest, eye, mouth and mark, in ink and in silhouette" do
    base = Portrait.features(@calm)

    for mask <- Features.masks(),
        crest <- Features.crests(),
        {eye_shape, mouth, mark} <-
          Enum.zip([Features.eye_shapes(), Features.mouths(), Features.marks()]),
        eyes <- [1, 3, 7],
        faded <- [false, true] do
      f =
        base
        |> put_in(["anatomy", "mask"], mask)
        |> put_in(["anatomy", "crest"], crest)
        |> put_in(["anatomy", "eye_shape"], eye_shape)
        |> put_in(["anatomy", "mouth"], mouth)
        |> put_in(["anatomy", "mark"], mark)
        |> put_in(["anatomy", "eyes"], eyes)
        |> put_in(["mood", "faded"], faded)

      {:ok, svg, _} = Svg.render(f, [])
      refute IO.iodata_to_binary(svg) =~ "NaN"
      parse!(svg)
      {:ok, sil, _} = Svg.render(f, silhouette: true)
      parse!(sil)
    end
  end

  test "a prompt describes the portrait" do
    prompt = Portrait.prompt(Portrait.features(Map.put(@calm, "status", "faded")))
    assert prompt =~ "Gor Lop~Tome"
    assert prompt =~ "3 eyes"
    assert prompt =~ "mask"
    assert prompt =~ "faded"
  end

  describe "an image model" do
    defmodule FakeModel do
      def generate(prompt, seed) do
        send(self(), {:generated, prompt, seed})
        {:ok, "PNG:" <> prompt}
      end

      def fail(_prompt, _seed), do: {:error, :overloaded}
    end

    setup do
      dir = Path.join(System.tmp_dir!(), "portraits-#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(dir) end)
      %{dir: dir}
    end

    test "is not used until configured: the SVG is drawn instead" do
      f = Portrait.features(@calm)
      assert ImageModel.render(f, []) == {:error, :not_configured}
      assert {_svg, "image/svg+xml"} = Portrait.render(f, renderer: ImageModel)
    end

    test "is asked once per portrait, and kept", %{dir: dir} do
      f = Portrait.features(@calm)
      Application.put_env(:lofi, ImageModel, generate: {FakeModel, :generate}, dir: dir)
      on_exit(fn -> Application.delete_env(:lofi, ImageModel) end)

      assert {"PNG:" <> prompt, "image/png"} = Portrait.render(f, renderer: ImageModel)
      assert_received {:generated, ^prompt, seed}
      assert seed == f["anatomy"]["seed"]
      assert {"PNG:" <> _, "image/png"} = Portrait.render(f, renderer: ImageModel)
      refute_received {:generated, _, _}

      Application.put_env(:lofi, ImageModel, generate: {FakeModel, :fail}, dir: dir)
      other = Portrait.features(%{@calm | "name" => "Ulth"})
      assert {_svg, "image/svg+xml"} = Portrait.render(other, renderer: ImageModel)
    end
  end
end
