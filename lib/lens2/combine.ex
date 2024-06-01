defmodule Lens2.Combine do
  import Lens2.Macros
  alias Lens2.Basic
  alias Lens2.Operations, as: A

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
      A.get_and_map(matcher_fun.(data), data, fun)
    end
  end


  @spec multiple([lens]) :: lens
  deflens multiple(lenses), do: lenses |> Enum.reverse() |> Enum.reduce(Basic.empty(), &both/2)

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
  @spec both(lens, lens) :: lens
  deflens_raw both(lens1, lens2) do
    fn data, fun ->
      {res1, changed1} = A.get_and_map(lens1, data, fun)
      {res2, changed2} = A.get_and_map(lens2, changed1, fun)
      {res1 ++ res2, changed2}
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
  @spec seq(lens, lens) :: lens
  deflens_raw seq(lens1, lens2) do
    fn data, fun ->
      {res, changed} =
        A.get_and_map(lens1, data, fn item ->
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
  @spec seq_both(lens, lens) :: lens
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
  @spec recur(lens) :: lens
  deflens_raw recur(lens), do: &do_recur(lens, &1, &2)

  @doc ~S"""
  Just like `recur` but also focuses on the root of the data.

      iex> data = {:x, [{:y, []}, {:z, [{:w, []}]}]}
      iex> Lens2.recur_root(Lens2.at(1) |> Lens2.all()) |> Lens2.at(0) |> Lens2.to_list(data)
      [:y, :w, :z, :x]
  """
  @spec recur_root(lens) :: lens
  deflens recur_root(lens), do: Lens2.both(Lens2.recur(lens), Lens2.root())

  defp do_recur(lens, data, fun) do
    {res, changed} =
      A.get_and_map(lens, data, fn item ->
        {results, changed1} = do_recur(lens, item, fun)
        {res_parent, changed2} = fun.(changed1)
        {results ++ [res_parent], changed2}
      end)

    {Enum.concat(res), changed}
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
  @spec context(lens, lens) :: lens
  deflens_raw context(context_lens, item_lens) do
    fn data, fun ->
      {results, changed} =
        A.get_and_map(context_lens, data, fn context ->
          A.get_and_map(item_lens, context, fn item -> fun.({context, item}) end)
        end)

      {Enum.concat(results), changed}
    end
  end

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
  @spec either(lens, lens) :: lens
  deflens_raw either(lens, other_lens) do
    fn data, fun ->
      case get_and_map(lens, data, fun) do
        {[], _updated} -> A.get_and_map(other_lens, data, fun)
        {res, updated} -> {res, updated}
      end
    end
  end


  ### T#EMPe
  defp get_and_map(lens, data, fun), do: get_and_update_in(data, [lens], fun)



end
