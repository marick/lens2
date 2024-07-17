defmodule Lens2.Lenses.MapSet do
  @moduledoc """
  Lenses that work with `MapSet` structures.
  """

  use Lens2

  @doc """
  Like `Lens.all/0`, but intended for use with a MapSet.

  `all` is pointless without other lenses appended to look
  deeper into the nested structure.

  Consider this lens and this data:

       lens =
         Lens.MapSet.all |> Lens.key?(:a)
       input =
         MapSet.new([%{a: 1}, %{a: 2}, %{a: 3}, %{vvvv: "unchanged"}])

  You can now increment the values of all the `:a` values like this:

       Deeply.update(input, lens, & &1*100)
       > MapSet.new([%{a: 100}, %{a: 200}, %{a: 300}, %{vvvv: "unchanged"}])

  Note that the question mark in `Lens.key?` is required, else the
  multiplication function will be called on `nil`.

  `all` also works reasonably well with `put`. Given the above
  `input` mapset and `lens`,

       Deeply.put(input, lens, 3)

  ... will produce:

       MapSet.new([%{a: 3}, %{vvvv: "unchanged"}]

  Note that the multiple maps with now-identical `:a` values have
  been correctly collapsed into one.

  As is typical for `Lens`, `get` functions return lists rather than
  the base type:

       Deeply.get_all(input, lens)
       > [1, 2, 3]    # *not* MapSet.new([1, 2, 3])

  """

  deflens all(), do: Lens.into(Lens.all, MapSet.new)
end
