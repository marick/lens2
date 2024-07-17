defmodule Lens2.Lenses.MapSet do
  @moduledoc """
  Lenses that work with `MapSet` structures.
  """

  use Lens2

  @doc """
  Like `Lens.all/0`, but intended for use with a `MapSet`.

  Here's how to update the `:a` values in a `MapSet` of maps:

       iex> lens = Lens.MapSet.all |> Lens.key?(:a)
       iex> container = MapSet.new([%{a: 1}, %{a: 2}, %{a: 3}])
       iex> Deeply.update(container, lens, & &1*100)
       MapSet.new([%{a: 100}, %{a: 200}, %{a: 300}])

  `all` also works reasonably well with `put`. Given the above
  container and lens,

       Deeply.put(container, lens, 3)

  ... will produce:

       MapSet.new([%{a: 3}]

  Note that the multiple maps with now-identical `:a` values have
  been correctly collapsed into one. (MapSets can't have duplicates.)

  As normal, `get` functions return lists rather than MapSets:

       Deeply.get_all(container, lens)
       > [1, 2, 3]    # *not* MapSet.new([1, 2, 3])

  """

  deflens all(), do: Lens.into(Lens.all, MapSet.new)
end
