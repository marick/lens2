defmodule Lens2.Operations do
  # import Lens2.Macros

  @opaque lens :: function

  @doc ~S"""
  Returns an updated version of the data and a transformed value from each location the lens focuses on. The
  transformation function must return a tuple `{value_to_return, value_to_update}`.

      iex> data = %{a: 1, b: 2, c: 3}
      iex> Lens2.keys([:a, :b, :c])
      ...> |> Lens2.filter(&Integer.is_odd/1)
      ...> |> Lens2.get_and_map(data, fn v -> {v + 1, v + 10} end)
      {[2, 4], %{a: 11, b: 2, c: 13}}
  """
  @spec get_and_map(lens, any, (any -> {any, any})) :: {list(any), any}
  def get_and_map(lens, data, fun), do: get_and_update_in(data, [lens], fun)


end
