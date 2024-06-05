defmodule Lens2.Lenses.Keyed do
  @moduledoc """
  Lenses helpful for working with structs, `Map`s, and `Keyword` lists.

  Although these lenses can be used with `Keyword` list, beware that -- for compatibility
  with `Access` -- many of them point only to the *first* matching key:

      iex(1)> use Lens2
      iex(2)> keylist = [a: 1, other: 2, a: 3]
      iex(3)> Deeply.to_list(keylist, Lens.key(:a))
      [1]         # not [1, 3]
      iex(4)> Deeply.to_list(keylist, Lens.keys([:a, :other]))
      [1, 2]      # not [1, 2, 3]

  See the `Lens2.Lenses.Keyword` module for an alternative.

  These lenses are available under the `Lens` alias when you `use Lens2`.

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
