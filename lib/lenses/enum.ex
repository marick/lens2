defmodule Lens2.Lenses.Enum do
  @moduledoc """
  Lenses that work on `Enumerable` and `Collectable` containers.
  """
  use Lens2.Makers

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

end
