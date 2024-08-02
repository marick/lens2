defmodule Lens2.Lenses.Keyed do
  @moduledoc """
  Lenses helpful for working with structs, maps, and types implementing the `Access` behaviour.

  Unlike `Access`, these functions make no distinction between structs
  and lenses. All operate on both. `Lens2.Deeply.put/3` and
  `Lens2.Deeply.update/3` will return a plain map if given one. If
  given a struct, they will return a struct of the same type.

  These lenses are available under the `Lens` alias when you `use Lens2`.

  These lenses can be used on `Keyword` lists, but
  the results may surprise you.

  1. Operations apply only to the first matching key:

          iex>  use Lens2
          iex>  keylist = [a: 1, other: 2, a: 3]
          iex>  Deeply.get_all(keylist, Lens.key(:a))
          [1]         # not [1, 3]
          iex>  Deeply.get_all(keylist, Lens.keys([:a, :other]))
          [1, 2]      # not [1, 2, 3]

  2. Update operations will produce maps rather than keyword lists.

  See the `Lens2.Lenses.Keyword` module for an alternative.
  """
  use Lens2.Makers
  alias Lens2.Helpers.DefOps
  alias Lens2.Lenses
  alias Lenses.{Combine,Indexed}

  # `def_composed_maker` doesn't cooperate with guards, so need an explicit precondition.
  defmacrop assert_list(first_arg) do
    quote do
      unless is_list(unquote(first_arg)) do
        {name, arity} =  __ENV__.function
        raise "#{name}/#{arity} takes a list as its argument."
      end
    end
  end

  @doc ~S"""
  Returns a lens that points to the value of `key`.

      iex>  lens = Lens.key(:a)
      iex>  %SomeStruct{a: 1, b: 2} |> Deeply.put(lens, :NEW)
      %SomeStruct{a: :NEW, b: 2}

  If the key doesn't exist in the map, a `nil` will be used instead.

      iex>  lens = Lens.key(:missing)
      iex>  %{a: 1, b: 2} |> Deeply.put(lens, :NEW)
      %{a: 1, b: 2, missing: :NEW}
      iex>  %{} |> Deeply.update(lens, fn nil -> :NEW end)
      %{missing: :NEW}

  `Lens2.Deeply.get_all/2` and `Lens2.Deeply.get_only/2` treats maps and
  structs the same when it comes to missing keys. That is, a `KeyError` is *not*
  raised as it would be for `struct[:some_misslelled_key]`:

      iex>  lens = Lens.key(:missing)
      iex>  %{a: 1, b: 2} |> Deeply.get_all(lens)
      [nil]
      iex>  %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)
      [nil]

  Like `Map.put`, you can use this lens to break the
  contract of a struct and add keys undeclared with `defstruct/1`:

      iex>  %SomeStruct{a: 1, b: 2} |> Map.put(:missing, :NEW)
      %{missing: :NEW, a: 1, __struct__: Lens2.Lenses.KeyedTest.SomeStruct, b: 2}

      iex>  lens = Lens.key(:missing)
      iex>  %SomeStruct{a: 1, b: 2} |> Deeply.put(lens, :NEW)
      %{missing: :NEW, a: 1, __struct__: Lens2.Lenses.KeyedTest.SomeStruct, b: 2}

  Don't do that.

  `key!/1` is more appropriate for structs.
  """

  @spec key(any) :: Lens2.lens
  def_maker key(key) do
    fn container, descender ->
      {gotten, updated} = descender.(DefOps.get(container, key))
      {[gotten], DefOps.put(container, key, updated)}
    end
  end

  @doc ~S"""
  Returns a lens that points to the value of the given key. If the
  key does not exist an error will be raised.

      iex> lens = Lens.key!(:missing)
      iex> %{a: 1} |> Deeply.put(lens, :NEW)
      ** (KeyError) key :missing not found in: %{a: 1}
  """
  @spec key!(any) :: Lens2.lens
  def_maker key!(key) do
    fn container, descender ->
      {gotten, updated} = descender.(DefOps.fetch!(container, key))
      {[gotten], DefOps.put(container, key, updated)}
    end
  end


  @doc ~S"""
  Returns a lens that points to the value of the given key. If
  the key does not exist it points to nothing.

  Here is the difference between this function and
  `Lens2.Lenses.Keyed.key/1` when it comes to retrieving values:

      iex> %{a: 1} |> Deeply.get_all(Lens.key?(:missing))
      []
      iex> %{a: 1} |> Deeply.get_all(Lens.key(:missing))
      [nil]

  This function cannot be used to add missing values:

      iex> %{a: 1} |> Deeply.put(Lens.key?(:missing), :NEW)
      %{a: 1}
      iex> %{a: 1} |> Deeply.put(Lens.key(:missing), :NEW)
      %{a: 1, missing: :NEW}

  It *can* however be used on a key that's *present* but has a `nil` value:

      iex> %{here: nil} |> Deeply.put(Lens.key?(:here), :NEW)
      %{here: :NEW}

  This behavior differs from `Access.key/1` or the shorthand form
  `put_in(..., [..., :key, ...] ...)`.
  Use `key/1` for that.
  """
  @spec key?(any) :: Lens2.lens
  def_maker key?(key) do
    fn container, descender ->
      case DefOps.fetch(container, key) do
        :error ->
          {[], container}

        {:ok, value} ->
          {gotten, updated} = descender.(value)
          {[gotten], DefOps.put(container, key, updated)}
      end
    end
  end

  @doc ~S"""
  Returns a lens that points to the values of the given keys.

  It has the same behavior as `Lens2.Lenses.key/1`, just for multiple keys at once.

      iex>  map = %{a: 1, b: 2}
      iex>  lens = Lens.keys([:a, :b, :missing])
      iex>  map |> Deeply.get_all(lens) |> Enum.sort
      [1, 2, nil]
      iex>  map |> Deeply.update(lens, fn
      ...>    nil -> :NEW
      ...>    x   -> 1111 * x
      ...>  end)
      %{a: 1111, b: 2222, missing: :NEW}

  The list can be empty, which gets nothing and updates nothing.

      iex> lens = Lens.keys([])
      iex> %{a: 1} |> Deeply.get_all(lens)
      []
      iex> %{a: 1} |> Deeply.put(lens, :NEW)
      %{a: 1}

  That's the same behavior as `Lens2.Lenses.Basic.empty/0`.
  """
  @spec keys(list(any)) :: Lens2.lens
  def_composed_maker keys(keys) do
    assert_list(keys)
    keys |> Enum.map(&key/1) |> Combine.multiple
  end

  @doc ~S"""
  Returns a lens that points to the values of the given keys. If any of
  the keys doesn't exist, `Lens2.Deeply` functions raise an error.

  It has the same behavior as `key!/1`, just for multiple keys at once.

      iex>  lens = Lens.keys!([:a, :b])
      iex>  %{a: 1, b: 2, c: 3} |> Deeply.get_all(lens) |> Enum.sort
      [1, 2]

      iex>  lens = Lens.keys!([:a, :missing])
      iex>  %{a: 1} |> Deeply.put(lens, :NEW)
      ** (KeyError) key :missing not found in: %{a: :NEW}
  """
  @spec keys!(list(any)) :: Lens2.lens
  def_composed_maker keys!(keys) do
    assert_list(keys)
    keys |> Enum.map(&key!/1) |> Combine.multiple
  end

  @doc ~S"""
  Returns a lens that points to the values of the given keys. If any of
  the keys does not exist, the `Lens2.Deeply` functions ignore it.

      iex>  map = %{a: 1, b: 2, c: 3}
      iex>  lens = Lens.keys?([:a, :b, :missing])
      iex>  map |> Deeply.get_all(lens) |> Enum.sort
      [1, 2]
      iex>  map |> Deeply.put(lens, :NEW)
      %{a: :NEW, b: :NEW, c: 3}
  """
  @spec keys?(list(any)) :: Lens2.lens
  def_composed_maker keys?(keys) do
    assert_list(keys)
    keys |> Enum.map(&key?/1) |> Combine.multiple
  end



  @doc ~S"""
  Concise representation for following keys into a container.

  It's pretty common to construct a lens with a pipeline like this:

  ```
      iex> lens = Lens.keys!([:a, :b]) |> Lens.key!(3)
      iex> map = %{a: %{(4-1) => :a3},
      ...>         b: %{(2+1) => :b3}}
      iex> Deeply.get_all(map, lens)
      [:a3, :b3]
  ```

  That's common enough that I provide a lens maker that takes a list
  of key or key-lists to have the same effect:

  ```
      iex> lens = Lens.key_path!([[:a, :b], 3])
      iex> map = %{a: %{(4-1) => :a3},
      ...>         b: %{(2+1) => :b3}}
      iex> Deeply.get_all(map, lens)
      [:a3, :b3]
  ```

  This could be seen as a compromise between `Access`-style definition
  and the normal lens pipeline style.

  TODO: There should be a `key_path?` and a `key_path`.
  """
  def_composed_maker key_path!(path) do
    reducer = fn key_or_keys, building_lens ->
      next_lens =
        case key_or_keys do
          keys when is_list(key_or_keys) -> keys!(keys)
          key ->                            key!(key)
        end
      Combine.seq(building_lens, next_lens)
    end


    Enum.reduce(path, Combine.root, reducer)
  end


  @doc ~S"""
  Returns a lens that points to all values of a map or struct.

      iex>  lens = Lens.map_values
      iex>  map = %{a: 1, b: 2}
      iex>  Deeply.get_all(map, lens) |> Enum.sort
      [1, 2]
      iex>  Deeply.put(map, lens, :NEW)
      %{a: :NEW, b: :NEW}

      iex>  lens = Lens.map_values
      iex>  struct = %SomeStruct{a: 1, b: 2}
      iex>  Deeply.get_all(struct, lens) |> Enum.sort
      [1, 2]
      iex>  Deeply.put(struct, lens, :NEW)
      %SomeStruct{a: :NEW, b: :NEW}

  Note: This function is changed from its
  [`Lens`](https://hexdocs.pm/lens/readme.html) equivalent. That one
  does not work with structs.
  """
  @spec map_values :: Lens2.lens
  def_maker map_values do
    fn container, get_and_update ->
      {built_list, built_container} =
        extract_keys(container)
        |> Enum.reduce({[], container}, fn key, {building_list, building_container} ->
          current_value = Map.get(container, key)
          {gotten, updated} = get_and_update.(current_value)
          {[gotten | building_list], Map.put(building_container, key, updated)}
        end)

      # reversing puts the output list in the same order as a `Map.get_all` would.
      {Enum.reverse(built_list), built_container}
    end
  end

  defp extract_keys(container) do
    cond do
      is_struct(container) ->
        container |> Map.from_struct |> Map.keys
      is_list(container) ->
        raise "`map_values` is incompatible with a keyword list: #{inspect container}"
      true ->
        container |> Map.keys
    end
  end





  @doc ~S"""
  Returns a lens that points to all keys of a map.

      iex>  lens = Lens.map_keys
      iex>  map = %{[1] => 1, [2] => 2}
      iex>  Deeply.get_all(map, lens) |> Enum.sort
      [[1], [2]]
      iex>  Deeply.update(map, lens, fn [integer] ->
      ...>    [integer * 1111]
      ...>  end)
      %{[1111] => 1, [2222] => 2}

  A lens produced by this function won't work on a struct. Updating
  struct keys themselves (as opposed to their values) makes no
  sense. And I'm hoping you won't need to use `get_all` to get all the
  keys of a struct, since all the keys are known at compile time.
  """
  @spec map_keys :: Lens2.lens
  def_composed_maker map_keys, do: Lenses.Enum.all() |> Lenses.Enum.into(%{}) |> Indexed.at(0)

end
