defmodule Lens2.Lenses.BiMapTest do
  use Lens2.Case, async: true

  doctest Lens2.Lenses.Bi

  alias Lens.Bi

  describe "support for bimap handling" do
    test "bimap_fetch" do
      container =
        BiMap.new(one: 1, two: 2)

      {:ok, fetched} = Bi.bimap_fetch(container, :one, :descend_value)
      assert fetched == 1

      {:ok, fetched} = Bi.bimap_fetch(container, 1, :descend_key)
      assert fetched == :one

      assert :error == Bi.bimap_fetch(container, :missing, :descend_key)
    end

    test "worker - element is found" do
      container = BiMap.new(a: 1, b: 2)
      {gotten, updated} =
        Bi.worker(:a, container, & {&1, &1*22}, :IRRELEVANT, :descend_value)

      assert gotten == [1]
      assert updated == BiMap.new(a: 22, b: 2)

      # reverse direction
      {gotten, updated} =
        Bi.worker(2, container, & {&1, inspect(&1)}, :IRRELEVANT, :descend_key)

      assert gotten == [:b]
      assert updated == BiMap.new(%{:a => 1, ":b" => 2})
    end

    test "worker - :ignore missing parameter" do
      container = BiMap.new(a: 1, b: 2)
      {gotten, updated} =
        Bi.worker(:missing, container, & {&1, inspect(&1)}, :ignore_missing, :descend_value)

      assert gotten == []
      assert updated == container
    end

    test "worker - :raise_on_missing" do
      container = BiMap.new(a: 1)
      assert_raise(ArgumentError, "value `:missing` not found in: BiMap.new([a: 1])", fn ->
        Bi.worker(:missing, container, & {&1, inspect(&1)}, :raise_on_missing, :descend_key)
      end)
    end

    test "worker - :nil_on_missing" do
      container = BiMap.new(a: 1, b: 2)
      {gotten, updated} =
        Bi.worker(:missing, container, & {&1, inspect(&1)}, :nil_on_missing, :descend_value)

      assert gotten == [nil]
      assert updated == BiMap.new(a: 1, b: 2, missing: "nil")
    end

  end



  test "all_values" do
    input = BiMap.new(%{1 => %{a: 1, b: 2}, 2 => %{a: 11, b: 22}})

    lens = Bi.all_values |> Lens.key(:a)

    assert Deeply.get_all(input, lens) == [1, 11]

    actual = Deeply.put(input, lens, :xyzzy)
    assert actual == BiMap.new(%{1 => %{a: :xyzzy, b: 2}, 2 => %{a: :xyzzy, b: 22}})

    # Note that `put` is bad when a BiMap is on the end because they can't have
    # duplicate values, so BiMap.new(a: 5, b: 5) is collapsed into a single value.

    assert Deeply.put(BiMap.new(a: 1, b: 2), Bi.all_values, 5) |> BiMap.size == 1

    actual = Deeply.update(input, lens, & &1 * 1000)
    assert actual == BiMap.new(%{1 => %{a: 1000, b: 2}, 2 => %{a: 11_000, b: 22}})
  end

  test "from_keys/1" do
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


    lens = Bi.from_keys([:a, :missing]) |> Lens.filter(& &1 == nil)
    bimap = BiMap.new(map)

    assert Deeply.get_all(bimap, lens) == [nil]
    assert Deeply.put(bimap, lens, :xyzzy) == BiMap.new(a: 323, b: 111, missing: :xyzzy)
    %BiMap{} = result = Deeply.update(bimap, lens, fn nil -> :erlang.make_ref end)

    assert BiMap.get(result, :a) == 323
    assert BiMap.get(result, :b) == 111
    assert BiMap.get(result, :missing) |> is_reference
  end

  test "from_key" do
    bimap = BiMap.new(a: %{aa: 1}, b: %{aa: 2})
    map = %{          a: %{aa: 1}, b: %{aa: 2}}

    map_lens = Lens.key(:a) |> Lens.key(:aa)
    lens = Bi.from_key(:a) |> Lens.key(:aa)

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
    missing_ok =      Bi.from_keys ([:a, :b, :c])
    missing_omitted = Bi.from_keys?([:a, :b, :c])

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
