defmodule Lens2.Lenses.Keyed do
  @moduledoc """
  Lenses helpful for working with `Map`s and `Keyword` lists.


  """
  use Lens2.Deflens
  alias Lens2.Helpers.DefOps
  alias Lens2.Lenses.{Basic,Combine,Indexed}

  @type lens :: Access.access_fun

  @doc ~S"""
  Returns a lens that focuses on the value under `key`.

  If the key doesn't exist in the map a nil will be returned or passed to the update function.

  """

  @spec key(any) :: lens
  deflens_raw key(key) do
    fn data, fun ->
      {res, updated} = fun.(DefOps.get(data, key))
      {[res], DefOps.put(data, key, updated)}
    end
  end

  @doc ~S"""
  Returns a lens that focuses on the value under the given key. If the key does not exist an error will be raised.

  """
  @spec key!(any) :: lens
  deflens_raw key!(key) do
    fn data, fun ->
      {res, updated} = fun.(DefOps.fetch!(data, key))
      {[res], DefOps.put(data, key, updated)}
    end
  end


  @doc ~S"""
  Returns a lens that focuses on the value under the given key. If they key does not exist it focuses on nothing.

  """
  @spec key?(any) :: lens
  deflens_raw key?(key) do
    fn data, fun ->
      case DefOps.fetch(data, key) do
        :error ->
          {[], data}

        {:ok, value} ->
          {res, updated} = fun.(value)
          {[res], DefOps.put(data, key, updated)}
      end
    end
  end

  @doc ~S"""
  Returns a lens that focuses on the values of all the keys.


  If any of the keys doesn't exist the update function will receive a nil.

  """
  @spec keys(nonempty_list(any)) :: lens
  deflens keys(keys), do: keys |> Enum.map(&key/1) |> Combine.multiple

  @doc ~S"""
  Returns a lens that focuses on the values of all the keys. If any of the keys does not exist, an error is raised.

  """
  @spec keys!(nonempty_list(any)) :: lens
  deflens keys!(keys), do: keys |> Enum.map(&key!/1) |> Combine.multiple

  @doc ~S"""
  Returns a lens that focuses on the values of all the keys. If any of the keys does not exist, it is ignored.

  """
  @spec keys?(nonempty_list(any)) :: lens
  deflens keys?(keys), do: keys |> Enum.map(&key?/1) |> Combine.multiple

  @doc ~S"""
  Returns a lens that focuses on all values of a map.

  """
  @spec map_values :: lens
  deflens map_values, do: Basic.all() |> Basic.into(%{}) |> Indexed.at(1)

  @doc ~S"""
  Returns a lens that focuses on all keys of a map.

  """
  @spec map_keys :: lens
  deflens map_keys, do: Basic.all() |> Basic.into(%{}) |> Indexed.at(0)
end
