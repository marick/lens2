defmodule Lens2 do
  use Lens2.Macros
  alias Lens2.{DefOps, Basic, Listlike}


  # I'm deliberately making this non-opaque because it's important people understand
  # that lenses are functions and that it's *lists* that are retrieved.
  @type t :: (:get, any, function -> list(any)) | (:get_kand_update, any, function -> {list(any), any})

  defdelegate root(), to: Basic

  defdelegate front(), to: Listlike
  defdelegate back(), to: Listlike
  defdelegate before(index), to: Listlike


  @doc ~S"""
  Returns a lens that does not focus on any part of the data.

      iex> Lens2.empty |> Lens2.to_list(:anything)
      []
      iex> Lens2.empty |> Lens2.map(1, &(&1 + 1))
      1
  """
  @spec empty :: t
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
  @spec const(any) :: t
  deflens_raw const(value) do
    fn _data, fun ->
      {res, updated} = fun.(value)
      {[res], updated}
    end
  end

  @doc ~S"""
  Select the lens to use based on a matcher function

      iex> selector = fn
      ...>   {:a, _} -> Lens2.at(1)
      ...>   {:b, _, _} -> Lens2.at(2)
      ...> end
      iex> Lens2.match(selector) |> Lens2.one!({:b, 2, 3})
      3
  """
  @spec match((any -> t)) :: t
  deflens_raw match(matcher_fun) do
    fn data, fun ->
      get_and_map(matcher_fun.(data), data, fun)
    end
  end

  @doc ~S"""
  Returns a lens that focuses on the n-th element of a list or tuple.

      iex> Lens2.at(2) |> Lens2.one!({:a, :b, :c})
      :c
      iex> Lens2.at(1) |> Lens2.map([:a, :b, :c], fn :b -> :d end)
      [:a, :d, :c]
  """
  @spec at(non_neg_integer) :: t
  deflens_raw at(index) do
    fn data, fun ->
      {res, updated} = fun.(DefOps.at(data, index))
      {[res], DefOps.put_at(data, index, updated)}
    end
  end

  @doc ~S"""
  An alias for `at`.
  """
  @spec index(non_neg_integer) :: t
  deflens index(index), do: at(index)

  @doc ~S"""
  Returns a lens that focuses on all of the supplied indices.

      iex> Lens2.indices([0, 2]) |> Lens2.to_list([:a, :b, :c])
      [:a, :c]
      iex> Lens2.indices([0, 2]) |> Lens2.map([1, 2, 3], &(&1 + 1))
      [2, 2, 4]
  """
  @spec indices([non_neg_integer]) :: t
  deflens indices(indices), do: indices |> Enum.map(&index/1) |> multiple



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
  @spec key(any) :: t
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
  @spec key!(any) :: t
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
  @spec key?(any) :: t
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
  @spec keys(nonempty_list(any)) :: t
  deflens keys(keys), do: keys |> Enum.map(&Lens2.key/1) |> multiple

  @doc ~S"""
  Returns a lens that focuses on the values of all the keys. If any of the keys does not exist, an error is raised.

      iex> Lens2.keys!([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2, c: 3})
      [1, 3]
      iex> Lens2.keys!([:a, :c]) |> Lens2.map([a: 1, b: 2, c: 3], &(&1 + 1))
      [a: 2, b: 2, c: 4]
      iex> Lens2.keys!([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2})
      ** (KeyError) key :c not found in: %{a: 1, b: 2}
  """
  @spec keys!(nonempty_list(any)) :: t
  deflens keys!(keys), do: keys |> Enum.map(&Lens2.key!/1) |> multiple

  @doc ~S"""
  Returns a lens that focuses on the values of all the keys. If any of the keys does not exist, it is ignored.

      iex> Lens2.keys?([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2, c: 3})
      [1, 3]
      iex> Lens2.keys?([:a, :c]) |> Lens2.map([a: 1, b: 2, c: 3], &(&1 + 1))
      [a: 2, b: 2, c: 4]
      iex> Lens2.keys?([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2})
      [1]
  """
  @spec keys?(nonempty_list(any)) :: t
  deflens keys?(keys), do: keys |> Enum.map(&Lens2.key?/1) |> multiple

  @doc ~S"""
  Returns a lens that focuses on all the values in an enumerable.

      iex> Lens2.all |> Lens2.to_list([1, 2, 3])
      [1, 2, 3]

  Does work with updates but produces a list from any enumerable by default:

      iex> Lens2.all |> Lens2.map(MapSet.new([1, 2, 3]), &(&1 + 1))
      [2, 3, 4]

  See [into](#into/2) on how to rectify this.
  """
  @spec all :: t
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
  Compose a pair of lens by applying the second to the result of the first

      iex> Lens2.seq(Lens2.key(:a), Lens2.key(:b)) |> Lens2.one!(%{a: %{b: 3}})
      3

  Piping lenses has the exact same effect:

      iex> Lens2.key(:a) |> Lens2.key(:b) |> Lens2.one!(%{a: %{b: 3}})
      3
  """
  @spec seq(t, t) :: t
  deflens_raw seq(lens1, lens2) do
    fn data, fun ->
      {res, changed} =
        get_and_map(lens1, data, fn item ->
          get_and_map(lens2, item, fun)
        end)

      {Enum.concat(res), changed}
    end
  end

  @doc ~S"""
  Combine the composition of both lens with the first one.

      iex> Lens2.seq_both(Lens2.key(:a), Lens2.key(:b)) |> Lens2.to_list(%{a: %{b: :c}})
      [:c, %{b: :c}]
  """
  @spec seq_both(t, t) :: t
  deflens seq_both(lens1, lens2), do: both(seq(lens1, lens2), lens1)

  @doc ~S"""
  Given a lens L this creates a lens that applies L, then applies L to the results of that application and so on,
  focusing on all the results encountered on the way.

      iex> data = %{
      ...>    items: [
      ...>      %{id: 1, items: []},
      ...>      %{id: 2, items: [
      ...>        %{id: 3, items: []}
      ...>      ]}
      ...> ]}
      iex> lens = Lens2.recur(Lens2.key(:items) |> Lens2.all) |> Lens2.key(:id)
      iex> Lens2.to_list(lens, data)
      [1, 3, 2]

  Note that it does not focus on the root item. You can remedy that with `Lens2.root`:


      iex> data = %{
      ...>    id: 4,
      ...>    items: [
      ...>      %{id: 1, items: []},
      ...>      %{id: 2, items: [
      ...>        %{id: 3, items: []}
      ...>      ]}
      ...>    ]
      ...> }
      iex> lens = Lens2.both(Lens2.recur(Lens2.key(:items) |> Lens2.all), Lens2.root) |> Lens2.key(:id)
      iex> Lens2.to_list(lens, data)
      [1, 3, 2, 4]
  """
  @spec recur(t) :: t
  deflens_raw recur(lens), do: &do_recur(lens, &1, &2)

  @doc ~S"""
  Just like `recur` but also focuses on the root of the data.

      iex> data = {:x, [{:y, []}, {:z, [{:w, []}]}]}
      iex> Lens2.recur_root(Lens2.at(1) |> Lens2.all()) |> Lens2.at(0) |> Lens2.to_list(data)
      [:y, :w, :z, :x]
  """
  deflens recur_root(lens), do: Lens2.both(Lens2.recur(lens), Lens2.root())

  @doc ~s"""
  Returns a lens that focuses on what both the lenses focus on.

      iex> Lens2.both(Lens2.key(:a), Lens2.key(:b) |> Lens2.at(1)) |> Lens2.to_list(%{a: 1, b: [2, 3]})
      [1, 3]

  Bear in mind that what the first lens focuses on will be processed first. Other functions in the library are designed
  so that the part is processed before the whole and it is advisable to do the same when using this function directly.
  Not adhering to this principle might lead to the second lens not being able to perform its traversal on a changed
  version of the structure.

      iex> Lens2.both(Lens2.root, Lens2.key(:a)) |> Lens2.get_and_map(%{a: 1}, fn x -> {x, :foo} end)
      ** (FunctionClauseError) no function clause matching in Access.fetch/2
      iex> Lens2.both(Lens2.key(:a), Lens2.root) |> Lens2.get_and_map(%{a: 1}, fn x -> {x, :foo} end)
      {[1, %{a: :foo}], :foo}
  """
  @spec both(t, t) :: t
  deflens_raw both(lens1, lens2) do
    fn data, fun ->
      {res1, changed1} = get_and_map(lens1, data, fun)
      {res2, changed2} = get_and_map(lens2, changed1, fun)
      {res1 ++ res2, changed2}
    end
  end

  @doc """
  Combines the two provided lenses in a way similar to `seq`. However instead of only focusing on what the final lens
  would focus on, it focuses on pairs of the form `{context, part}`, where context is the focus of the first lens in
  which the focus of the second lens was found.

      iex> lens = Lens2.context(Lens2.keys([:a, :c]), Lens2.key(:b) |> Lens2.all())
      iex> Lens2.to_list(lens, %{a: %{b: [1, 2]}, c: %{b: [3]}})
      [{%{b: [1, 2]}, 1}, {%{b: [1, 2]}, 2}, {%{b: [3]}, 3}]
      iex> Lens2.map(lens, %{a: %{b: [1, 2]}, c: %{b: [3]}}, fn({%{b: bs}, value}) ->
      ...>   length(bs) + value
      ...> end)
      %{a: %{b: [3, 4]}, c: %{b: [4]}}
  """
  @spec context(t, t) :: t
  deflens_raw context(context_lens, item_lens) do
    fn data, fun ->
      {results, changed} =
        get_and_map(context_lens, data, fn context ->
          get_and_map(item_lens, context, fn item -> fun.({context, item}) end)
        end)

      {Enum.concat(results), changed}
    end
  end

  @spec multiple([t]) :: t
  deflens multiple(lenses), do: lenses |> Enum.reverse() |> Enum.reduce(empty(), &both/2)

  @doc ~S"""
  Returns a lens that focuses on what the first lens focuses on, unless it's nothing. In that case the
  lens will focus on what the second lens focuses on.

      iex(1)> get_in(%{a: 1}, [Lens2.either(Lens2.key?(:a), Lens2.key?(:b))])
      [1]
      iex(2)> get_in(%{b: 2}, [Lens2.either(Lens2.key?(:a), Lens2.key?(:b))])
      [2]

  It can be used to return a default value:

      iex> get_in([%{id: 8}], [Lens2.all |> Lens2.filter(&(&1.id == 8)) |> Lens2.either(Lens2.const(:default))])
      [%{id: 8}]
      iex> get_in([%{id: 8}], [Lens2.all |> Lens2.filter(&(&1.id == 1)) |> Lens2.either(Lens2.const(:default))])
      [:default]

  Or to upsert:

      iex> upsert = Lens2.all() |> Lens2.filter(&(&1[:id] == 1)) |> Lens2.either(Lens2.front())
      iex> update_in([%{id: 0}, %{id: 1}], [upsert], fn _ -> %{id: 1, x: :y} end)
      [%{id: 0}, %{id: 1, x: :y}]
      iex> update_in([%{id: 0}, %{id: 2}], [upsert], fn _ -> %{id: 1, x: :y} end)
      [%{id: 1, x: :y}, %{id: 0}, %{id: 2}]
  """
  @spec either(t, t) :: t
  deflens_raw either(lens, other_lens) do
    fn data, fun ->
      case get_and_map(lens, data, fun) do
        {[], _updated} -> get_and_map(other_lens, data, fun)
        {res, updated} -> {res, updated}
      end
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
  @spec into(t, Collectable.t()) :: t
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
  @spec filter(t, (any -> boolean)) :: t
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

  @doc false
  @deprecated "Use filter/2 instead"
  @spec satisfy(t, (any -> boolean)) :: t
  def satisfy(lens, predicate), do: filter(lens, predicate)

  @doc ~S"""
  Returns a lens that focuses on a subset of elements focused on by the given lens that don't satisfy the given
  condition.

      iex> Lens2.map_values() |> Lens2.reject(&Integer.is_odd/1) |> Lens2.to_list(%{a: 1, b: 2, c: 3, d: 4})
      [2, 4]
  """
  @spec reject(t, (any -> boolean)) :: t
  def reject(lens, predicate), do: filter(lens, &(not predicate.(&1)))

  @doc ~S"""
  Returns a lens that focuses on all values of a map.

      iex> Lens2.map_values() |> Lens2.to_list(%{a: 1, b: 2})
      [1, 2]
      iex> Lens2.map_values() |> Lens2.map(%{a: 1, b: 2}, &(&1 + 1))
      %{a: 2, b: 3}
  """
  @spec map_values :: t
  deflens map_values, do: all() |> into(%{}) |> at(1)

  @doc ~S"""
  Returns a lens that focuses on all keys of a map.

      iex> Lens2.map_keys() |> Lens2.to_list(%{a: 1, b: 2})
      [:a, :b]
      iex> Lens2.map_keys() |> Lens2.map(%{1 => :a, 2 => :b}, &(&1 + 1))
      %{2 => :a, 3 => :b}
  """
  @spec map_keys :: t
  deflens map_keys, do: all() |> into(%{}) |> at(0)

  @doc ~S"""
  Returns a list of values that the lens focuses on in the given data.

      iex> Lens2.keys([:a, :c]) |> Lens2.to_list(%{a: 1, b: 2, c: 3})
      [1, 3]
  """
  @spec to_list(t, any) :: list(any)
  def to_list(lens, data), do: get_in(data, [lens])

  @doc ~S"""
  Performs a side effect for each values this lens focuses on in the given data.

      iex> data = %{a: 1, b: 2, c: 3}
      iex> fun = fn -> Lens2.keys([:a, :c]) |> Lens2.each(data, &IO.inspect/1) end
      iex> import ExUnit.CaptureIO
      iex> capture_io(fun)
      "1\n3\n"
  """
  @spec each(t, any, (any -> any)) :: :ok
  def each(lens, data, fun), do: to_list(lens, data) |> Enum.each(fun)

  @doc ~S"""
  Returns an updated version of the data by applying the given function to each value the lens focuses on and building
  a data structure of the same shape with the updated values in place of the original ones.

      iex> data = [1, 2, 3, 4]
      iex> Lens2.all() |> Lens2.filter(&Integer.is_odd/1) |> Lens2.map(data, fn v -> v + 10 end)
      [11, 2, 13, 4]
  """
  @spec map(t, any, (any -> any)) :: any
  def map(lens, data, fun), do: update_in(data, [lens], fun)

  @doc ~S"""
  Returns an updated version of the data by replacing each spot the lens focuses on with the given value.

      iex> data = [1, 2, 3, 4]
      iex> Lens2.all() |> Lens2.filter(&Integer.is_odd/1) |> Lens2.put(data, 0)
      [0, 2, 0, 4]
  """
  @spec put(t, any, any) :: any
  def put(lens, data, value), do: put_in(data, [lens], value)

  @doc ~S"""
  Executes `to_list` and returns the single item that the given lens focuses on for the given data. Crashes if there
  is more than one item.
  """
  @spec one!(t, any) :: any
  def one!(lens, data) do
    [result] = to_list(lens, data)
    result
  end

  defp do_recur(lens, data, fun) do
    {res, changed} =
      get_and_map(lens, data, fn item ->
        {results, changed1} = do_recur(lens, item, fun)
        {res_parent, changed2} = fun.(changed1)
        {results ++ [res_parent], changed2}
      end)

    {Enum.concat(res), changed}
  end

  ### T#EMPe
  def get_and_map(lens, data, fun), do: get_and_update_in(data, [lens], fun)


end
