defmodule Lens2.MostlyText.ImplementationV1GetTest do
  use Lens2.Case, async: true

  defmodule V1 do
    @type container :: any
    @type descender :: (container -> any)
    @type get_lens :: (container, descender -> [any])

    @spec at(non_neg_integer) :: get_lens
    def at(index) do
      fn container, descender ->
        gotten =
          Enum.at(container, index)
          |> descender.()
        [gotten]
      end
    end

    def seq(outer_lens, inner_lens) do
      fn outer_container, inner_descender ->
        outer_descender =
          fn inner_container ->
            inner_lens.(inner_container, inner_descender)
          end

        gotten =
          outer_lens.(outer_container, outer_descender)

        Enum.concat(gotten)
      end
    end

    def all do
      fn container, descender ->
        for item <- container, do: descender.(item)
      end
    end
  end

  defmodule Derply do
    def get_all(container, lens) do
      getter = & &1    # Just return the leaf value
      lens.(container, getter)
    end

  end

  test "at called alone" do
    lens = V1.at(1)
    assert Derply.get_all(["0", "1", "2"], lens) == ["1"]
  end

  test "using seq" do
    lens = V1.seq(V1.at(0), V1.at(1))
    assert Derply.get_all([["0", "1", "2"], [], []], lens) == ["1"]
  end

  test "all" do
    nested = [ [0, 1, 2], [0, 1111, 2222]]
    lens = V1.seq(V1.all(), V1.at(1))
    assert Derply.get_all(nested, lens) == [1, 1111]
  end
end
