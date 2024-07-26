defmodule Lens2.MostlyText.ByHandGetAndUpdateTest do
  use Lens2.Case, async: true

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

  def get_all(container, lens) do
    descender = & {&1, &1}
    {gotten, _} = lens.(container, descender)
    gotten
  end

  def update(container, lens, update_fn) do
    descender = fn deeper_container ->
      { deeper_container, update_fn.(deeper_container) }
    end

    {_, updated} = lens.(container, descender)
    updated
  end

  def seq(outer_lens, inner_lens) do
    fn outer_container, inner_descender ->
      outer_descender =
        fn inner_container ->
          inner_lens.(inner_container, inner_descender)
        end

      {gotten, updated} =
        outer_lens.(outer_container, outer_descender)

      :erts_debug.same(outer_container, updated)
      {Enum.concat(gotten), updated}
    end
  end

  def all do
    fn container, descender ->
      pairs =
        for item <- container, do: descender.(item)
      Enum.unzip(pairs)
    end
  end

  test "at called alone" do
    lens = at(1)
    assert get_all([0, 1, 2], lens) == [1]
    assert update([0, 1, 2], lens, &inspect/1) == [0, "1", 2]
  end

  test "using seq" do
    lens = seq(at(0), at(1))
    container = [[0, 1, 2], [], []]
    assert get_all(container, lens) == [1]
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
    assert get_all(container, lens) == [333]
    assert update(container, lens, & &1 * 10000100001) == expected
  end

  test "all" do
    nested = [ [0, 1, 2], [0, 1111, 2222], [:a, :b, :c] ]
    lens = seq(all(), at(1))
    assert get_all(nested, lens) == [ 1, 1111, :b]

    actual = update(nested, lens, &inspect/1)
    assert actual == [ [0, "1", 2], [0, "1111", 2222], [:a, ":b", :c]]
  end

  test "all - real" do
    nested = [ [0, 1, 2], [0, 1111, 2222], [:a, :b, :c] ]
    lens = Lens.all |> Lens.at(1)
    assert Deeply.get_all(nested, lens) == [ 1, 1111, :b]
    actual = Deeply.update(nested, lens, &inspect/1)
    assert actual == [ [0, "1", 2], [0, "1111", 2222], [:a, ":b", :c]]
  end


end
