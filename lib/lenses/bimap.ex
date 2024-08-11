defmodule Lens2.Lenses.BiMap do
  use Lens2
  import Lens2.Helpers.Section
  use Private

  private do

    # There's some perhaps-excessive parameterization here. There are three decisions
    # to consider.
    #
    # 1. Is the container a BiMap or a BiMultiMap?
    # 2. Are we descending through values (selected by key) or keys (selected by value)?
    # 3. Do we ignore missing values (as in key?), raise errors (as in key!), or
    #    use `nil` to mean "missing" (`key`)

    # Let's start with the case where we're dealing with a `Bimap`.

    # `bimap` deals with error-raising lenses (`key!` and `fetch_key!`) and
    # nil-returning lenses (`key` and `fetch_key`).
    #
    # 1. The `descend_which` argument is either `:descend_value` or `descend_key`.
    #    BiMap uses this to construct a replacement key/value pair to use with
    #    BiMap.put. (If the lookup was by key, you want the pair to be key/new-value.
    #    If it was by value, you want it to be new-key/value.)
    # 2. The `fetcher_name` could be one of `fetch!` (for `key!`),
    #    `get` (for `key`), or their inverse functions (`fetch_key!` and `get_key`)
    #
    # Note that `descend_which` could be derived from `fetcher_name`, but I prefer
    # to deal with supplied constants than calculated values.

    def bimap(
          lens_arg, container, descender, fetcher_name, descend_which) do
      fetched = apply(BiMap, fetcher_name, [container, lens_arg])
      {gotten, updated} =  descender.(fetched)

      replacement = ordered(lens_arg, updated, descend_which)
      {[gotten], BiMap.put(container, replacement)}
    end

    # `bimap_ignore_missing` is used for `key?` and `to_key?`. The difference is that
    # it has to handle a return value of type `:error | {:ok, any}`.

    def bimap_ignore_missing(
          lens_arg, container, descender, fetcher_name, descend_which) do
      fetched = apply(BiMap, fetcher_name, [container, lens_arg])
      case fetched do
        :error ->
          {[], container}
        {:ok, fetched} ->
          {gotten, updated} = descender.(fetched)
          replacement = ordered(lens_arg, updated, descend_which)
          {[gotten], BiMap.put(container, replacement)}
      end
    end

    def ordered(lens_arg, new_value, :descend_value), do: {lens_arg, new_value}
    def ordered(lens_arg, new_key,   :descend_key),   do: {new_key, lens_arg}

    # Now for the `BiMultiMap` cases. The tricky thing with `BiMultiMap` is that you
    # can't do, for example:
    #
    #     Get a value: say, a 5 associated with `:a`.
    #     Update it, by, say incrementing it.
    #     Put it back under the same key, like `BiMultiMap.put(..., :a, 6)`.
    #
    # That will *add* `{:a, 6}` to the bimultimap that *still contains* `{:a, 5}`.
    # You have to explicitly delete the old pair.
    #
    # Because a BiMultiMap `fetch` operation returns a *list* of values, instead of
    # a single value, the division between the `?`, `!`, and unadorned makers is
    # different.
    #
    # * `key!` and `to_key!` should use `fetch!` or `fetch_keys!`, which will raise
    #   rather than return a empty list.
    # * `key?` and `to_key?` can use `fetch` and `fetch_keys` and simply iterate over
    #   all the return values. If there are none, no big deal.
    # * `key` and `to_key` have to special case an `:error` return value and fake a
    #   `[nil]` return value.

    def worker(lens_arg, %BiMultiMap{} = container, descender, on_missing, descend_which) do
      fetched =
        multi_fetch(container, lens_arg, descend_which)
        |> multi_adjust_fetched(on_missing)
      {gotten, to_delete, to_put} = multi_descend(descender, lens_arg, fetched, descend_which)
      updated =
        container
        |> then(& Enum.reduce(to_delete, &1, fn kv, acc -> BiMultiMap.delete(acc, kv) end))
        |> then(& Enum.reduce(to_put, &1, fn kv, acc -> BiMultiMap.put(acc, kv) end))
      {gotten, updated}
    end

    def multi_fetch(container, lens_arg, descend_which) do
      case descend_which do
        :descend_value -> BiMultiMap.fetch(container, lens_arg)
        :descend_key -> BiMultiMap.fetch_keys(container, lens_arg)
      end
    end

    def multi_adjust_fetched({:ok, list}, _), do: list
    def multi_adjust_fetched(:error, :raise_on_missing), do: raise(KeyError, "no match in BiMultiMap")
    def multi_adjust_fetched(:error, :nil_on_missing), do: [nil]
    def multi_adjust_fetched(:error, :ignore_missing), do: []

    def multi_descend(descender, lens_arg, fetched, descend_which) do
      reducer = fn one_fetched, {building_gotten, building_delete, building_put} ->
        {lower_gotten, lower_updated} = descender.(one_fetched)
        {
          [lower_gotten | building_gotten],
          [ordered(lens_arg, one_fetched, descend_which) | building_delete],
          [ordered(lens_arg, lower_updated, descend_which) | building_put]
        }
      end

      Enum.reduce(fetched, {[], [], []}, reducer)
    end

    # Note that the multimap cases could be fairly easily extended to
    # handle `keys?([:a, :b])`, in that the test if a key (or value)
    # is relevant would be `x in lens_arg` instead of `x ===
    # lens_arg`. That would be more O(n) than O(n^2), but I haven't
    # bothered.




    # These are intermediate functions. Their purpose is to switch on whether the
    # container is a BiMap or a BiMultiMap.

    def _key(key, %BiMap{} = container, descender, fetcher_name),
        do: bimap(key, container, descender, fetcher_name, :descend_value)
    def _key(key, %BiMultiMap{} = container, descender),
        do: worker(key, container, descender, :nil_on_missing, :descend_value)

    def _key?(key, %BiMap{} = container, descender),
        do: bimap_ignore_missing(key, container, descender, :fetch, :descend_value)
    def _key?(key, %BiMultiMap{} = container, descender),
        do: worker(key, container, descender, :ignore_missing, :descend_value)


    def _to_key(value, %BiMap{} = container, descender, fetcher_name),
        do: bimap(value, container, descender, fetcher_name, :descend_key)

    def _to_key?(value, %BiMap{} = container, descender),
        do: bimap_ignore_missing(value, container, descender, :fetch_key, :descend_key)
    def _to_key?(value, %BiMultiMap{} = container, descender),
        do: worker(value, container, descender, :ignore_missing, :descend_key)
  end


  @moduledoc """

  Lens makers for the [`BiMap`](https://hexdocs.pm/bimap/readme.html)
  bidirectional map [package](https://hex.pm/packages/bimap).

  A `BiMap` allows a "reverse lookup": using a value to find the corresponding key.

      iex>  bimap = BiMap.new(%{1 => "1111", 2 => "2222"})
      iex>  BiMap.get(bimap, 1)
      "1111"
      iex>  BiMap.get_key(bimap, "1111")
      1

  A `BiMap` differs importantly from a map in that it requires
  *values*, not just keys, to be unique. This can cause some confusion
  as BiMap's `put` operation can cause existing bindings to disappear.

       iex>  bimap = BiMap.new(a: 5, b: 6)
       iex>  BiMap.put(bimap, :b, 5)
       BiMap.new(b: 5)   # where did `:a` go?

  I've found the problem gets worse with lenses (because you may be
  putting multiple places in a single call, and the place you want
  to change may be nested below the BiMap, making it harder to
  notice the constraint is relevant.) You might prefer
  [BiMultiMap](https://hexdocs.pm/bimap/BiMultiMap.html) (which comes with BiMap).

  Note that `BiMap` does not implement `Access`. However, lenses
  created with these functions do, so they can be used with `get_in/2`
  and friends.

  This module follows the convention of using names like `key` to mean
  using a key to obtain a value. Names like `to_key` go in the reverse
  direction: from value to key. Using `value(1)` to refer to the key
  `:a` would be just too weird.


  """

  section "THE CORE FUNCTIONS" do
    @doc """
    Return a lens that points at the value of a single
    [`BiMap`](https://hexdocs.pm/bimap/readme.html) key, ignoring
    missing keys.

    This works the same as `Lens2.Lenses.Keyed.key?/1`.

        iex>  bimap = BiMap.new(a: 1, b: 2)
        ...>  lens = [:a, :MISSING] |> Enum.map(&Lens.BiMap.key?/1) |> Lens.multiple
        iex>  Deeply.get_all(bimap, lens)
        [1]

    Unlike `key/1`, the returned lens cannot be used to create a missing key:

        iex> Deeply.put(BiMap.new, Lens.BiMap.key?(:missing), :NEW)
        BiMap.new
    """
    @spec key?(any) :: Lens2.lens
    def_raw_maker key?(key),
      do: fn container, descender -> _key?(key, container, descender) end

    @doc """
    Like `key/1` and `key?/1` except that the lens will raise an error for a missing key.

    This works the same as `Lens2.Lenses.Keyed.key!/1`.

        iex>  bimap = BiMap.new(a: 1)
        iex>  Deeply.put(bimap, Lens.BiMap.key!(:a), :NEW)
        BiMap.new(a: :NEW)
        iex>  Deeply.put(bimap, Lens.BiMap.key!(:missing), :NEW)
        ** (ArgumentError) key :missing not found in: BiMap.new([a: 1])
    """
    @spec key!(any) :: Lens2.lens
    def_raw_maker key!(key),
      do: fn container, descender -> _key(key, container, descender, :fetch!) end

    @doc """
    Return a lens that points at the value of a single [`BiMap`](https://hexdocs.pm/bimap/readme.html) key.

    As with `Lens2.Lenses.Keyed.key/1`, a missing key is represented with `nil`:

        iex>  bimap = BiMap.new(a: 1, b: 2)
        ...>  lens = [:a, :MISSING] |> Enum.map(&Lens.BiMap.key/1) |> Lens.multiple
        iex>  Deeply.get_all(bimap, lens) |> Enum.sort
        [1, nil]

    This lens can introduce a missing key-value pair, unlike `key?/1`.

        iex> Deeply.put(BiMap.new, Lens.BiMap.key(:missing), :NEW)
        BiMap.new(%{missing: :NEW})
    """

    @spec key(any) :: Lens2.lens
    def_raw_maker key(key),
      do: fn container, descender -> _key(key, container, descender, :get) end

    # There is no `to_key` because a `nil` key is not worth much.


    @doc """

    Return a lens that points at the key associated with a given value,
    provided there is any such value.

        iex>  bimap = BiMap.new(a: 1)
        iex>  Deeply.get_all(bimap, Lens.BiMap.to_key?(1))
        [:a]
        iex>  Deeply.get_all(bimap, Lens.BiMap.to_key?(11111))
        []

    You can create a new key-value pair with `key/1`.
    `Lens2.Deeply.put/3` will not work with this lens:

        iex> Deeply.put(BiMap.new, Lens.BiMap.to_key?("value"), :new_key)
        BiMap.new
    """
    @spec to_key?(any) :: Lens2.lens
    def_raw_maker to_key?(value),
                  do: fn bimap, descender -> _to_key?(value, bimap, descender) end


    @doc """

    Return a lens that points at the key associated with a given value. Raises an
    error if there is no such value.

        iex>  bimap = BiMap.new(a: 1)
        iex>  Deeply.get_all(bimap, Lens.BiMap.to_key!(1))
        [:a]
        iex>  Deeply.get_all(bimap, Lens.BiMap.to_key!(11111))
        ** (ArgumentError) value 11111 not found in: BiMap.new([a: 1])

    """
    @spec to_key!(any) :: Lens2.lens
    def_raw_maker to_key!(value),
      do: fn container, descender -> _to_key(value, container, descender, :fetch_key!) end


  end

  section "THE PLURAL FORMS" do
    @doc """
    Like `key?/1` but takes a list of keys.

    Missing keys are ignored.

        iex>  bimap = BiMap.new(a: 2)
        iex>  lens = Lens.BiMap.keys?([:a, :missing])
        iex>  Deeply.update(bimap, lens, & &1*1111)
        BiMap.new(a: 2222)
        iex>  Deeply.get_only(bimap, lens)
        2

    """
    @spec keys?([any]) :: Lens2.lens
    defmaker keys?(keys) do
      keys |> Enum.map(&key?/1) |> Lens.multiple
    end

    @doc """
    Like `key!/1` but takes a list of keys.

    Any missing key raises an error.

        iex>  bimap = BiMap.new(a: 2)
        iex>  lens = Lens.BiMap.keys!([:a, :missing])
        iex>  Deeply.get_only(bimap, lens)
        ** (ArgumentError) key :missing not found in: BiMap.new([a: 2])

    """
    @spec keys!([any]) :: Lens2.lens
    defmaker keys!(keys) do
      keys |> Enum.map(&key!/1) |> Lens.multiple
    end

    @doc """
    Like `key/1` but takes a list of keys.

    The value of a missing key is treated as `nil`.

        iex>  bimap = BiMap.new(a: 2)
        iex>  lens = Lens.BiMap.keys([:a, :missing])
        iex>  updater = fn
        ...>    nil -> "newly added"
        ...>    x   -> x * 1111
        ...>  end
        iex>  Deeply.update(bimap, lens, updater)
        BiMap.new(a: 2222, missing: "newly added")

    """
    @spec keys([any]) :: Lens2.lens
    defmaker keys(keys) do
      keys |> Enum.map(&key/1) |> Lens.multiple
    end

    @doc """
    Like `to_key?/1` but takes a list of values.

    Missing keys are ignored.

        iex>  bimap = BiMap.new(%{1 => "value"})
        iex>  lens = Lens.BiMap.to_keys?(["value", "some missing value"])
        iex>  Deeply.update(bimap, lens, & &1*1111)
        BiMap.new(%{1111 => "value"})
        iex>  Deeply.get_only(bimap, lens)
        1

    """
    @spec to_keys?([any]) :: Lens2.lens
    defmaker to_keys?(keys) do
      keys |> Enum.map(&to_key?/1) |> Lens.multiple
    end


    @doc """
    Like `to_key!/1` but takes a list of values.

    Any missing value raises an error.

        iex>  bimap = BiMap.new(a: 2)
        iex>  lens = Lens.BiMap.to_keys!([2, "missing value"])
        iex>  Deeply.get_all(bimap, lens)
        ** (ArgumentError) value "missing value" not found in: BiMap.new([a: 2])

    """
    @spec to_keys!([any]) :: Lens2.lens
    defmaker to_keys!(keys) do
      keys |> Enum.map(&to_key!/1) |> Lens.multiple
    end

  end

  section "MISCELLANEOUS" do

    @doc """
    Return a lens that points at all values of a [`BiMap`](https://hexdocs.pm/bimap/readme.html).

        iex>  bimap = BiMap.new(%{1 => "1111", 2 => "2222"})
        iex>  Deeply.get_all(bimap, Lens.BiMap.all_values) |> Enum.sort
        ["1111", "2222"]

    Note that using `put` with `all_values` is profoundly useless, as
    only one key/value pair can be retained – and you can't even predict
    which one it will be!

        iex>  bimap = BiMap.new(a: 1, b: 2, c: 3, d: 4, e: 5)
        iex>  updated = Deeply.put(bimap, Lens.BiMap.all_values, :NEW)
        iex>  assert [:NEW] == BiMap.values(updated)
        ...>
        iex>  [key] = BiMap.keys(updated)
        iex>  assert key in [:a, :b, :c, :d, :e]
        ...>  # On my machine, today, it turns out to be `:e`.
    """
    @spec all_values :: Lens2.lens
    defmaker all_values(),
             do: update_appropriately(Lens.all |> Lens.at(1))

    @doc """
    Return a lens that points at all keys of a [`BiMap`](https://hexdocs.pm/bimap/readme.html).

    This is useful for descending into complex keys. Consider a
    spatial BiMap that connects `{x, y}` tuples to some values
    representing physical objects at that position.

        iex>  bimap = BiMap.new(%{{0, 0} => "some data", {1, 1} => "other data"})
        iex>  Deeply.update(bimap, Lens.BiMap.all_keys,
        ...>                       fn {x, y} -> {x + 1, y + 1} end)
        iex>  BiMap.new(%{{1, 1} => "some data", {2, 2} => "other data"})

    Note that all the updates are done before the result BiMap is formed. You needn't fear
    that updating the `{0, 0}` tuple will wipe out the existing `{1, 1}` tuple.

    """
    @spec all_keys :: Lens2.lens
    defmaker all_keys() do
      update_appropriately(Lens.all |> Lens.at(0))
    end

    @doc """
    Restore results into whichever the appropriate type is.

    Suppose `values/0` didn't exist, and you were writing it as a
    pipeline. That involves treating the container as an `Enum`, getting
    key/value tuples, and then taking the second tuple element. However, that's
    a problem for update, as you get a list of tuples back:

        iex> lens = Lens.all |> Lens.at(1)
        iex> Deeply.update(BiMultiMap.new(a: 1, b: 2), lens, & &1 * 1111)
        [a: 1111, b: 2222]

    That's what `Lens2.Lenses.Enum.update_into/2` is for, except that it requires
    you to give it an empty container to fill:

        iex> lens = Lens.update_into(BiMap.new, Lens.all |> Lens.at(1))
        iex> Deeply.update(BiMultiMap.new(a: 1, b: 2), lens, & &1 * 1111)
        BiMap.new(a: 1111, b: 2222)

    Notice the resulting container is a `BiMap` even though the original
    container was a `BiMultiMap`. If you only ever use one of the two,
    that may be OK. But if you want to write a lens that works with
    both, use this function. It creates the empty container to match
    the original type:

        iex> lens = Lens.BiMap.update_appropriately(Lens.all |> Lens.at(1))
        iex> Deeply.update(BiMultiMap.new(a: 1, b: 2), lens, & &1 * 1111)
        BiMultiMap.new(a: 1111, b: 2222)
        iex> Deeply.update(BiMap.new(a: 1, b: 2), lens, & &1 * 1111)
        BiMap.new(a: 1111, b: 2222)

    This is in fact the implementation of `values/0`.
    """
    @spec update_appropriately(Lens2.lens) :: Lens2.lens
    def_raw_maker update_appropriately(lens) do
      fn %struct{} = container, descender ->
        {gotten, updated} = Deeply.get_and_update(container, lens, descender)
        {gotten, Enum.into(updated, struct.new())}
      end
    end
  end
end
