defmodule Lens2.Lenses.Enum do
  @moduledoc """
  Lenses that work on `Enumerable` and `Collectable` containers.
  """
  use Lens2.Makers
  alias Lens2.Deeply

  @doc ~S"""
  Given a pointer to an enumerable, return a lens that points to all its elements.

      iex> Deeply.get_all([0, 1, 2], Lens.all)
      [0, 1, 2]
      iex> Deeply.update([0, 1, 2], Lens.all, &inspect/1)
      ["0", "1", "2"]

  Note that order is preserved for enumerables where that makes sense
  (lists, but not maps, for example).

  `update` and `put` always produce a list. Consider applying `all` to
  a map. The values pointed to are `{key, value}` tuples:

      iex> Deeply.get_all(%{1 => 100, 4 => 400}, Lens.all) |> Enum.sort
      [{1, 100}, {4, 400}]

  Updating the values can be done by composing `all/0` with `Lens2.Lenses.Indexed.at/1`:

      iex> lens = Lens.all |> Lens.at(1)
      iex> Deeply.update(%{1 => 100, 4 => 400}, lens, &inspect/1) |> Enum.sort
      [{1, "100"}, {4, "400"}]

  The result could be "poured" into a map using `Enum.into`:

      iex> %{1 => 100, 4 => 400}
      ...> |> Deeply.update(Lens.all |> Lens.at(1), &inspect/1)
      ...> |> Enum.into(%{})
      %{1 => "100", 4 => "400"}

  There is also a lens-maker that has the same effect:

      iex> lens = Lens.into(Lens.all |> Lens.at(1), %{})
      iex> %{1 => 100, 4 => 400}
      ...> |> Deeply.update(lens, &inspect/1)

  In this particular case, it would work equally well to pipe into `into/1`:

      iex> lens = Lens.all |> Lens.at(1) |> Lens.into(%{})
      iex> %{1 => 100, 4 => 400}
      ...> |> Deeply.update(lens, &inspect/1)
      %{1 => "100", 4 => "400"}

  But see the `into/1` documentation for why such piping is error-prone.

  `into/1` is used by datatype-specific lens-makers, such as those in
  `Lens2.Lenses.Keyed` and `Lens2.Lenses.MapSet`, to produce the right
  result type for updates.

  Note the lens produced by `all/0` works on lists but not tuples, and
  on maps but not structs. Neither of the latter two implement
  protocol `Enumerable`.

  """
  @spec all :: Lens2.lens
  def_maker all do
    fn container, descender ->
      {gotten, updated} =
        Enum.reduce(container, {[], []}, fn item, {gotten, updated} ->
          {gotten_item, updated_item} = descender.(item)
          {[gotten_item | gotten], [updated_item | updated]}
        end)

      {Enum.reverse(gotten), Enum.reverse(updated)}
    end
  end

  @doc ~S"""
  On `update` and `put`, puts the result into a given `Collectable`. No effect on `get_all`.


  Here's an example of using `into` to update the values of a `Range`
  and put them `into` a `MapSet`:

       iex> Deeply.update(0..5, Lens.all |> Lens.into(MapSet.new), &inspect/1)
       MapSet.new(["0", "1", "2", "3", "4", "5"])

  However, it's tricksy to use `into/1` in a pipeline. The above lens is more safely written
  as:

       Lens.into(Lens.all, MapSet.new)

  You can just take my word for it, but if you'd like to understand why, read on.

  ### The Why

  Suppose we've successfully used the pipeline form above, but now we come upon
  ranges within a map:

       %{a: 0..2, b: 3..4}

  We want to explode all the interior ranges into MapSets of strings to get something like
  this:

      %{a: MapSet.new(["0", "1", "2"]),
        b: MapSet.new(["3", "4"])}

  Copy and paste the previous solution, prepend a
  `Lens2.Lenses.Keyed.map_values/0`, and we're golden, right?

      iex> lens = Lens.map_values |> Lens.all |> Lens.into(MapSet.new)
      iex> Deeply.update(%{a: 0..2, b: 3..4}, lens, &inspect/1)
      %MapSet{map: %{{:a, ["0", "1", "2"]} => [], {:b, ["3", "4"]} => []}}

  Um, what?

  The problem is that the `into/1` is the last thing done. It works on the *entire* updated
  container. It, in effect, does this:

      iex> updated =
      ...>   Deeply.update(%{a: 0..2, b: 3..4},
      ...>                 Lens.map_values |> Lens.all,
      ...>                 &inspect/1)
      %{a: ["0", "1", "2"], b: ["3", "4"]}
      iex> updated |> Enum.into(MapSet.new)
      %MapSet{map: %{{:a, ["0", "1", "2"]} => [], {:b, ["3", "4"]} => []}}

  In our case, we want the `into` to take place on intermediate containers, so we
  need to wrap the `into/2` around only the relevant parts of the pipeline, like this:

      iex> lens = Lens.map_values |> Lens.into(Lens.all, MapSet.new)
      iex> Deeply.update(%{a: 0..2, b: 3..4}, lens, &inspect/1)
      %{a: MapSet.new(["0", "1", "2"]),
        b: MapSet.new(["3", "4"])}

  Alternately, we could make the separation like this.

      iex> lens = Lens.seq(Lens.map_values, Lens.all |> Lens.into(MapSet.new))
      iex> Deeply.update(%{a: 0..2, b: 3..4}, lens, &inspect/1)
      %{a: MapSet.new(["0", "1", "2"]),
        b: MapSet.new(["3", "4"])}
  """
  @spec into(Lens2.lens, Collectable.t()) :: Lens2.lens
  def_maker into(lens, collectable) do
    fn container, descender ->
      {gotten, updated} = Deeply.get_and_update(container, lens, descender)
      {gotten, Enum.into(updated, collectable)}
    end
  end

end
