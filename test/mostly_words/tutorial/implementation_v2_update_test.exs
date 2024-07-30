defmodule Lens2.MostlyText.ImplementationV2UpdateTest do
  use Lens2.Case, async: true


  defmodule V2 do
    @type container :: any
    @type descender :: (container -> container)
    @type update_lens :: (container, descender -> container)

    @spec at(non_neg_integer) :: update_lens
    def at(index) do
      fn container, descender ->
        updated =
          Enum.at(container, index)
          |> descender.()
        List.replace_at(container, index, updated)
      end
    end

    def key(key) do
      fn container, descender ->
        updated =
          Map.get(container, key)
          |> descender.()

        Map.put(container, key, updated)
      end
    end

    def seq(outer_lens, inner_lens) do
      fn outer_container, inner_descender ->
        outer_descender =
          fn inner_container ->
            inner_lens.(inner_container, inner_descender)
          end

        updated =
          outer_lens.(outer_container, outer_descender)

        updated
      end
    end

    def all do
      fn container, descender ->
        for item <- container, do: descender.(item)
      end
    end
  end


  defmodule Derply do
    def update(container, lens, update_fn) do
      lens.(container, update_fn)
    end

    def put(container, lens, constant) do
      lens.(container, fn _ -> constant end)
    end
  end

  test "at called alone" do
    lens = V2.at(1)
    assert Derply.update([0, 1, 2], lens, &inspect/1) == [0, "1", 2]
    assert Derply.put([0, 1, 2], lens, "NEW") == [0, "NEW", 2]
  end

  test "using seq" do
    lens = V2.seq(V2.at(0), V2.at(1))
    container = [[0, 1, 2], [], []]
    assert Derply.update(container, lens, &inspect/1) == [[0, "1", 2], [], []]
  end

  test "longer" do
    container = [
                  [0],
                  [
                    [00],
                    [11],
                    [
                      :---,
                      :---,
                      :---,
                       333
                    ],
                  [33]
                 ],
                 [2],
                 [3]
               ]
    expected = [
                  [0],
                  [
                    [00],
                    [11],
                    [
                      :---,
                      :---,
                      :---,
                      3330033300333
                    ],
                  [33]
                 ],
                 [2],
                 [3]
               ]
    lens = V2.seq(V2.at(1), V2.seq(V2.at(2), V2.at(3)))
    assert Derply.update(container, lens, & &1 * 10000100001) == expected
  end

  test "all" do
    nested = [ [0, 1, 2], [0, 1111, 2222]]
    lens = V2.seq(V2.all(), V2.at(1))
    assert Derply.update(nested, lens, &inspect/1) == [ [0, "1", 2], [0, "1111", 2222]]
  end
end
