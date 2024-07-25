defmodule Lens2.MostlyText.ByHandUpdateTest do
  use Lens2.Case, async: true

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
      updated = descender.(Map.get(container, key))
      Map.put(container, key, updated)
    end
  end


  def update(container, lens, update_fn) do
    lens.(container, update_fn)
  end

  def put(container, lens, constant) do
    lens.(container, fn _ -> constant end)
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

  test "at called alone" do
    lens = at(1)
    assert update([0, 1, 2], lens, &inspect/1) == [0, "1", 2]
    assert put([0, 1, 2], lens, "NEW") == [0, "NEW", 2]
  end

  test "using seq" do
    lens = seq(at(0), at(1))
    container = [[0, 1, 2], [], []]
    assert update(container, lens, &inspect/1) == [[0, "1", 2], [], []]
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
    lens = seq(at(1), seq(at(2), at(3)))
    assert update(container, lens, & &1 * 10000100001) == expected
  end

  test "all" do
    nested = [ [0, 1, 2], [0, 1111, 2222]]
    lens = seq(all(), at(1))
    assert update(nested, lens, &inspect/1) == [ [0, "1", 2], [0, "1111", 2222]]
  end


end
