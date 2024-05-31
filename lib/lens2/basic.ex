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


end
