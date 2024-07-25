defmodule Lens2.MostlyText.ByHandGetTest do
  use Lens2.Case, async: true

  @type container :: any
  @type descender :: (container -> any)
  @type get_lens :: (container, descender -> [any])

  @spec at(non_neg_integer) :: get_lens
  def at(index) do
    fn container, descender ->
      gotten = descender.(Enum.at(container, index))
      [gotten]
    end
  end

  def get_all(container, lens) do
    getter = & &1    # Just return the leaf value
    lens.(container, getter)
  end

  def seq(outer_lens, inner_lens) do
    fn outer_container, inner_descender ->
      outer_descender =                                  # <<
        fn inner_container ->                            # <<
          inner_lens.(inner_container, inner_descender)  # <<
        end                                              # <<

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

  test "all" do
    nested = [ [0, 1, 2], [0, 1111, 2222]]
    lens = seq(all(), at(1))
    assert get_all(nested, lens) == [1, 1111]
  end


  test "at called alone" do
    lens = at(1)
    assert get_all(["0", "1", "2"], lens) == ["1"]
    # assert get_in(["0", "1", "2"], [lens]) == ["1"]
  end

  test "using real seq" do
    lens = Lens.seq(Lens.at(0), Lens.at(1))
    assert get_in([["0", "1", "2"], [], []], [lens]) == ["1"]
  end


  test "using seq" do
    lens = seq(at(0), at(1))
    assert get_all([["0", "1", "2"], [], []], lens) == ["1"]
  end

end