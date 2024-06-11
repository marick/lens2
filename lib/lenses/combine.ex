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

  **Rarely used**

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


  @doc ~S"""
  Returns a lens that ignores the data and always focuses on the given value.

  """
  @spec const(any) :: Lens.lens
  deflens_raw const(value) do
    fn _data, fun ->
      {res, updated} = fun.(value)
      {[res], updated}
    end
  end



  @doc ~S"""
  """
  @spec match((any -> Lens2.lens)) :: Lens2.lens
  deflens_raw match(matcher_fun) do
    fn data, fun ->
      Deeply.get_and_update(data, matcher_fun.(data), fun)
    end
  end


  @spec multiple([Lens2.lens]) :: Lens2.lens
  deflens multiple(lenses), do: lenses |> Enum.reverse() |> Enum.reduce(empty(), &both/2)

  @doc ~s"""
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
