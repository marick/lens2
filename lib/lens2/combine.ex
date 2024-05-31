defmodule Lens2.Combine do
  import Lens2.Macros

  @opaque lens :: function

  @doc ~S"""
  Select the lens to use based on a matcher function

      iex> selector = fn
      ...>   {:a, _} -> Lens2.at(1)
      ...>   {:b, _, _} -> Lens2.at(2)
      ...> end
      iex> Lens2.match(selector) |> Lens2.one!({:b, 2, 3})
      3
  """
  @spec match((any -> lens)) :: lens
  deflens_raw match(matcher_fun) do
    fn data, fun ->
      get_and_map(matcher_fun.(data), data, fun)
    end
  end

  ### T#EMPe
  defp get_and_map(lens, data, fun), do: get_and_update_in(data, [lens], fun)



end
