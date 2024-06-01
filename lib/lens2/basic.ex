defmodule Lens2.Basic do
  import Lens2.Macros

  @opaque lens :: function

  @doc ~S"""
  Returns a lens that yields the entirety of the data currently under focus.

      iex> Lens2.to_list(Lens2.root, :data)
      [:data]
      iex> Lens2.map(Lens2.root, :data, fn :data -> :other_data end)
      :other_data
      iex> Lens2.key(:a) |> Lens2.both(Lens2.root, Lens2.key(:b)) |> Lens2.to_list(%{a: %{b: 1}})
      [%{b: 1}, 1]
  """
  @spec root :: lens
  deflens_raw root do
    fn data, fun ->
      {res, updated} = fun.(data)
      {[res], updated}
    end
  end


  @doc ~S"""
  Returns a lens that does not focus on any part of the data.

      iex> Lens2.empty |> Lens2.to_list(:anything)
      []
      iex> Lens2.empty |> Lens2.map(1, &(&1 + 1))
      1
  """
  @spec empty :: lens
  deflens_raw empty, do: fn data, _fun -> {[], data} end


  @doc ~S"""
  Returns a lens that ignores the data and always focuses on the given value.

      iex> Lens2.const(3) |> Lens2.one!(:anything)
      3
      iex> Lens2.const(3) |> Lens2.map(1, &(&1 + 1))
      4
      iex> import Integer
      iex> lens = Lens2.keys([:a, :b]) |> Lens2.match(fn v -> if is_odd(v), do: Lens2.root, else: Lens2.const(0) end)
      iex> Lens2.map(lens, %{a: 11, b: 12}, &(&1 + 1))
      %{a: 12, b: 1}
  """
  @spec const(any) :: lens
  deflens_raw const(value) do
    fn _data, fun ->
      {res, updated} = fun.(value)
      {[res], updated}
    end
  end

  @doc ~S"""
  Returns a lens that focuses on all the values in an enumerable.

      iex> Lens2.all |> Lens2.to_list([1, 2, 3])
      [1, 2, 3]

  Does work with updates but produces a list from any enumerable by default:

      iex> Lens2.all |> Lens2.map(MapSet.new([1, 2, 3]), &(&1 + 1))
      [2, 3, 4]

  See [into](#into/2) on how to rectify this.
  """
  @spec all :: lens
  deflens_raw all do
    fn data, fun ->
      {res, updated} =
        Enum.reduce(data, {[], []}, fn item, {res, updated} ->
          {res_item, updated_item} = fun.(item)
          {[res_item | res], [updated_item | updated]}
        end)

      {Enum.reverse(res), Enum.reverse(updated)}
    end
  end

  @doc ~S"""
  Returns a lens that does not change the focus of of the given lens, but puts the results into the given collectable
  when updating.

      iex> Lens2.into(Lens2.all(), MapSet.new) |> Lens2.map(MapSet.new([-2, -1, 1, 2]), &(&1 * &1))
      MapSet.new([1, 4])

  Notice that collectable composes in a somewhat surprising way, for example:

      iex> Lens2.map_values() |> Lens2.all() |> Lens2.into(%{}) |>
      ...>   Lens2.map(%{key1: %{key2: :value}}, fn {k, v} -> {v, k} end)
      %{key1: [{:value, :key2}]}

  To prevent this, avoid using `|>` with `into`:

      iex> Lens2.map_values() |> Lens2.into(Lens2.all(), %{}) |>
      ...>   Lens2.map(%{key1: %{key2: :value}}, fn {k, v} -> {v, k} end)
      %{key1: %{value: :key2}}
  """
  @spec into(lens, Collectable.t()) :: lens
  deflens_raw into(lens, collectable) do
    fn data, fun ->
      {res, updated} = get_and_map(lens, data, fun)
      {res, Enum.into(updated, collectable)}
    end
  end

  @doc ~S"""
  Returns a lens that focuses on a subset of elements focused on by the given lens that satisfy the given condition.

      iex> Lens2.map_values() |> Lens2.filter(&Integer.is_odd/1) |> Lens2.to_list(%{a: 1, b: 2, c: 3, d: 4})
      [1, 3]
  """
  @spec filter(lens, (any -> boolean)) :: lens
  def filter(predicate), do: Lens2.root() |> filter(predicate)

  deflens_raw filter(lens, predicate) do
    fn data, fun ->
      {res, changed} =
        get_and_map(lens, data, fn item ->
          if predicate.(item) do
            {res, changed} = fun.(item)
            {[res], changed}
          else
            {[], item}
          end
        end)

      {Enum.concat(res), changed}
    end
  end

  # TODO: why is reject's definition not parallel to filter, with the one-arity case?

  @doc ~S"""
  Returns a lens that focuses on a subset of elements focused on by the given lens that don't satisfy the given
  condition.

      iex> Lens2.map_values() |> Lens2.reject(&Integer.is_odd/1) |> Lens2.to_list(%{a: 1, b: 2, c: 3, d: 4})
      [2, 4]
  """
  @spec reject(lens, (any -> boolean)) :: lens
  def reject(lens, predicate), do: filter(lens, &(not predicate.(&1)))


  ### T#EMPe
  defp get_and_map(lens, data, fun), do: get_and_update_in(data, [lens], fun)



end
