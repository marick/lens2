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

      replacement = replacement_kv(lens_arg, updated, descend_which)
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
          replacement = replacement_kv(lens_arg, updated, descend_which)
          {[gotten], BiMap.put(container, replacement)}
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

    def multimap_ignore_missing(lens_arg, container, descender, descend_which) do
      BiMultiMap.to_list(container)
      |> Enum.reduce({[], BiMultiMap.new}, fn kv, {building_gotten, building_updated} ->
        if relevant?(kv, lens_arg, descend_which) do
          {gotten_from_one, updated_from_one} =
            kv
            |> choose(descend_which)
            |> descender.()
          replacement = replacement_kv(kv, updated_from_one, descend_which)
          {
            [gotten_from_one | building_gotten],
            BiMultiMap.put(building_updated, replacement)
          }
        else
          {building_gotten, BiMultiMap.put(building_updated, kv)}
        end
      end)
    end

    # Note that the multimap cases could be fairly easily extended to
    # handle `keys?([:a, :b])`, in that the test if a key (or value)
    # is relevant would be `x in lens_arg` instead of `x ===
    # lens_arg`. That would be more O(n) than O(n^2), but I haven't
    # bothered.


    # Here are the functions that depend on the `descend_which` parameters. They
    # are primarily about picking either the first or second value of a tuple, or
    # about flipping them.

    def relevant?({k, _v}, lens_arg,  :descend_value), do: k === lens_arg
    def relevant?({_k, v}, lens_arg,  :descend_key),   do: v === lens_arg

    def choose(   {_k, v},            :descend_value), do: v
    def choose(   {k, _v},            :descend_key),   do: k

    def replacement_kv(   {k, _v},  new_value, :descend_value), do: {k, new_value}
    def replacement_kv(   {_k, v},  new_key,   :descend_key),   do: {new_key, v}
    def replacement_kv(   lens_arg, new_value, :descend_value), do: {lens_arg, new_value}
    def replacement_kv(   lens_arg, new_key,   :descend_key),   do: {new_key, lens_arg}


    # These are intermediate functions. Their purpose is to switch on whether the
    # container is a BiMap or a BiMultiMap.

    def _key(key, %BiMap{} = container, descender, fetcher_name),
        do: bimap(key, container, descender, fetcher_name, :descend_value)

    def _key?(key, %BiMap{} = container, descender),
        do: bimap_ignore_missing(key, container, descender, :fetch, :descend_value)
    def _key?(key, %BiMultiMap{} = container, descender),
        do: multimap_ignore_missing(key, container, descender, :descend_value)


    def _to_key(value, %BiMap{} = container, descender, fetcher_name),
        do: bimap(value, container, descender, fetcher_name, :descend_key)

    def _to_key?(value, %BiMap{} = container, descender),
        do: bimap_ignore_missing(value, container, descender, :fetch_key, :descend_key)
    def _to_key?(value, %BiMultiMap{} = container, descender),
        do: multimap_ignore_missing(value, container, descender, :descend_key)


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

  section "RETURN ALL KEYS OR ALL VALUES" do

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
             do: Lens.update_into(BiMap.new, Lens.all |> Lens.at(1))

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
      Lens.into(Lens.all |> Lens.at(0), BiMap.new)
    end
  end


  section "SKIPPING OVER MISSING (key? and friends)" do

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

  end

  section "MISSING KEYS OR VALUES RAISE ERRORS" do
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


  section "MISSING KEYS OR VALUES USE NIL" do

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
  end
end
