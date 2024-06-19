defmodule Lens2.Lenses.Combine do
  @moduledoc """
  Lenses that combine lenses to get new lenses.


  """
  use Lens2.Deflens
  alias Lens2.Deeply

  @doc ~S"""
  Create an initial pointer from the whole of a container.

  **Rarely used**

  Most lenses consume pointers to create new pointers. However,
  sometimes you want to *add* those new pointers to the original
  pointer. Use `root/0` to represent the original.

  That's the difference between `levels_below/1` and
  `add_levels_below/1`: the latter uses `both/2` and `root/0` to add the
  root pointer to what `levels_below/1` produces.

      deflens add_levels_below(descender) do
        pointers_below = levels_below(descender)
        both(root(), pointers_below)
      end
  """
  @spec root :: Lens2.lens
  deflens_raw root do
    fn data, fun ->
      {res, updated} = fun.(data)
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
  deflens_raw empty, do: fn data, _fun -> {[], data} end


  @doc deprecated: "Too confusing."
  @doc ~S"""
  Returns a lens that replaces any incoming pointers with a pointer to the given data.

  You can use this to produce a sort of a default value. For example, recall that
  `Lens2.Lenses.Keyed.key?/1` will return nothing for a missing key:

      iex> Deeply.to_list(%{}, Lens.key?(:a))
      []


  The `either/2` lens will apply its second lens argument if the first
  has no value, so it can be used to defer to `const`:

      iex> lens = Lens.either(Lens.key?(:a), Lens.const(:DEFAULT))
      iex> Deeply.to_list(%{a: :GIVEN}, lens)
      [:GIVEN]
      iex> Deeply.to_list(%{}, lens)
      [:DEFAULT]

  The default value can even be used by later lenses:

      iex> lens =
      ...>   Lens.either(Lens.key?(:a), Lens.const(%{bb: :BB_DEFAULT_VALUE}))
      ...>   |> Lens.key(:bb)
      iex> Deeply.to_list(%{a: %{bb: :GIVEN}}, lens)
      [:GIVEN]
      iex> Deeply.to_list(%{}, lens)
      [:BB_DEFAULT_VALUE]

  However, this defaulting is not as useful as it seems.

  First, you must take care to use `key?` and not, say,
  `Lens2.Lenses.Keyed.lens/1`.  The latter *will* produce a value for a
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

  Compare that to using `key/1` or `Kernel.put_in/1

      iex> Deeply.put(%{}, Lens.key(:a), :NEW)
      %{a: :NEW}
      iex> put_in(%{}, [:a], :NEW)
      %{a: :NEW}

  I think this is all too confusing to justify using `const`.
  """

  @spec const(any) :: Lens.lens
  deflens_raw const(value) do
    fn _data, fun ->
      {res, updated} = fun.(value)
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
       iex>  Deeply.to_list(returns, lens)
       [1, 2]

  Note the use of `empty/0` to handle the "don't care" case.

  """
  @spec match((any -> Lens2.lens)) :: Lens2.lens
  deflens_raw match(matcher_fun) do
    fn data, fun ->
      Deeply.get_and_update(data, matcher_fun.(data), fun)
    end
  end


  @doc ~S"""
  Use multiple lenses to convert a single pointer into a multitude of
  them (usually into the next level down).

  Suppose you have an enumeration of tuple and want to point to the
  values at indices 0, 1, and 3. You can do that like this:

      iex> lens = Lens.multiple([Lens.at(0), Lens.at(1), Lens.at(3)])
      iex> list = [0, 1, 2, 3, 4]
      iex> Deeply.to_list(list, lens)
      [0, 1, 3]
      iex> Deeply.update(list, lens, & &1 * 1111)
      [0, 1111, 2, 3333, 4]

  This is essentially the implementation of `Lens2.Lenses.Indexed.indices/1`.
  """
  @spec multiple([Lens2.lens]) :: Lens2.lens
  deflens multiple(lenses), do: lenses |> Enum.reverse() |> Enum.reduce(empty(), &both/2)

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
      iex> Deeply.to_list(list, lens)
      [0, 0, 2, 3, 4, 6, 6]

  You might be surprised by the duplications in the result (I was!),
  but that shows that the two lenses are independent. `by_2` produces
  pointers to `0`, `2, `4`, and `6`. `by_3` produces pointers to `0`,
  `3`, and `6`. `both/2`, when used by `Deeply.to_list` just gathers
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
  deflens_raw both(lens1, lens2) do
    fn data, fun ->
      {res1, changed1} = Deeply.get_and_update(data, lens1, fun)
      {res2, changed2} = Deeply.get_and_update(changed1, lens2, fun)
      {res1 ++ res2, changed2}
    end
  end


  @doc ~S"""
  """
  @spec seq(Lens2.lens, Lens2.lens) :: Lens2.lens
  deflens_raw seq(lens1, lens2) do
    fn data, fun ->
      {res, changed} =
        Deeply.get_and_update(data, lens1, fn item ->
          Deeply.get_and_update(item, lens2, fun)
        end)

      {Enum.concat(res), changed}
    end
  end

  @doc ~S"""
  """
  @spec seq_both(Lens2.lens, Lens2.lens) :: Lens2.lens
  deflens seq_both(lens1, lens2), do: both(seq(lens1, lens2), lens1)


  @doc ~S"""
  Use a `descender` lens to replace one or more pointers with all the matching pointers below them.

  The `descender` lens is used recursively. Here is an example. (For a less terse explanation, see <<<<>>>>>

  Consider this structure:

      %{below:
           %{..., below: ...}}

  `Lens.key?(:below)` will transform a pointer to the root into a
  pointer to the first substructure:

           %{..., below: ...}}

  This function can use that lens to give you pointers all the places under a `:below` key:

      iex> lens = Lens.levels_below(Lens.key?(:below))
      iex> tree = %{below:
      ...>           %{value: 1, below:
      ...>                         %{value: 2}}}
      iex> Deeply.to_list(tree, lens)
      [%{value: 2},
       %{value: 1, below: %{value: 2}}
       # Note that the original `tree` is not included.
      ]

  Given pointers to the levels, a later lens can point to values at all of those levels:

      iex> lens = Lens.levels_below(Lens.key?(:below)) |> Lens.key(:value)
      iex> tree = %{below:
      ...>           %{value: 1, below:
      ...>                         %{value: 2}}}
      iex> Deeply.update(tree, lens, & &1 * 111111)
      %{below:
         %{value: 111111, below:
                          %{value: 222222}}}
      ...>
      iex> Deeply.to_list(tree, lens)
      [2, 1]

  See `add_levels_below/1` for a lens that doesn't replace the
  top-level pointers, but rather adds to them.

  This name is a synonym for `recur/1`, the name in the original `Lens` package.
  """
  @spec levels_below(Lens2.lens) :: Lens2.lens
  deflens_raw levels_below(descender), do: &do_recur(descender, &1, &2)

  @doc ~S"""

  "Explode" one pointer into many pointers into recursive levels within the original
  container, plus the original pointer.

  You have a pointer into a nested container. You want pointers into
  each nested level of the container, with the levels defined by a
  lens.
  """
  @spec add_levels_below(Lens2.lens) :: Lens2.lens
  deflens add_levels_below(descender) do
    pointers_below = levels_below(descender)
    both(root(), pointers_below)
  end


  @doc ~S"""
  """
  @spec recur(Lens2.lens) :: Lens2.lens
  deflens recur(descender), do: levels_below(descender)

  @doc ~S"""
  """
  @spec recur_root(Lens2.lens) :: Lens2.lens
  deflens recur_root(descender), do: add_levels_below(descender)

  defp do_recur(lens, data, fun) do
    {res, changed} =
      Deeply.get_and_update(data, lens, fn item ->
        {results, changed1} = do_recur(lens, item, fun)
        {res_parent, changed2} = fun.(changed1)
        {results ++ [res_parent], changed2}
      end)

    {Enum.concat(res), changed}
  end

  @doc """
  """
  @spec context(Lens2.lens, Lens2.lens) :: Lens2.lens
  deflens_raw context(context_lens, item_lens) do
    fn data, fun ->
      {results, changed} =
        Deeply.get_and_update(data, context_lens, fn context ->
          Deeply.get_and_update(context, item_lens, fn item -> fun.({context, item}) end)
        end)

      {Enum.concat(results), changed}
    end
  end

  @doc ~S"""
  """
  @spec either(Lens2.lens, Lens2.lens) :: Lens2.lens
  deflens_raw either(lens, other_lens) do
    fn data, fun ->
      case Deeply.get_and_update(data, lens, fun) do
        {[], _updated} -> Deeply.get_and_update(data, other_lens, fun)
        {res, updated} -> {res, updated}
      end
    end
  end
end
