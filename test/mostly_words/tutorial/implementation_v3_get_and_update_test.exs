defmodule Lens2.MostlyText.ImplementationV3GetAndUpdateTest do
  use Lens2.Case, async: true


  defmodule V3 do
    def at(index) do
      fn container, descender ->
        {gotten, updated} =
          Enum.at(container, index)
          |> descender.()

        {[gotten],
         List.replace_at(container, index, updated)
        }
      end
    end

    def seq(outer_lens, inner_lens) do
      fn outer_container, inner_descender ->
        outer_descender =
          fn inner_container ->
            inner_lens.(inner_container, inner_descender)
          end

        {gotten, updated} =
          outer_lens.(outer_container, outer_descender)

        {Enum.concat(gotten), updated}
      end
    end

    # No change needed
    def all do
      fn container, descender ->
        pairs =
          for item <- container, do: descender.(item)
        Enum.unzip(pairs)
      end
    end
  end

  defmodule Derply do
    def get_and_update(container, lens, tuple_returner) do
      lens.(container, tuple_returner)
    end

    def update(container, lens, update_fn) do
      tuple_returner = & {&1, update_fn.(&1)}
      {_, updated} = get_and_update(container, lens, tuple_returner)
      updated
    end

    def get_all(container, lens) do
      tuple_returner = & {&1, &1}
      {gotten, _} = get_and_update(container, lens, tuple_returner)
      gotten
    end
  end



  test "at called alone" do
    lens = V3.at(1)
    container = [0, 1, 2]
    expected = { [1], [0, "1", 2] }
    tuple_returner = & {&1, inspect(&1)}

    assert Deeply.get_and_update(container, Lens.at(1), tuple_returner) == expected
    assert Derply.get_and_update(container, lens, tuple_returner) == expected
    assert Derply.update(container, lens, &inspect/1) == elem(expected, 1)
    assert Derply.get_all(container, lens) == elem(expected, 0)
  end

  test "using seq" do
    lens = V3.seq(V3.at(0), V3.at(1))
    container = [[0, 1, 2], [], []]
    expected = { [1], [[0, "1", 2], [], []] }
    tuple_returner = & {&1, inspect(&1)}

    assert Derply.get_and_update(container, lens, tuple_returner) == expected
    assert Derply.update(container, lens, &inspect/1) == elem(expected, 1)
    assert Derply.get_all(container, lens) == elem(expected, 0)
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
    lens = V3.seq(V3.at(1), V3.seq(V3.at(2), V3.at(3)))

    assert Derply.get_and_update(container, lens, & {&1, &1 * 10000100001}) == {[333], expected}
    assert Derply.update(container, lens, & &1 * 10000100001) == expected
    assert Derply.get_all(container, lens) == [333]
  end

  test "all" do
    container = [ [0, 1, 2], [0, 1111, 2222], [:a, :b, :c] ]
    expected = [ [0, "1", 2], [0, "1111", 2222], [:a, ":b", :c]]
    lens = V3.seq(V3.all(), V3.at(1))
    tuple_returner = & {&1, inspect(&1)}

    assert Derply.get_and_update(container, lens, tuple_returner) == { [ 1, 1111, :b], expected}
    assert Derply.update(container, lens, &inspect/1) == expected
    assert Derply.get_all(container, lens) == [ 1, 1111, :b]
  end
end
