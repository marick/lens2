defmodule Lens2.Lens1.Facade do
  @moduledoc """
  `Use` this module to get the API of the original `Lens` package.

  Used to run the old tests.

  Note this runs the old tests against `Deeply.*` and `Lens.Lenses.*`, not against
  the actual Lens1 code.
  """

  defmacro __using__(_opts \\ []) do
    quote do
      alias Lens2.Lens1.Facade, as: Lens1
      import Lens2.Deflens
    end
  end

  use Lens2.Lenses.Use

  alias Lens2.Deeply

  @opaque t :: (:get, any, function -> list(any)) | (:get_and_update, any, function -> {list(any), any})

  @doc ~S"""
  Returns an updated version of the data and a transformed value from each location the lens focuses on. The
  transformation function must return a tuple `{value_to_return, value_to_update}`.

      iex> data = %{a: 1, b: 2, c: 3}
      iex> Lens.keys([:a, :b, :c])
      ...> |> Lens.filter(&Integer.is_odd/1)
      ...> |> Lens.get_and_map(data, fn v -> {v + 1, v + 10} end)
      {[2, 4], %{a: 11, b: 2, c: 13}}
  """
  @spec get_and_map(t, any, (any -> {any, any})) :: {list(any), any}
  def get_and_map(lens, data, fun),
      do: Deeply.get_and_update(data, lens, fun)

  @doc ~S"""
  Returns a list of values that the lens focuses on in the given data.

      iex> Lens.keys([:a, :c]) |> Lens.to_list(%{a: 1, b: 2, c: 3})
      [1, 3]
  """
  @spec to_list(t, any) :: list(any)
  def to_list(lens, data),
      do: Deeply.to_list(data, lens)

  @doc ~S"""
  Performs a side effect for each values this lens focuses on in the given data.

      iex> data = %{a: 1, b: 2, c: 3}
      iex> fun = fn -> Lens.keys([:a, :c]) |> Lens.each(data, &IO.inspect/1) end
      iex> import ExUnit.CaptureIO
      iex> capture_io(fun)
      "1\n3\n"
  """
  @spec each(t, any, (any -> any)) :: :ok
  def each(lens, data, fun),
      do: Deeply.each(data, lens, fun)

  @doc ~S"""
  Returns an updated version of the data by applying the given function to each value the lens focuses on and building
  a data structure of the same shape with the updated values in place of the original ones.

      iex> data = [1, 2, 3, 4]
      iex> Lens.all() |> Lens.filter(&Integer.is_odd/1) |> Lens.map(data, fn v -> v + 10 end)
      [11, 2, 13, 4]
  """
  @spec map(t, any, (any -> any)) :: any
  def map(lens, data, fun),
      do: Deeply.update(data, lens, fun)

  @doc ~S"""
  Returns an updated version of the data by replacing each spot the lens focuses on with the given value.

      iex> data = [1, 2, 3, 4]
      iex> Lens.all() |> Lens.filter(&Integer.is_odd/1) |> Lens.put(data, 0)
      [0, 2, 0, 4]
  """
  @spec put(t, any, any) :: any
  def put(lens, data, value),
      do: Deeply.put(data, lens, value)

  @doc ~S"""
  Executes `to_list` and returns the single item that the given lens focuses on for the given data. Crashes if there
  is more than one item.
  """
  @spec one!(t, any) :: any
  def one!(lens, data) do
    [result] = to_list(lens, data)
    result
  end
end
