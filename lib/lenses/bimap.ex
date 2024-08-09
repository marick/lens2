defmodule Lens2.Lenses.BiMap do
  use Lens2
  import Lens2.Helpers.Section
  use Private

  private do
    def relevant?({k, _v}, lens_arg,  :descend_value), do: k == lens_arg
    def relevant?({_k, v}, lens_arg,  :descend_key),   do: v == lens_arg

    def choose(   {_k, v},            :descend_value), do: v
    def choose(   {k, _v},            :descend_key),   do: k

    def new_kv(   {k, _v},  new_value, :descend_value), do: {k, new_value}
    def new_kv(   {_k, v},  new_key,   :descend_key),   do: {new_key, v}
    def new_kv(   lens_arg, new_value, :descend_value), do: {lens_arg, new_value}
    def new_kv(   lens_arg, new_key,   :descend_key),   do: {new_key, lens_arg}

    def fetch_one(container, key,   :descend_value), do: BiMap.fetch(container, key)
    def fetch_one(container, value, :descend_key), do: BiMap.fetch_key(container, value)


    def multimap_kv?(lens_arg, container, descender, descend_which) do
      BiMultiMap.to_list(container)
      |> Enum.reduce({[], BiMultiMap.new},fn kv, {building_gotten, building_updated} ->
        if relevant?(kv, lens_arg, descend_which) do
          {gotten_from_one, updated_from_one} = descender.(choose(kv, descend_which))
          {
            [gotten_from_one | building_gotten],
            BiMultiMap.put(building_updated, new_kv(kv, updated_from_one, descend_which))
          }
        else
          {building_gotten, BiMultiMap.put(building_updated, kv)}
        end
      end)
    end

    def bimap_kv?(lens_arg, %BiMap{} = container, descender, descend_which) do
      case fetch_one(container, lens_arg, descend_which) do
        :error ->
          {[], container}
        {:ok, fetched} ->
          {gotten, updated} = descender.(fetched)
          {[gotten], BiMap.put(container, new_kv(lens_arg, updated, descend_which))}
      end
    end



    def _to_key?(value, %BiMap{} = container, descender),
        do: bimap_kv?(value, container, descender, :descend_key)
    def _to_key?(value, %BiMultiMap{} = container, descender),
        do: multimap_kv?(value, container, descender, :descend_key)

    def _key?(key, %BiMap{} = container, descender),
        do: bimap_kv?(key, container, descender, :descend_value)
    def _key?(key, %BiMultiMap{} = container, descender),
        do: multimap_kv?(key, container, descender, :descend_value)
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
    defmaker all_values() do
      Lens.update_into(BiMap.new, Lens.all |> Lens.at(1))
    end

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
    def_raw_maker key?(key) do
      fn container, descender ->
        _key?(key, container, descender)
      end
    end


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
    def_raw_maker to_key?(value) do
      fn bimap, descender ->
        _to_key?(value, bimap, descender)
      end
    end

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
    def_raw_maker key!(key) do
      fn bimap, descender ->
        {gotten, updated} = descender.(BiMap.fetch!(bimap, key))
        {[gotten], BiMap.put(bimap, key, updated)}
      end
    end

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
    def_raw_maker to_key!(value) do
      fn bimap, descender ->
        {gotten, updated} = descender.(BiMap.fetch_key!(bimap, value))
        {[gotten], BiMap.put(bimap, updated, value)}
      end
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
    def_raw_maker key(key) do
      fn bimap, descender ->
        {gotten, updated} = descender.(BiMap.get(bimap, key))
        {[gotten], BiMap.put(bimap, key, updated)}
      end
    end

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
