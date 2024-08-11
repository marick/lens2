defmodule Lens2.Lenses.Bi do
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

    def worker(lens_arg, %BiMap{} = container, descender, on_missing, descend_which) do
      handle_valid_result = fn fetched ->
        {gotten, updated} = descender.(fetched)
        replacement = ordered(lens_arg, updated, descend_which)
        {[gotten], BiMap.put(container, replacement)}
      end

      fetch_tuple = bimap_fetch(container, lens_arg, descend_which)

      case {on_missing, fetch_tuple} do
        {_, {:ok, fetched}} ->
          handle_valid_result.(fetched)
        {:nil_on_missing, _} ->
          handle_valid_result.(nil)
        {:raise_on_missing, _} ->
          raise_error(container, lens_arg, descend_which)
        {:ignore_missing, _} ->
          {[], container}
      end
    end

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
    # Note that all the deletions should be done before all the puts, else
    # a newly-put value might be erased by a later put.

    def worker(lens_arg, %BiMultiMap{} = container, descender, on_missing, descend_which) do
      handle_valid_result = fn fetched ->
        {gotten, to_delete, to_put} = multi_descend(descender, lens_arg, fetched, descend_which)
        updated =
          container
          |> then(& Enum.reduce(to_delete, &1, fn kv, acc -> BiMultiMap.delete(acc, kv) end))
          |> then(& Enum.reduce(to_put, &1, fn kv, acc -> BiMultiMap.put(acc, kv) end))
        {gotten, updated}
      end

      fetch_tuple = multi_fetch(container, lens_arg, descend_which)

      case {on_missing, fetch_tuple} do
        {_, {:ok, fetched}} ->
          handle_valid_result.(fetched)
        {:nil_on_missing, _} ->
          handle_valid_result.([nil])
        {:raise_on_missing, _} ->
          raise_error(container, lens_arg, descend_which)
        {:ignore_missing, _} ->
          {[], container}
      end
    end

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

    def bimap_fetch(container, lens_arg, descend_which) do
      case descend_which do
        :descend_value -> BiMap.fetch(container, lens_arg)
        :descend_key -> BiMap.fetch_key(container, lens_arg)
      end
    end

    def multi_fetch(container, lens_arg, descend_which) do
      case descend_which do
        :descend_value -> BiMultiMap.fetch(container, lens_arg)
        :descend_key -> BiMultiMap.fetch_keys(container, lens_arg)
      end
    end

    def ordered(lens_arg, new_value, :descend_value), do: {lens_arg, new_value}
    def ordered(lens_arg, new_key,   :descend_key),   do: {new_key, lens_arg}

    def raise_error(container, lens_arg, descend_which) do
      tag =
        case descend_which do
          :descend_key -> "value"
          :descend_value -> "key"
        end
      raise(ArgumentError, "#{tag} `#{inspect lens_arg}` not found in: #{inspect container}")
    end



    # Note that the multimap cases could be fairly easily extended to
    # handle `from_keys?([:a, :b])`, in that the test if a key (or value)
    # is relevant would be `x in lens_arg` instead of `x ===
    # lens_arg`. That would be more O(n) than O(n^2), but I haven't
    # bothered.
  end


  @moduledoc """
  Lens makers for the [`BiMap`](https://hexdocs.pm/bimap/readme.html)
  bidirectional map [package](https://hex.pm/packages/bimap).

  The package contains both `BiMap` and `BiMultiMap`. These lenses work with
  both.

      iex> lens = Lens.Bi.from_key(:a)
      iex> Deeply.get_all(BiMap.new(a: 5), lens)
      [5]
      iex> Deeply.get_all(BiMultiMap.new(a: 5), lens)
      [5]

  Both map types allow a fast "reverse lookup": using a value to find the corresponding key.

      iex>  bimap = BiMap.new(%{1 => "1111", 2 => "2222"})
      iex>  BiMap.get(bimap, 1)            # key to value
      "1111"
      iex>  BiMap.get_key(bimap, "1111")   # value to key
      1

  A `BiMap` differs importantly from a map in that it requires
  *values*, not just keys, to be unique. This can cause some confusion
  as `Deeply.put` can cause existing bindings to disappear.

       iex>  bimap = BiMap.new(a: 5, b: 6)
       iex>  Deeply.put(bimap, Lens.Bi.from_key!(:b), 5)
       BiMap.new(b: 5)   # where did `:a` go?

  A `BiMultiMap` doesn't have that restriction. A given key may be associated
  with multiple values *and* a given value may be associated with multiple keys.
  However, a single key/value pair can only appear once:

       iex>  multi = BiMultiMap.new(a: 5, b: 6, b: 5, b: 5, b: 5, b: 5)
       BiMultiMap.new(a: 5, b: 6, b: 5)       # only one copy of {:b, 5}
       iex>  Deeply.put(multi, Lens.Bi.from_key!(:b), 5)
       BiMultiMap.new(a: 5, b: 5)             # duplicate {:b, 5} pair is removed


  This module violates the convention of using names like `key` to mean
  using a key to obtain a value. I found myself typing `Lens.key` (etc.) when
  I meant `Lens.Bi.key`. The `from_key*` form is used to go from a key to a value;
  the `to_key*` form is used to go from a value to a key.
  """

  section "THE CORE FUNCTIONS" do
    @doc """
    Return a lens that points at the value or values of a single
    key, ignoring
    missing keys.

    This works the same as `Lens2.Lenses.Keyed.key?/1`.

        iex>  bimap = BiMap.new(a: 1, b: 2)
        iex>  lens = Lens.both(Lens.Bi.from_key?(:a), Lens.Bi.from_key?(:MISSING))
        iex>  Deeply.get_all(bimap, lens)
        [1]

    Unlike `from_key/1`, the returned lens cannot be used to create a missing key:

        iex> Deeply.put(BiMap.new, Lens.Bi.from_key?(:missing), :NEW)
        BiMap.new
    """
    @spec from_key?(any) :: Lens2.lens
    def_raw_maker from_key?(key) do
      fn container, descender ->
        worker(key, container, descender, :ignore_missing, :descend_value)
      end
    end

    @doc """
    Like `from_key/1` and `from_key?/1` except that the lens will raise an error for a missing key.

    This works the same as `Lens2.Lenses.Keyed.key!/1`.

        iex>  multi = BiMultiMap.new(a: 1)
        iex>  Deeply.put(multi, Lens.Bi.from_key!(:a), :NEW)
        BiMultiMap.new(a: :NEW)
        iex>  Deeply.put(multi, Lens.Bi.from_key!(:missing), :NEW)
        ** (ArgumentError) key `:missing` not found in: BiMultiMap.new([a: 1])
    """
    @spec from_key!(any) :: Lens2.lens
    def_raw_maker from_key!(key) do
      fn container, descender ->
        worker(key, container, descender, :raise_on_missing, :descend_value)
      end
    end

    @doc """
    Point at all values associated with a key. (`BiMap` will have only
    one, `BiMultiMap` may have several.)

    As with `Lens2.Lenses.Keyed.key/1`, a missing key is represented with `nil`:

        iex>  bimap = BiMap.new(a: 1, b: 2)
        ...>  lens = Lens.both(Lens.Bi.from_key(:a), Lens.Bi.from_key(:MISSING))
        iex>  Deeply.get_all(bimap, lens) |> Enum.sort
        [1, nil]

    This lens can introduce a missing key-value pair:

        iex> Deeply.put(BiMap.new, Lens.Bi.from_key(:missing), :NEW)
        BiMap.new(%{missing: :NEW})
    """

    @spec from_key(any) :: Lens2.lens
    def_raw_maker from_key(key) do
      fn container, descender ->
        worker(key, container, descender, :nil_on_missing, :descend_value)
      end
    end


    @doc """

    Return a lens that points at the key(s) associated with a given value,
    provided there is any such value.

    If there is no such value, nothing is done.

        iex>  bimap = BiMap.new(a: 1)
        iex>  Deeply.get_all(bimap, Lens.Bi.to_key?(1))
        [:a]
        iex>  Deeply.get_all(bimap, Lens.Bi.to_key?(11111))
        []

    You can't create a new key-value pair with this function. See `to_key/1`.
    """
    @spec to_key?(any) :: Lens2.lens
    def_raw_maker to_key?(value) do
      fn container, descender ->
        worker(value, container, descender, :ignore_missing, :descend_key)
      end
    end


    @doc """
    Return a lens that points at the key(s) associated with a given value. Raises an
    error if there is no such value.

        iex>  bimap = BiMap.new(a: 1)
        iex>  Deeply.get_all(bimap, Lens.Bi.to_key!(1))
        [:a]
        iex>  Deeply.get_all(bimap, Lens.Bi.to_key!(11111))
        ** (ArgumentError) value `11111` not found in: BiMap.new([a: 1])

    """
    @spec to_key!(any) :: Lens2.lens
    def_raw_maker to_key!(value) do
      fn container, descender ->
        worker(value, container, descender, :raise_on_missing, :descend_key)
      end
    end

    @doc """
    Return a lens that points at the key(s) associated with a given value. `nil`
    is used if there is no such value.

        iex> multi = BiMultiMap.new(a: 1, b: 2, a: 2)
        iex> Deeply.update(multi, Lens.Bi.to_key(2), &inspect/1)
        BiMultiMap.new([{:a, 1}, {":b", 2}, {":a", 2}])
        iex> Deeply.update(multi, Lens.Bi.to_key(38), &inspect/1)
        BiMultiMap.new([{:a, 1}, {:b, 2},   {:a, 2}, {"nil", 38}])

    Whether being able to create a key that's some variant of `nil` is actually useful, well...
    """

    @spec to_key(any) :: Lens2.lens
    def_raw_maker to_key(key) do
      fn container, descender ->
        worker(key, container, descender, :nil_on_missing, :descend_key)
      end
    end
  end

  section "THE PLURAL FORMS" do
    @doc """
    Like `from_key?/1` but takes a list of keys.

    Missing keys are ignored.

        iex>  bimap = BiMap.new(a: 2)
        iex>  lens = Lens.Bi.from_keys?([:a, :missing])
        iex>  Deeply.update(bimap, lens, & &1*1111)
        BiMap.new(a: 2222)
        iex>  Deeply.get_only(bimap, lens)
        2

    """
    @spec from_keys?([any]) :: Lens2.lens
    defmaker from_keys?(keys) do
      keys |> Enum.map(&from_key?/1) |> Lens.multiple
    end

    @doc """
    Like `from_key!/1` but takes a list of keys.

    Any missing key raises an error.

        iex>  bimap = BiMap.new(a: 2)
        iex>  lens = Lens.Bi.from_keys!([:a, :missing])
        iex>  Deeply.get_only(bimap, lens)
        ** (ArgumentError) key `:missing` not found in: BiMap.new([a: 2])

    """
    @spec from_keys!([any]) :: Lens2.lens
    defmaker from_keys!(keys) do
      keys |> Enum.map(&from_key!/1) |> Lens.multiple
    end

    @doc """
    Like `from_key/1` but takes a list of keys.

    The value of a missing key is treated as `nil`.

        iex>  bimap = BiMap.new(a: 2)
        iex>  lens = Lens.Bi.from_keys([:a, :missing])
        iex>  updater = fn
        ...>    nil -> "newly added"
        ...>    x   -> x * 1111
        ...>  end
        iex>  Deeply.update(bimap, lens, updater)
        BiMap.new(a: 2222, missing: "newly added")

    """
    @spec from_keys([any]) :: Lens2.lens
    defmaker from_keys(keys) do
      keys |> Enum.map(&from_key/1) |> Lens.multiple
    end

    @doc """
    Like `to_key?/1` but takes a list of values.

    Missing keys are ignored.

        iex>  bimap = BiMap.new(%{1 => "value"})
        iex>  lens = Lens.Bi.to_keys?(["value", "some missing value"])
        iex>  Deeply.update(bimap, lens, & &1*1111)
        BiMap.new(%{1111 => "value"})
        iex>  Deeply.get_all(bimap, lens)
        [1]

    """
    @spec to_keys?([any]) :: Lens2.lens
    defmaker to_keys?(keys) do
      keys |> Enum.map(&to_key?/1) |> Lens.multiple
    end


    @doc """
    Like `to_key!/1` but takes a list of values.

    Any missing value raises an error.

        iex>  bimap = BiMap.new(a: 2)
        iex>  lens = Lens.Bi.to_keys!([2, "missing value"])
        iex>  Deeply.get_all(bimap, lens)
        ** (ArgumentError) value `"missing value"` not found in: BiMap.new([a: 2])

    """
    @spec to_keys!([any]) :: Lens2.lens
    defmaker to_keys!(keys) do
      keys |> Enum.map(&to_key!/1) |> Lens.multiple
    end


    @doc """
    Like `to_key/1` but takes a list of values.

        iex> container = BiMultiMap.new(a: 1, b: 2, a: 2)
        iex> lens = Lens.Bi.to_keys([1, 2])
        iex> Deeply.update(container, lens, &inspect/1)
        BiMultiMap.new([{":a", 1}, {":b", 2}, {":a", 2}])
    """
    @spec to_keys([any]) :: Lens2.lens
    defmaker to_keys(keys) do
      keys |> Enum.map(&to_key/1) |> Lens.multiple
    end

  end

  section "MISCELLANEOUS" do
    @doc """
    Return a lens that points at all key/value pairs.

    `Deeply.get_all` will return a `List` of `{key, value} tuples`.

        iex>  bimap = BiMap.new(%{1 => 10, 2 => 20})
        iex>  Deeply.get_all(bimap, Lens.Bi.all) |> Enum.sort
        [{1, 10}, {2, 20}]

    `Lens2.Lenses.Enum.all/0` would do the same. However, it would return a
    list in the case of `Deeply.update`, whereas `all/0` wraps the
    result in an appropriate bidirectional map:

        iex>  bimap = BiMap.new(%{1 => 10, 2 => 20})
        iex>  tweak_tuple = fn {k, v} -> {k-1, v+1} end
        iex>  Deeply.update(bimap, Lens.all, tweak_tuple) |> Enum.sort
        [{0, 11}, {1, 21}]     # List is because we used `Lens.all`, not `Lens.Bi.all`
        ...>
        iex>  Deeply.update(bimap, Lens.Bi.all, tweak_tuple)
        BiMap.new(%{0 => 11, 1 => 21})

    `Deeply.put` is weird and useless because you can only create a singleton map (as duplicate
    `{key, value}` tuples will be removed):

        iex>  multi = BiMultiMap.new(a: 1, b: 2)
        iex>  Deeply.put(multi, Lens.Bi.all, {:z, 9})  # adds the key/value pair twice
        BiMultiMap.new(z: 9)
    """
    defmaker all(), do: update_appropriately(Lens.all)

    @doc """
    Return a lens that points at all values.

        iex>  container = BiMultiMap.new(a: 1, b: 2, a: 2)
        iex>  Deeply.get_all(container, Lens.Bi.all_values) |> Enum.sort
        [1, 2, 2]   # Note duplicates

    Note that using `put` with `all_values` is profoundly useless for a `BiMap`, as
    only one key/value pair can be retained – and you can't even predict
    which one it will be!

        iex>  bimap = BiMap.new(a: 1, b: 2, c: 3, d: 4, e: 5)
        iex>  updated = Deeply.put(bimap, Lens.Bi.all_values, :NEW)
        iex>  assert [:NEW] == BiMap.values(updated)
        ...>
        iex>  [key] = BiMap.keys(updated)
        iex>  assert key in [:a, :b, :c, :d, :e]
        ...>  # On my machine, today, it turns out to be `:e`.

    `Deeply.put` works with `BiMultiMaps`:

        iex>  multi = BiMultiMap.new(a: 1, b: 2, c: 3, d: 4, e: 5)
        iex>  Deeply.put(multi, Lens.Bi.all_values, :NEW)
        BiMultiMap.new(a: :NEW, b: :NEW, c: :NEW, d: :NEW, e: :NEW)

    """
    @spec all_values :: Lens2.lens
    defmaker all_values(),
             do: update_appropriately(Lens.all |> Lens.at(1))

    @doc """
    Return a lens that points at all keys.

    This is useful for descending into complex keys. Consider a
    spatial BiMap that connects `{x, y}` tuples to some values
    representing physical objects at that position.

        iex>  bimap = BiMap.new(%{{0, 0} => "some data", {1, 1} => "other data"})
        iex>  Deeply.update(bimap, Lens.Bi.all_keys,
        ...>                       fn {x, y} -> {x + 1, y + 1} end)
        iex>  BiMap.new(%{{1, 1} => "some data", {2, 2} => "other data"})

    Note that all the updates are done before the result map is formed. You needn't fear
    that updating the `{0, 0}` tuple will wipe out the existing `{1, 1}` tuple.

    """
    @spec all_keys :: Lens2.lens
    defmaker all_keys() do
      update_appropriately(Lens.all |> Lens.at(0))
    end

    @doc """
    Restore results into whichever the appropriate type is.

    Suppose `all_values/0` didn't exist, and you were writing it as a
    pipeline. That involves treating the container as an `Enum`, getting
    key/value tuples, and then taking the second tuple element. However, that's
    a problem for update, as you get a list of tuples back:

        iex> lens = Lens.all |> Lens.at(1)
        iex> Deeply.update(BiMultiMap.new(a: 1, b: 2), lens, & &1 * 1111)
        [{:a, 1111}, {:b, 2222}]  # more commonly printed as [a: 1111, b: 2222]

    Outside this package, you'd use `Lens2.Lenses.Enum.update_into/2`
    to "coerce the type." You can use that here too:

        iex> lens = Lens.update_into(BiMap.new, Lens.all |> Lens.at(1))
        iex> Deeply.update(BiMultiMap.new(a: 1, b: 2), lens, & &1 * 1111)
        BiMap.new(a: 1111, b: 2222)

    Notice the resulting container is a `BiMap` even though the original
    container was a `BiMultiMap`. If you only ever use one of the two,
    that may be OK. But if you want to write a lens that works with
    both, use this function. It creates the empty container to match
    the original type:

        iex> lens = Lens.Bi.update_appropriately(Lens.all |> Lens.at(1))
        iex> Deeply.update(BiMultiMap.new(a: 1, b: 2), lens, & &1 * 1111)
        BiMultiMap.new(a: 1111, b: 2222)
        iex> Deeply.update(BiMap.new(a: 1, b: 2), lens, & &1 * 1111)
        BiMap.new(a: 1111, b: 2222)

    This is in fact the implementation of `all_values/0`.
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
