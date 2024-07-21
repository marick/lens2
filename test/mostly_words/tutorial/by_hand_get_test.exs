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
    getter = fn value -> value end
    lens.(container, getter)
  end

  def seq(lens1, lens2) do
    fn lens1_container, lens2_descender ->
      lens1_descender =
        fn lens2_container -> lens2.(lens2_container, lens2_descender) end

      gotten =
        lens1.(lens1_container, lens1_descender)

      Enum.concat(gotten)
    end
  end



  test "all" do
    nested = [ [0, 1, 2], [00, 11, 22]]
    lens = Lens.all |> Lens.at(1)
    Deeply.get_all(nested, lens)
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
