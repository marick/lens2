defmodule Lens2.Maplike do
  import Lens2.Macros
  alias Lens2.Helpers.DefOps
  alias Lens2.{Basic,Combine,Listlike}

  @doc ~S"""
  Returns a lens that focuses on the value under `key`.

      iex> Lens2.to_list(Lens2.key(:foo), %{foo: 1, bar: 2})
      [1]
      iex> Lens2.map(Lens2.key(:foo), %{foo: 1, bar: 2}, fn x -> x + 10 end)
      %{foo: 11, bar: 2}

  If the key doesn't exist in the map a nil will be returned or passed to the update function.

      iex> Lens2.to_list(Lens2.key(:foo), %{})
      [nil]
      iex> Lens2.map(Lens2.key(:foo), %{}, fn nil -> 3 end)
      %{foo: 3}
  """

  @opaque lens :: function

  @spec key(any) :: lens
  deflens_raw key(key) do
    fn data, fun ->
      {res, updated} = fun.(DefOps.get(data, key))
      {[res], DefOps.put(data, key, updated)}
    end
  end

  @doc ~S"""
  Returns a lens that focuses on the value under the given key. If the key does not exist an error will be raised.

      iex> Lens2.key!(:a) |> Lens2.one!(%{a: 1, b: 2})
      1
      iex> Lens2.key!(:a) |> Lens2.one!([a: 1, b: 2])
      1
      iex> Lens2.key!(:c) |> Lens2.one!(%{a: 1, b: 2})
      ** (KeyError) key :c not found in: %{a: 1, b: 2}
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

      iex> Lens2.key?(:a) |> Lens2.to_list(%{a: 1, b: 2})
      [1]
      iex> Lens2.key?(:a) |> Lens2.to_list([a: 1, b: 2])
      [1]
      iex> Lens2.key?(:c) |> Lens2.to_list(%{a: 1, b: 2})
      []
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

      iex> Lens2.keys([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2, c: 3})
      [1, 3]
      iex> Lens2.keys([:a, :c]) |> Lens2.map([a: 1, b: 2, c: 3], &(&1 + 1))
      [a: 2, b: 2, c: 4]

  If any of the keys doesn't exist the update function will receive a nil.

      iex> Lens2.keys([:a, :c]) |> Lens2.map(%{a: 1, b: 2}, fn nil -> 3; x -> x end)
      %{a: 1, b: 2, c: 3}
  """
  @spec keys(nonempty_list(any)) :: lens
  deflens keys(keys), do: keys |> Enum.map(&key/1) |> Combine.multiple

  @doc ~S"""
  Returns a lens that focuses on the values of all the keys. If any of the keys does not exist, an error is raised.

      iex> Lens2.keys!([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2, c: 3})
      [1, 3]
      iex> Lens2.keys!([:a, :c]) |> Lens2.map([a: 1, b: 2, c: 3], &(&1 + 1))
      [a: 2, b: 2, c: 4]
      iex> Lens2.keys!([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2})
      ** (KeyError) key :c not found in: %{a: 1, b: 2}
  """
  @spec keys!(nonempty_list(any)) :: lens
  deflens keys!(keys), do: keys |> Enum.map(&key!/1) |> Combine.multiple

  @doc ~S"""
  Returns a lens that focuses on the values of all the keys. If any of the keys does not exist, it is ignored.

      iex> Lens2.keys?([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2, c: 3})
      [1, 3]
      iex> Lens2.keys?([:a, :c]) |> Lens2.map([a: 1, b: 2, c: 3], &(&1 + 1))
      [a: 2, b: 2, c: 4]
      iex> Lens2.keys?([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2})
      [1]
  """
  @spec keys?(nonempty_list(any)) :: lens
  deflens keys?(keys), do: keys |> Enum.map(&key?/1) |> Combine.multiple

  @doc ~S"""
  Returns a lens that focuses on all values of a map.

      iex> Lens2.map_values() |> Lens2.to_list(%{a: 1, b: 2})
      [1, 2]
      iex> Lens2.map_values() |> Lens2.map(%{a: 1, b: 2}, &(&1 + 1))
      %{a: 2, b: 3}
  """
  @spec map_values :: lens
  deflens map_values, do: Basic.all() |> Basic.into(%{}) |> Listlike.at(1)

  @doc ~S"""
  Returns a lens that focuses on all keys of a map.

      iex> Lens2.map_keys() |> Lens2.to_list(%{a: 1, b: 2})
      [:a, :b]
      iex> Lens2.map_keys() |> Lens2.map(%{1 => :a, 2 => :b}, &(&1 + 1))
      %{2 => :a, 3 => :b}
  """
  @spec map_keys :: lens
  deflens map_keys, do: Basic.all() |> Basic.into(%{}) |> Listlike.at(0)
end
