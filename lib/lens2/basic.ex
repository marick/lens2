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


end
