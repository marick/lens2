defmodule Lens2.Lenses.EnumTest do
  use Lens2.Case, async: true

  doctest Lens2.Lenses.Enum


  describe "all/0" do
    test "typical" do
      [1, 2, 3] |> Deeply.get_all(Lens.all)
      |> assert_equals([1, 2, 3])

      %{:a => 1, 3 => 4} |> Deeply.get_all(Lens.all) |> Enum.sort
      |> assert_equals([{3, 4}, {:a, 1}])

      [1, 2, 3] |> Deeply.update(Lens.all, & &1+1)
      |> assert_equals([2, 3, 4])

      %{:a => 1, 3 => 4} |> Deeply.update(Lens.all, fn
        {k, v} when is_atom(k) -> {k, v * 1000}
        {k, v}                 -> {k+1, v * 2}
      end)
      |> Enum.sort
      |> assert_equals([{4, 8}, {:a, 1000}])
    end

    @tag :skip
    test "all/0 now works with tuples" do
      # Dunno if I want to do this. It's not hard to convert tuples to
      # lists and structs to maps, but the reverse conversion (usually
      # done with Lens.into) becomes a puzzle.

      {1, 2} |> Deeply.get_all(Lens.all)
      |> assert_equals([1, 2])

      {1, 2} |> Deeply.get_all(Lens.all |> Lens.into({})) |> dbg
    end
  end


end
