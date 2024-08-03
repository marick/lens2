defmodule Lens2.Lenses.Combine do
  @moduledoc """
  Lenses that combine lenses to get new lenses.


  """
  use Lens2.Makers
  alias Lens2.Deeply

  @doc ~S"""
  Create an initial pointer from the whole of a container.

  **Rarely used**

  Most lenses consume pointers to create new pointers. However,
  sometimes you want to *add* those new pointers to the original
  pointer. Use `root/0` to represent the original.

  That's the difference between `repeatedly/1` and
  `and_repeatedly/1`: the latter uses `both/2` and `root/0` to add the
  root pointer to what `repeatedly/1` produces.

      def_composed_maker and_repeatedly(descender) do
        pointers_below = repeatedly(descender)
        both(root(), pointers_below)
      end
  """
  @spec root :: Lens2.lens
  def_maker root do
    fn container, descender ->
      {res, updated} = descender.(container)
      {[res], updated}
    end
  end


  @doc ~S"""
  Returns a lens ignores all input pointers and produces no pointers.

  Suppose you have an `Enumeration` of lenses and you want to combine
  them into a single lens with `Enum.reduce/3`:

      Enum.reduce(lenses, ???, combining_function)

  If each step of the reduction is going to add a new source of
  pointers, the starting point should be a source of *no* pointers,
  which is `empty/0`. For example, the implementation of `multiple/1`
  combines lenses one by one using `both/2`. It starts with `empty/0`:

      Enum.reduce(lenses, empty(), &both/2)

  """
  @spec empty :: Lens2.lens
  def_maker empty, do: fn container, _descender -> {[], container} end


  @doc deprecated: "Too confusing."
  @doc ~S"""
  Returns a lens that replaces any incoming pointers with a pointer to the given container.

  You can use this to produce a sort of a default value. For example, recall that
  `Lens2.Lenses.Keyed.key?/1` will return nothing for a missing key:

      iex> Deeply.get_all(%{}, Lens.key?(:a))
      []


  The `either/2` lens will apply its second lens argument if the first
  has no value, so it can be used to defer to `const`:

      iex> lens = Lens.either(Lens.key?(:a), Lens.const(:DEFAULT))
      iex> Deeply.get_all(%{a: :GIVEN}, lens)
      [:GIVEN]
      iex> Deeply.get_all(%{}, lens)
      [:DEFAULT]

  The default value can even be used by later lenses:

      iex> lens =
      ...>   Lens.either(Lens.key?(:a), Lens.const(%{bb: :BB_DEFAULT_VALUE}))
      ...>   |> Lens.key(:bb)
      iex> Deeply.get_all(%{a: %{bb: :GIVEN}}, lens)
      [:GIVEN]
      iex> Deeply.get_all(%{}, lens)
      [:BB_DEFAULT_VALUE]

  However, this defaulting is not as useful as it seems.

  First, you must take care to use `key?` and not, say,
  `Lens2.Lenses.Keyed.key/1`.  The latter *will* produce a value for a
  missing key (`nil`), which means `either/2` will not use its second
  argument.

  Second, `Lens2.Deeply.put/3` and `Lens2.Deeply.update/3` work
  because a lens pipeline "backtracks" along a path to build up the
  new nested structure. `const` breaks (or, more accurately,
  eliminates) that backtracking. For example, in my first use of `const`,
  I did not expect that using `put` on a map with a missing key would "lose" the map:

      iex> lens = Lens.either(Lens.key?(:a), Lens.const(:DEFAULT))
      iex> Deeply.put(%{}, lens, :NEW)
      :NEW    # *not* %{a: :NEW}

  Compare that to using `key/1` or `put_in/1`

      iex> Deeply.put(%{}, Lens.key(:a), :NEW)
      %{a: :NEW}
      iex> put_in(%{}, [:a], :NEW)
      %{a: :NEW}

  I think this is all too confusing to justify using `const`.
  """

  @spec const(any) :: Lens.lens
  def_maker const(value) do
    fn _container, descender ->
      {res, updated} = descender.(value)
      {[res], updated}
    end
  end

  @doc ~S"""
  Descend different "shapes" of data differently. Powered by function
  argument pattern matching.

  `GenServer` message handlers return tuples to the `GenServer` infrastructure. There are quite a variety, but let's say we only care about these three:

        {:noreply, new_state}
        {:noreply, new_state, something_else}
        {:reply, reply, new_state}

  We have an `Enumeration` of these and other such tuples. For our
  three, we wish to descend into `new_state`. That can be done like
  this:

       iex>  matcher = fn
       ...>    {:noreply, _} -> Lens.at(1)
       ...>    {:noreply, _, _} -> Lens.at(1)
       ...>    {:reply, _, _} -> Lens.at(2)
       ...>     _ -> Lens.empty
       ...>  end
       iex>  lens = Lens.all |> Lens.match(matcher) |> Lens.key?(:code)
       iex>  returns = [{:noreply, %{code: 1}},
       ...>             {:reply, :ok, %{code: 2}},
       ...>             {:stop, 5, %{code: :ignore}}]
       iex>  Deeply.get_all(returns, lens)
       [1, 2]

  Note the use of `empty/0` to handle the "don't care" case.

  """
  @spec match((any -> Lens2.lens)) :: Lens2.lens
  def_maker match(matcher_fun) do
    fn container, descender ->
      Deeply.get_and_update(container, matcher_fun.(container), descender)
    end
  end


  @doc ~S"""
  Use multiple lenses to convert a single pointer into a multitude of
  them (usually into the next level down).

  Suppose you have an enumeration of tuple and want to point to the
  values at indices 0, 1, and 3. You can do that like this:

      iex> lens = Lens.multiple([Lens.at(0), Lens.at(1), Lens.at(3)])
      iex> list = [0, 1, 2, 3, 4]
      iex> Deeply.get_all(list, lens)
      [0, 1, 3]
      iex> Deeply.update(list, lens, & &1 * 1111)
      [0, 1111, 2, 3333, 4]

  This is essentially the implementation of `Lens2.Lenses.Indexed.indices/1`.
  """
  @spec multiple([Lens2.lens]) :: Lens2.lens
  def_composed_maker multiple(lenses),
                     do: lenses |> Enum.reverse() |> Enum.reduce(empty(), &both/2)

  @doc ~S"""
  Convert one pointer into two pointers (usually into the next level down).

  Suppose you want a lens that will point at all the elements of an
  enumeration that are divisible by either two or three. The lenses to
  point at the two types of values can be made with
  `Lens2.Lenses.Filter.filter/2`, then combined with `both/2`:

      iex> by_2 = Lens.filter(& rem(&1, 2) == 0)
      iex> by_3 = Lens.filter(& rem(&1, 3) == 0)
      iex> list = [0, 1, 2, 3, 4, 5, 6]
      iex> lens = Lens.all |> Lens.both(by_2, by_3)
      iex> Deeply.get_all(list, lens)
      [0, 0, 2, 3, 4, 6, 6]

  You might be surprised by the duplications in the result (I was!),
  but that shows that the two lenses are independent. `by_2` produces
  pointers to `0`, `2`, `4`, and `6`. `by_3` produces pointers to `0`,
  `3`, and `6`. `both/2`, when used by `Deeply.get_all` just gathers
  the values at all the pointer, not caring that sometimes two point
  at the same thing.

  The possibility of duplications has consequences for `Deeply.update`. For example,
  consider this:

      Deeply.update(list, lens, & &1 * 1111)

  Here's the result:

      [0, 1, 2222, 3333, 4444, 5, 7405926]

  The original `6` matched both filters, so it was multiplied
  twice. (So was the `0`, though you can't tell.)
  """
  @spec both(Lens2.lens, Lens2.lens) :: Lens2.lens
  def_maker both(lens1, lens2) do
    fn container, descender ->
      {res1, changed1} = Deeply.get_and_update(container, lens1, descender)
      {res2, changed2} = Deeply.get_and_update(changed1, lens2, descender)
      {res1 ++ res2, changed2}
    end
  end


  @doc ~S"""
  Given two lenses, apply the second to the results of the first.

  This is the mechanism behind pipelining. This:

      Lens.key(:a) |> Lens.key(:b)

  ... is the same as this:

      Lens.seq(Lens.key(:a), Lens.key(:b))
  """
  @spec seq(Lens2.lens, Lens2.lens) :: Lens2.lens
  def_maker seq(outer_lens, inner_lens) do
    fn outer_container, inner_descender ->
      outer_descender = fn inner_container ->
        Deeply.get_and_update(inner_container, inner_lens, inner_descender)
      end

      {gotten, updated} =
        Deeply.get_and_update(outer_container, outer_lens, outer_descender)

      {Enum.concat(gotten), updated}
    end
  end

  @doc ~S"""
  Like `seq/2` but retains the pointers from the first lens.


  Whereas `seq/2` discards the pointers from the first lens after the
  second consumes them, `seq_both` retains them. It is literally defined as:

      both(seq(lens1, lens2), lens1)

  This is similar to `and_repeatedly`, except it stops after one application.

      iex> map = %{a: %{c: 1},
      ...>         b: %{c: 2}}
      iex> lens = Lens.keys([:a, :b]) |> Lens.seq_both(Lens.key(:c))
      iex> Deeply.get_all(map, lens)
      [ 1, 2, %{c: 1}, %{c: 2} ]

  This behavior means that `Lens2.Deeply.update/3` applies "bottom
  up". Consider summing a nested list with `Enum.sum/1`:

      iex> nested = %{a: [1, [20, 30, 40], 5]}
      iex> lens = Lens.seq_both(Lens.key(:a), Lens.at(1))
      iex> Deeply.update(nested, lens, &Enum.sum/1)
      %{a: 96}

  *First*, the interior list `[20, 30, 40]` is summed, resulting in
  the list `[1, 90, 5]`. *Then* the summation function is applied to
  that, producing the final value of `96`.

  `Lens2.Deeply.put/3` can be used, but it (in effect) ignores the deeper pointers:

      iex> nested = [ [ 1 ] ]
      iex> lens = Lens.seq_both(Lens.at(0), Lens.at(0))
      iex> Deeply.put(nested, lens, :NEW)
      [ :NEW ]

  Presumably, the `1` in the `[1]` sublist was replaced with `:NEW`
  before the entire sublist was itself replaced, but you can't tell.

  """
  @spec seq_both(Lens2.lens, Lens2.lens) :: Lens2.lens
  def_composed_maker seq_both(lens1, lens2), do: both(seq(lens1, lens2), lens1)


  @doc ~S"""
  Apply a `descender` lens repeatedly to replace one or more pointers with all the matching pointers below them, descending "all the way into" the container.

  Given a pointer to within a container, `repeatedly(descender)`:

  1. Applies `descender` to get a list of places. Let's suppose there
     are two such places, and call them `X` and `Y`.
  2. *Replaces* the original pointer (or pointers) with `X` and `Y`.
  3. Applies `descender` to `X` and `Y` to get, say, `X_1` and `Y_1`.
  4. *Appends* the new pointers, giving `[X, Y, X_1, Y_1]`.
  5. Repeats steps 3 and 4 until no new places are found.

  (If you want to retain the original place or places, rather than
  replacing them, use `and_repeatedly/1`.)

  Here is an example. (For a less terse explanation, see <<<<>>>>>

  Consider this structure:

      %{below:
           %{..., below: ...}}

  `Lens.key?(:below)` will transform a pointer to the root into a
  pointer to the first substructure:

           %{..., below: ...}}

  This function can use that lens to give you pointers all the places under a `:below` key:

      iex> lens = Lens.repeatedly(Lens.key?(:below))
      iex> tree = %{below:
      ...>           %{value: 1, below:
      ...>                         %{value: 2}}}
      iex> Deeply.get_all(tree, lens)
      [%{value: 2},
       %{value: 1, below: %{value: 2}}
       # Note that the original `tree` is not included.
      ]

  Given pointers to the levels, a later lens can point to values at all of those levels:

      iex> lens = Lens.repeatedly(Lens.key?(:below)) |> Lens.key(:value)
      iex> tree = %{below:
      ...>           %{value: 1, below:
      ...>                         %{value: 2}}}
      iex> Deeply.update(tree, lens, & &1 * 111111)
      %{below:
         %{value: 111111, below:
                          %{value: 222222}}}
      ...>
      iex> Deeply.get_all(tree, lens)
      [2, 1]

  **Warning:** The lens *must* make a distinction between "missing"
  and `nil`.  If the `Lens2.Lenses.Keyed.key?/1` above were replaced
  with `Lens2.Lenses.Keyed.key/1`, which does not distinguish between
  a key whose value is `nil` and a missing key, the descent would
  never finish, as:

      iex> nil |> Deeply.get_all(Lens.key(:a))
      nil

  I think this behavior is for compatibility with `Access`:

      iex> nil |> get_in([:a])
      nil

  Note: `Lens2.Lenses.Indexed.at/1` does not make a distinction
  between an index in range or an index containing `nil`, so it cannot
  be used with this function.

      iex> nil |> get_in([Access.at(3)])
      nil

  `repeatedly/1` is a synonym for `recur/1`, the name in the original `Lens` package.
  """
  @spec repeatedly(Lens2.lens) :: Lens2.lens
  def_maker repeatedly(descender), do: &do_recur(descender, &1, &2)

  @doc ~S"""
  Apply a `descender` lens repeatedly to augment the current set of
  pointers with all matching pointers below them, descending "all the
  way into" the container.

  See `repeatedly/1` for details and a more extensive example. The
  only difference is that the lens produced by this function will
  retain the original pointers. Suppose you have this structure:

      iex>  nested = %{value: 1,
      ...>             below: %{value: 2,
      ...>                      below: %{value: 3}}}
      iex>  values = Lens.and_repeatedly(Lens.key?(:below)) |> Lens.key(:value)
      iex>  Deeply.get_all(nested, values) |> Enum.sort
      [1, 2, 3]

   Had `repeatedly/1` be used, the `1` value would not be included in the result.
  """
  @spec and_repeatedly(Lens2.lens) :: Lens2.lens
  def_composed_maker and_repeatedly(descender) do
    pointers_below = repeatedly(descender)
    both(root(), pointers_below)
  end


  @doc ~S"""
  The [Lens 1](https://hexdocs.pm/lens/readme.html) name for `repeatedly/1`.

  It confused me, so I retaliated by renaming it.
  """
  @spec recur(Lens2.lens) :: Lens2.lens
  def_composed_maker recur(descender), do: repeatedly(descender)

  @doc ~S"""
  The [Lens 1](https://hexdocs.pm/lens/readme.html) name for `and_repeatedly/1`.
  """
  @spec recur_root(Lens2.lens) :: Lens2.lens
  def_composed_maker recur_root(descender), do: and_repeatedly(descender)

  defp do_recur(lens, container, descender) do
    {res, changed} =
      Deeply.get_and_update(container, lens, fn item ->
        {results, changed1} = do_recur(lens, item, descender)
        {res_parent, changed2} = descender.(changed1)
        {results ++ [res_parent], changed2}
      end)

    {Enum.concat(res), changed}
  end

  @doc """
  Record an intermediate container on the way to selected values.

  A composed lens will descend through nested containers to reach one
  or more leaf values.  It's occasionally useful to make one or more
  intermediate containers available to the caller of
  `Deeply.get_all` or the function passed to
  `Deeply.update`.

  **Getting**

  One use might be to answer the question, "Where did this leaf value
  come from?" Consider the following structure, with a list within a map within a list:

       map_0 = %{a: [0, :target_1, 2], name: "first"}
       map_1 = %{a: [4, :target_5, 6], name: "second"}
       map_list = [map_0, map_1]

  When fetching the two `:target` atoms, we want to record which map
  contained them, perhaps to extract the `:name`. We will do that by:

  1. Describing a path *from* the map to the target list element:

         into_map = Lens.key(:a) |> Lens.at(1)

  2. Marking the start of that path as something worth recording:

         Lens.context(into_map)   # Think of this as taking a snapshot.

  3. Combining that with a lens describing the path *to* the map:

         lens = Lens.at(0) |> Lens.context(into_map)

  This lens, applied to `map_list`, will produce two leaf
  values. `Deeply.get_all` will return those, but also the snapshots
  taken on the way. The two are wrapped into a tuple. So:

      [{map_0_snapshot, map_0_target}, {map_1_snapshot, map_1_target}] =
        Deeply.get_all(map_list, lens)

  In this case, the result will be:

      map_0_snapshot == %{a: [0, :target_1, 2], name: "first"}
      map_0_target   == :target_1
      map_1_snapshot == %{a: [0, :target_1, 2], name: "second"}
      map_1_target   == :target_5

  **Putting**

  The `context` lens has no effect on `Deeply.put`. That is, using the lens above,
  we could change the targets like this:

      actual = Deeply.put(map_list, lens, :REPLACEMENT)

      actual == [ %{a: [0, :REPLACEMENT, 2], name: "first"},
                  %{a: [0, :REPLACEMENT, 2], name: "second"}

  That's the same as you'd get with a lens pipeline that leaves out the `context`:

      lens = Lens.at(0) |> Lens.key(:a) |> Lens.at(1)

  **Updating**

  The function used with `Deeply.update` will take a tuple argument:

      updater = fn {snapshot, leaf} -> ... end

  Let's simplify the previous example to this list-of-maps-of-lists:

      map_list = [
         %{a: [10, 100, 1000]}
      ]

  We want to update the `100` element with the sum of the whole `:a`
  list. For extra fun, we'll add on the current value of the element
  (100), giving an expected result of `10 + 100 + 1000 + 100 = 1210`.

  Once we have the leaf value `100` and the context `{a: [10, 100,
  1000]}`, this updater function would serve:

      updater = fn {snapshot, leaf} ->
        Enum.sum(snapshot) + leaf
      end

  Then `Deeply.update` will work as hoped:

      actual = Deeply.update(map_list, lens)
      assert actual == [
         %{a: [10, 1210, 1000]}
      ]

  Note that `Deeply.update` can still only update leaf values, not the snapshots.

  **Nested contexts**

  What happens with this composed lens?

      Lens.at(0) |> Lens.context(Lens.key(:a) |> Lens.context(Lens.at(1)))

  It produces nested tuples of this form:

      {outer_context, {inner_context, leaf_value}}

  ... such as:

      {
        %{a: [0, :target_1, 2], b: 3},
        {
          [0, :target_1, 2],
          :target_1
        }
      }

  A structure of the same shape and values will be given to a `Deeply.update` function.

  """
  @spec context(Lens2.lens, Lens2.lens) :: Lens2.lens
  def_maker context(context_lens, item_lens) do
    fn container, descender ->
      {results, changed} =
        Deeply.get_and_update(container, context_lens, fn context ->
          Deeply.get_and_update(context, item_lens, fn item ->
            descender.({context, item})
          end)
        end)

      {Enum.concat(results), changed}
    end
  end

  @doc ~S"""
  Replace pointers with the pointers returned by the first lens. If there are none,
  follow the second lens.

  For example, to descend through key `:a` or – if there is no such
  key – then key `:b`:

      iex> lens = Lens.key?(:a) |> Lens.either(Lens.key?(:b))
      iex> Deeply.get_only(%{a: 1}, lens)
      1
      iex> Deeply.get_only(%{b: 2}, lens)
      2

  The first lens must be a lens that treats missing values differently
  than nils. Otherwise, the second lens will never be used. Consider changing the
  above to use `Lens2.Lenses.Keyed.key/1` instead of `Lens2.Lenses.Keyed.key?/1`:

      iex> lens = Lens.key(:a) |> Lens.either(Lens.key?(:b))
      iex> Deeply.get_only(%{b: 2}, lens)
      nil

  The `nil` final result is because the first lens produces `nil` for
  the missing `:a` key.
  """
  @spec either(Lens2.lens, Lens2.lens) :: Lens2.lens
  def_maker either(lens, other_lens) do
    fn container, descender ->
      case Deeply.get_and_update(container, lens, descender) do
        {[], _updated} -> Deeply.get_and_update(container, other_lens, descender)
        {res, updated} -> {res, updated}
      end
    end
  end

  @doc ~S"""
  On `update` and `put`, puts the result into a given `Collectable`. No effect on `get_all`.


  Here's an example of using `into` to update the values of a `Range`
  and put them `into` a `MapSet`:

       iex> Deeply.update(0..5, Lens.all |> Lens.into(MapSet.new), &inspect/1)
       MapSet.new(["0", "1", "2", "3", "4", "5"])

  However, it's tricksy to use `into/1` in a pipeline. The above lens is more safely written
  as:

       Lens.into(Lens.all, MapSet.new)

  You can just take my word for it, but if you'd like to understand why, read on.

  ### The Why

  Suppose we've successfully used the pipeline form above, but now we come upon
  ranges within a map:

       %{a: 0..2, b: 3..4}

  We want to explode all the interior ranges into MapSets of strings to get something like
  this:

      %{a: MapSet.new(["0", "1", "2"]),
        b: MapSet.new(["3", "4"])}

  Copy and paste the previous solution, prepend a
  `Lens2.Lenses.Keyed.map_values/0`, and we're golden, right?

      iex> lens = Lens.map_values |> Lens.all |> Lens.into(MapSet.new)
      iex> Deeply.update(%{a: 0..2, b: 3..4}, lens, &inspect/1)
      %MapSet{map: %{{:a, ["0", "1", "2"]} => [], {:b, ["3", "4"]} => []}}

  Um, what?

  The problem is that the `into/1` is the last thing done. It works on the *entire* updated
  container. It, in effect, does this:

      iex> updated =
      ...>   Deeply.update(%{a: 0..2, b: 3..4},
      ...>                 Lens.map_values |> Lens.all,
      ...>                 &inspect/1)
      %{a: ["0", "1", "2"], b: ["3", "4"]}
      iex> updated |> Enum.into(MapSet.new)
      %MapSet{map: %{{:a, ["0", "1", "2"]} => [], {:b, ["3", "4"]} => []}}

  In our case, we want the `into` to take place on intermediate containers, so we
  need to wrap the `into/2` around only the relevant parts of the pipeline, like this:

      iex> lens = Lens.map_values |> Lens.into(Lens.all, MapSet.new)
      iex> Deeply.update(%{a: 0..2, b: 3..4}, lens, &inspect/1)
      %{a: MapSet.new(["0", "1", "2"]),
        b: MapSet.new(["3", "4"])}

  Alternately, we could make the separation like this.

      iex> lens = Lens.seq(Lens.map_values, Lens.all |> Lens.into(MapSet.new))
      iex> Deeply.update(%{a: 0..2, b: 3..4}, lens, &inspect/1)
      %{a: MapSet.new(["0", "1", "2"]),
        b: MapSet.new(["3", "4"])}
  """
  @spec into(Lens2.lens, Collectable.t()) :: Lens2.lens
  def_maker into(lens, collectable) do
    fn container, descender ->
      {gotten, updated} = Deeply.get_and_update(container, lens, descender)
      {gotten, Enum.into(updated, collectable)}
    end
  end



end
