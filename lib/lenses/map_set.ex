defmodule Lens2.Lenses.MapSet do
  @moduledoc """
  Lenses that work with `MapSet` structures.
  """

  use Lens2
  alias Lens2.Helpers.DefOps

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

  @spec all() :: Lens2.lens
  defmaker all(),
    do: Lens.update_into(MapSet.new, Lens.all)


  @doc """
  Make a lens that points at elements satisfying a predicate.

  Here is how you might increment all the even values of a `MapSet`:

      iex> import Integer, only: [is_even: 1]
      iex> container = MapSet.new([-1, 0, 1, 2])
      iex> Deeply.update(container, Lens.MapSet.is(&is_even/1), & &1+1)
      MapSet.new([-1, 1, 3])  # Note that duplicate 1 has been removed.
  """
  @spec is( (Lens2.value -> boolean) ) :: Lens2.lens
  defmaker is(predicate),
    do: all() |> Lens.filter(predicate)


  @doc """
  Make a lens that points at elements containing a particular key/value pair.

  A `MapSet` might contain a struct or other `Access`-compatible container,
  such as a map or struct. A lens created by this maker will select all elements
  with a given key that matches the given value:

      iex> container = MapSet.new([%{name: "bullwinkle"}, %{name: "rocky"}])
      iex> Deeply.get_all(container, Lens.MapSet.has!(name: "rocky"))
      [%{name: "rocky"}]

  Here, I get all the names from a keyword list that are associated with the value
  `2`:

      iex> container = [ [name: "bullwinkle", val: 1],
      ...>               [name: "rocky",      val: 2],
      ...>               [name: "natasha",    val: 2]] |> MapSet.new
      iex> lens = Lens.MapSet.has!(val: 2) |> Lens.key(:name)
      iex> Deeply.get_all(container, lens) |> Enum.sort
      ["natasha", "rocky"]

  As the exclamation point suggests, an error is raised if any of the
  elements doesn't have the given key.

  Structs are not required to implement the `Access` callback
  functions. (Indeed, even if it does implement `Access.fetch/2`,
  that's not used.)

  """
  @spec has!(keyword(any)) :: Lens2.lens
  defmaker has!([{key, value}]) do
    predicate =
      fn element ->
        DefOps.fetch!(element, key) == value
      end
    is(predicate)
  end
end
