defmodule Lens2.Lenses.BiMultiMapTest do
  use Lens2.Case, async: true


  describe "key?" do
    test "no such key" do
      container = BiMultiMap.new(%{1 => %{a: 1, b: 2}, 2 => %{a: 11, b: 22}})
      lens = Lens.BiMap.key?(:a)
      assert Deeply.get_all(container, lens) == []
    end

    test "key? - one level" do
      container =
        BiMultiMap.new(one: %{a: 1, b: 2},
                       two: %{a: 11, b: 22},
                       one: %{a: 111, b: 222})
      lens = Lens.BiMap.key?(:one)
      {gotten, updated} = Deeply.get_and_update(container, lens,
                                                & {&1, Map.put(&1, :c, &1[:a] + &1[:b])})

      assert Enum.sort(gotten) == [%{a: 1, b: 2}, %{a: 111, b: 222}]
      assert updated == BiMultiMap.new(one: %{a: 1, b: 2, c: 3},
                                       two: %{a: 11, b: 22},
                                       one: %{a: 111, b: 222, c: 333})

      # two levels
      lens = Lens.BiMap.key?(:one) |> Lens.key!(:a)
      {gotten, updated} = Deeply.get_and_update(container, lens, & {&1, &1+1})
      assert Enum.sort(gotten) == [1, 111]
      assert updated == BiMultiMap.new(one: %{a: 2, b: 2},
                                       two: %{a: 11, b: 22},
                                       one: %{a: 112, b: 222})
    end
  end

  describe "to_key?" do
    test "no such value" do
      container = BiMultiMap.new(%{1 => %{a: 1, b: 2}, 2 => %{a: 11, b: 22}})
      lens = Lens.BiMap.to_key?(:missing)
      assert Deeply.get_all(container, lens) == []
    end

    test "to_key? - one level" do
      container =
        BiMultiMap.new
        |> BiMultiMap.put({1, "one"})
        |> BiMultiMap.put({2, "two"})
        |> BiMultiMap.put({1.0, "one"})

      lens = Lens.BiMap.to_key?("one")
      {gotten, updated} = Deeply.get_and_update(container, lens, & {&1, &1*2})

      assert Enum.sort(gotten) == [1, 1.0]
      assert updated == (BiMultiMap.new
      |> BiMultiMap.put({2, "one"})
      |> BiMultiMap.put({2, "two"})
      |> BiMultiMap.put({2.0, "one"}))
    end

    test "to_key? - two levels" do
      container =
        BiMultiMap.new
        |> BiMultiMap.put({%{a: 3, b: 2}, 1})
        |> BiMultiMap.put({%{a: 33, b: 22}, 2})
        |> BiMultiMap.put({%{a: 333, b: 222}, 1})
      lens = Lens.BiMap.to_key?(1) |> Lens.key!(:a)
      {gotten, updated} = Deeply.get_and_update(container, lens, & {&1, inspect(&1)})
      assert Enum.sort(gotten) == [3, 333]
      assert updated == (BiMultiMap.new
      |> BiMultiMap.put({%{a: "3", b: 2}, 1})
      |> BiMultiMap.put({%{a: 33, b: 22}, 2})
      |> BiMultiMap.put({%{a: "333", b: 222}, 1}))
    end
  end



  @tag :skip
  test "all_values" do
    input = BiMultiMap.new(%{1 => %{a: 1, b: 2}, 2 => %{a: 11, b: 22}})

    lens = Lens.BiMap.all_values |> Lens.key(:a)

    assert Deeply.get_all(input, lens) == [1, 11]

    actual = Deeply.put(input, lens, :xyzzy)
    assert actual == BiMultiMap.new(%{1 => %{a: :xyzzy, b: 2}, 2 => %{a: :xyzzy, b: 22}})

    # Note that `put` is bad when a BiMultiMap is on the end because they can't have
    # duplicate values, so BiMultiMap.new(a: 5, b: 5) is collapsed into a single value.

    assert Deeply.put(BiMultiMap.new(a: 1, b: 2), Lens.BiMap.all_values, 5) |> BiMultiMap.size == 1

    actual = Deeply.update(input, lens, & &1 * 1000)
    assert actual == BiMultiMap.new(%{1 => %{a: 1000, b: 2}, 2 => %{a: 11_000, b: 22}})
  end

  @tag :skip
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
    bimap = BiMultiMap.new(map)

    assert Deeply.get_all(bimap, lens) == [nil]
    assert Deeply.put(bimap, lens, :xyzzy) == BiMultiMap.new(a: 323, b: 111, missing: :xyzzy)
    %BiMultiMap{} = result = Deeply.update(bimap, lens, fn nil -> :erlang.make_ref end)

    assert BiMultiMap.get(result, :a) == 323
    assert BiMultiMap.get(result, :b) == 111
    assert BiMultiMap.get(result, :missing) |> is_reference
  end

  @tag :skip
  test "key" do
    bimap = BiMultiMap.new(a: %{aa: 1}, b: %{aa: 2})
    map = %{          a: %{aa: 1}, b: %{aa: 2}}

    map_lens = Lens.key(:a) |> Lens.key(:aa)
    lens = Lens.BiMap.key(:a) |> Lens.key(:aa)

    BiMultiMap.put(bimap, :a, %{aa: 100})

    assert Deeply.get_all(map, map_lens) == [1]
    assert Deeply.get_all(bimap, lens) == [1]

    assert Deeply.put(map, map_lens, 5) == %{a: %{aa: 5}, b: %{aa: 2}}
    assert Deeply.put(bimap, lens, 5) == BiMultiMap.new(a: %{aa: 5}, b: %{aa: 2})

    assert Deeply.update(map, map_lens, & &1 * 100) == %{a: %{aa: 100}, b: %{aa: 2}}
    assert Deeply.update(bimap, lens, & &1 * 100) == BiMultiMap.new(a: %{aa: 100}, b: %{aa: 2})
  end

  @tag :skip
  test "the difference between key and key?" do
    bimap = BiMultiMap.new(a: 1, b: nil)
    missing_ok =      Lens.BiMap.keys ([:a, :b, :c])
    missing_omitted = Lens.BiMap.keys?([:a, :b, :c])

    Deeply.get_all(bimap, missing_ok)
    |> assert_good_enough(in_any_order([1, nil, nil]))

    Deeply.get_all(bimap, missing_omitted)
    |> assert_good_enough(in_any_order([1, nil]))

    # Usual issue with multi-put
    key = Deeply.put(bimap, missing_ok, 5) |> BiMultiMap.get_keys(5)
    assert key == :c # we happen to know keys are set left to right.

    # Usual issue with multi-put
    key = Deeply.put(bimap, missing_omitted, 5) |> BiMultiMap.get_keys(5)
    assert key == :b

    make_unique = fn value -> {value, :erlang.make_ref()} end

    actual = Deeply.update(bimap, missing_ok, make_unique)
    assert BiMultiMap.size(actual) == 3
    assert {1, _ref} = BiMultiMap.fetch!(actual, :a)
    assert {nil, _ref} = BiMultiMap.fetch!(actual, :b)
    assert {nil, _ref} = BiMultiMap.fetch!(actual, :c)

    actual = Deeply.update(bimap, missing_omitted, make_unique)
    assert BiMultiMap.size(actual) == 2
    assert {1, _ref} = BiMultiMap.fetch!(actual, :a)
    assert {nil, _ref} = BiMultiMap.fetch!(actual, :b)
  end
end
