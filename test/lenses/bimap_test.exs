defmodule Lens2.Lenses.BiMapTest do
  use Lens2.Case, async: true

  doctest Lens2.Lenses.BiMap

  test "all_values" do
    input = BiMap.new(%{1 => %{a: 1, b: 2}, 2 => %{a: 11, b: 22}})

    lens = Lens.BiMap.all_values |> Lens.key(:a)

    assert Deeply.get_all(input, lens) == [1, 11]

    actual = Deeply.put(input, lens, :xyzzy)
    assert actual == BiMap.new(%{1 => %{a: :xyzzy, b: 2}, 2 => %{a: :xyzzy, b: 22}})

    # Note that `put` is bad when a BiMap is on the end because they can't have
    # duplicate values, so BiMap.new(a: 5, b: 5) is collapsed into a single value.

    assert Deeply.put(BiMap.new(a: 1, b: 2), Lens.BiMap.all_values, 5) |> BiMap.size == 1

    actual = Deeply.update(input, lens, & &1 * 1000)
    assert actual == BiMap.new(%{1 => %{a: 1000, b: 2}, 2 => %{a: 11_000, b: 22}})
  end

  test "bimap_keys/1" do
    # This should work akin to operating on maps, so let's start with this oracle
    # lens:
    oracle = Lens.keys([:a, :missing]) |> Lens.filter(& &1 == nil)
    map = %{a: 323, b: 111}

    assert Deeply.get_all(map, oracle) == [nil]
    assert Deeply.put(map, oracle, :xyzzy) == %{a: 323, b: 111, missing: :xyzzy}
    Deeply.update(map, oracle, fn nil -> :erlang.make_ref end)
    |> assert_fields(a: 323,
                     b: 111,
                     missing: &is_reference/1)


    lens = Lens.BiMap.keys([:a, :missing]) |> Lens.filter(& &1 == nil)
    bimap = BiMap.new(map)

    assert Deeply.get_all(bimap, lens) == [nil]
    assert Deeply.put(bimap, lens, :xyzzy) == BiMap.new(a: 323, b: 111, missing: :xyzzy)
    %BiMap{} = result = Deeply.update(bimap, lens, fn nil -> :erlang.make_ref end)

    assert BiMap.get(result, :a) == 323
    assert BiMap.get(result, :b) == 111
    assert BiMap.get(result, :missing) |> is_reference
  end

  # test "bimap_missing_keys/1" do
  #   lens = Lens.key(:a) |> Lens.BiMap.bimap_missing_keys([:a, :b, :c])
  #   data = %{a: BiMap.new(%{a: 1})}

  #   Deeply.get_all(data, lens)
  #   |> assert_good_enough(in_any_order([:b, :c]))

  #   %{a: result} = Deeply.put(data, lens, 393)
  #   assert BiMap.get(result, :a) == 1 # not set because it's not missing.
  #   # Remember that duplicate values are not allowed in BiMaps.
  #   assert BiMap.get(result, :b) == 393 || BiMap.get(result, :c) == 393

  #   %{a: result} = Deeply.update(data, lens, fn key -> {key, :erlang.make_ref} end)
  #   assert BiMap.get(result, :a) == 1
  #   {:b, b_ref} = BiMap.get(result, :b)
  #   assert is_reference(b_ref)

  #   assert {:c, c_ref} = BiMap.get(result, :c)
  #   assert is_reference(c_ref)

  #   refute b_ref == c_ref
  # end

  test "key" do
    bimap = BiMap.new(a: %{aa: 1}, b: %{aa: 2})
    map = %{          a: %{aa: 1}, b: %{aa: 2}}

    map_lens = Lens.key(:a) |> Lens.key(:aa)
    lens = Lens.BiMap.key(:a) |> Lens.key(:aa)

    BiMap.put(bimap, :a, %{aa: 100})

    assert Deeply.get_all(map, map_lens) == [1]
    assert Deeply.get_all(bimap, lens) == [1]

    assert Deeply.put(map, map_lens, 5) == %{a: %{aa: 5}, b: %{aa: 2}}
    assert Deeply.put(bimap, lens, 5) == BiMap.new(a: %{aa: 5}, b: %{aa: 2})

    assert Deeply.update(map, map_lens, & &1 * 100) == %{a: %{aa: 100}, b: %{aa: 2}}
    assert Deeply.update(bimap, lens, & &1 * 100) == BiMap.new(a: %{aa: 100}, b: %{aa: 2})
  end

  test "the difference between key and key?" do
    bimap = BiMap.new(a: 1, b: nil)
    missing_ok =      Lens.BiMap.keys ([:a, :b, :c])
    missing_omitted = Lens.BiMap.keys?([:a, :b, :c])

    Deeply.get_all(bimap, missing_ok)
    |> assert_good_enough(in_any_order([1, nil, nil]))

    Deeply.get_all(bimap, missing_omitted)
    |> assert_good_enough(in_any_order([1, nil]))

    # Usual issue with multi-put
    key = Deeply.put(bimap, missing_ok, 5) |> BiMap.get_key(5)
    assert key == :c # we happen to know keys are set left to right.

    # Usual issue with multi-put
    key = Deeply.put(bimap, missing_omitted, 5) |> BiMap.get_key(5)
    assert key == :b

    make_unique = fn value -> {value, :erlang.make_ref()} end

    actual = Deeply.update(bimap, missing_ok, make_unique)
    assert BiMap.size(actual) == 3
    assert {1, _ref} = BiMap.fetch!(actual, :a)
    assert {nil, _ref} = BiMap.fetch!(actual, :b)
    assert {nil, _ref} = BiMap.fetch!(actual, :c)

    actual = Deeply.update(bimap, missing_omitted, make_unique)
    assert BiMap.size(actual) == 2
    assert {1, _ref} = BiMap.fetch!(actual, :a)
    assert {nil, _ref} = BiMap.fetch!(actual, :b)
  end
end
