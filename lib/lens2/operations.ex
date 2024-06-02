defmodule Lens2.Operations do

  @type lens :: Access.access_fun

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

  @doc ~S"""
  Returns a list of values that the lens focuses on in the given data.

      iex> Lens2.keys([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2, c: 3})
      [1, 3]
  """
  @spec to_list(lens, any) :: list(any)
  def to_list(lens, data), do: get_in(data, [lens])

  @doc ~S"""
  Performs a side effect for each values this lens focuses on in the given data.

      iex> data = %{a: 1, b: 2, c: 3}
      iex> fun = fn -> Lens2.keys([:a, :c]) |> Lens2.each(data, &IO.inspect/1) end
      iex> import ExUnit.CaptureIO
      iex> capture_io(fun)
      "1\n3\n"
  """
  @spec each(lens, any, (any -> any)) :: :ok
  def each(lens, data, fun), do: to_list(lens, data) |> Enum.each(fun)

  @doc ~S"""
  Returns an updated version of the data by applying the given function to each value the lens focuses on and building
  a data structure of the same shape with the updated values in place of the original ones.

      iex> data = [1, 2, 3, 4]
      iex> Lens2.all() |> Lens2.filter(&Integer.is_odd/1) |> Lens2.map(data, fn v -> v + 10 end)
      [11, 2, 13, 4]
  """
  @spec map(lens, any, (any -> any)) :: any
  def map(lens, data, fun), do: update_in(data, [lens], fun)

  @doc ~S"""
  Returns an updated version of the data by replacing each spot the lens focuses on with the given value.

      iex> data = [1, 2, 3, 4]
      iex> Lens2.all() |> Lens2.filter(&Integer.is_odd/1) |> Lens2.put(data, 0)
      [0, 2, 0, 4]
  """
  @spec put(lens, any, any) :: any
  def put(lens, data, value), do: put_in(data, [lens], value)

  @doc ~S"""
  Executes `to_list` and returns the single item that the given lens focuses on for the given data. Crashes if there
  is more than one item.
  """
  @spec one!(lens, any) :: any
  def one!(lens, data) do
    [result] = to_list(lens, data)
    result
  end
end
