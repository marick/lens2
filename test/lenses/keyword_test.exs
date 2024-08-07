defmodule Lens2.Lenses.KeywordTest do
  use Lens2.Case, async: true
  alias Lens2.Helpers.AssertionError

  doctest Lens2.Lenses.Keyword

  test "atom assertion" do
    assert_raise AssertionError, "key?/1 takes an atom as its argument.", fn ->
      Lens.Keyword.key?(3)
    end
  end

end
