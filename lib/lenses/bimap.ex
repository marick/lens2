defmodule Lens2.Lenses.BiMap do
  use Lens2

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
  """

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
  def_composed_maker all_values() do
    Lens.into(Lens.all |> Lens.at(1), BiMap.new)
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
  def_composed_maker all_keys() do
    Lens.into(Lens.all |> Lens.at(0), BiMap.new)
  end

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

  def_maker key(key) do
    fn bimap, descender ->
      {gotten, updated} = descender.(BiMap.get(bimap, key))
      {[gotten], BiMap.put(bimap, key, updated)}
    end
  end

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
  def_maker key?(key) do
    fn bimap, descender ->
      case BiMap.fetch(bimap, key) do
        :error ->
          {[], bimap}
        {:ok, value} ->
          {gotten, updated} = descender.(value)
          {[gotten], BiMap.put(bimap, key, updated)}
      end
    end
  end

  @doc """
  Like `key/1` and `key?/1` except that the lens will raise an error for a missing key.

  This works the same as `Lens2.Lenses.Keyed.key!/1`.

      iex>  bimap = BiMap.new(a: 1)
      iex>  Deeply.put(bimap, Lens.BiMap.key!(:a), :NEW)
      BiMap.new(a: :NEW)
      iex>  Deeply.put(bimap, Lens.BiMap.key!(:missing), :NEW)
      ** (ArgumentError) key :missing not found in: BiMap.new([a: 1])
  """
  def_maker key!(key) do
    fn bimap, descender ->
      {gotten, updated} = descender.(BiMap.fetch!(bimap, key))
      {[gotten], BiMap.put(bimap, key, updated)}
    end
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
  def_composed_maker keys(keys) do
    keys |> Enum.map(&key/1) |> Lens.multiple
  end

  @doc """
  Point at the values of an `Enumeration` of [`BiMap`](https://hexdocs.pm/bimap/readme.html) keys, ignoring missing keys.
  """
  def_composed_maker keys?(keys) do
    keys |> Enum.map(&key?/1) |> Lens.multiple
  end

  # @doc """
  # Differs from `missing` in that the missing key is passed to a `map` function.

  # This is useful when adding keys to a map, where the value somehow depends on the key.

  #    A.map(bimap, LensX.bimap_keys([:a, :b]), fn missing_key ->
  #      // create a process that remembers the `missing_key` and put it into the
  #      // BiMap under the `missing_ley`
  #    end

  # """
  # def_maker missing_keys(list) do
  #   fn bimap, descender ->
  #     reducer =
  #       fn key, {gotten_so_far, updated_so_far} ->
  #         if BiMap.has_key?(bimap, key) do
  #           {gotten_so_far, updated_so_far}
  #         else
  #           {gotten, updated} = descender.(key)
  #           {[gotten | gotten_so_far], BiMap.put(updated_so_far, key, updated)}
  #         end
  #       end

  #     {gotten_final, updated_final} = Enum.reduce(list, {[], bimap}, reducer)
  #     {gotten_final, updated_final}
  #   end
  # end
end
