defmodule Lens2.Lenses.BiMultiMapTest do
  use Lens2.Case, async: true
  alias Lens.BiMap, as: Bi


  describe "support for multimap handling" do
    test "multi_fetch" do
      container =
        BiMultiMap.new(one: 1, two: 2, one: "one")

      {:ok, fetched} = Bi.multi_fetch(container, :one, :descend_value)
      assert Enum.sort(fetched) == [1, "one"]

      {:ok, fetched} = Bi.multi_fetch(container, 1, :descend_key)
      assert Enum.sort(fetched) == [:one]

      assert :error == Bi.multi_fetch(container, :missing, :descend_key)
    end

    test "multi_adjust_fetched" do
      assert Bi.multi_adjust_fetched({:ok, [1]}, :raise_on_missing) == [1]
      assert Bi.multi_adjust_fetched({:ok, [1]}, :nil_on_missing) == [1]
      assert Bi.multi_adjust_fetched({:ok, [1]}, :ignore_missing) == [1]


      assert_raise(KeyError, "no match (improve this message)", fn ->
        Bi.multi_adjust_fetched(:error, :raise_on_missing) == [1]
      end)

      assert Bi.multi_adjust_fetched(:error, :nil_on_missing) == [nil]
      assert Bi.multi_adjust_fetched(:error, :ignore_missing) == []
    end

    test "multi_descend" do
      descender = & {[&1, &1+1], {&1, &1*1000}}

      {gotten, to_delete, to_put} =
        Bi.multi_descend(descender, "one", [1, 1.1], :descend_value)
      assert Enum.sort(gotten) == [ [1, 2], [1.1, 2.1]]
      assert Enum.sort(to_delete) == [{"one", 1}, {"one", 1.1}]
      assert Enum.sort(to_put) == [{"one", {1, 1000}}, {"one", {1.1, 1100.0}}]
    end


    test "multimap" do
      container = BiMultiMap.new(a: 1, a: 2, b: 1, b: 2)
      {gotten, updated} =
        Bi.worker(:a, container, & {&1, &1*22}, :ignore_missing, :descend_value)

      assert Enum.sort(gotten) == [1, 2]
      assert updated == BiMultiMap.new(a: 22, a: 44, b: 1, b: 2)

      # reverse direction
      {gotten, updated} =
        Bi.worker(2, container, & {&1, inspect(&1)}, :ignore_missing, :descend_key)

      assert Enum.sort(gotten) == [:a, :b]
      expected = BiMultiMap.new(a: 1, b: 1) |> BiMultiMap.put(":a", 2) |> BiMultiMap.put(":b", 2)
      assert updated == expected
    end
  end


  describe "key?" do
    test "no such key" do
      container = BiMultiMap.new(%{1 => %{a: 1, b: 2}, 2 => %{a: 11, b: 22}})
      lens = Bi.key?(:a)
      assert Deeply.get_all(container, lens) == []
    end

    test "one level" do
      container =
        BiMultiMap.new(one: %{a: 1, b: 2},
                       two: %{a: 11, b: 22},
                       one: %{a: 111, b: 222})
      lens = Bi.key?(:one)
      {gotten, updated} = Deeply.get_and_update(container, lens,
                                                & {&1, Map.put(&1, :c, &1[:a] + &1[:b])})

      assert Enum.sort(gotten) == [%{a: 1, b: 2}, %{a: 111, b: 222}]
      assert updated == BiMultiMap.new(one: %{a: 1, b: 2, c: 3},
                                       two: %{a: 11, b: 22},
                                       one: %{a: 111, b: 222, c: 333})

      # two levels
      lens = Bi.key?(:one) |> Lens.key!(:a)
      {gotten, updated} = Deeply.get_and_update(container, lens, & {&1, &1+1})
      assert Enum.sort(gotten) == [1, 111]
      assert updated == BiMultiMap.new(one: %{a: 2, b: 2},
                                       two: %{a: 11, b: 22},
                                       one: %{a: 112, b: 222})
    end

    test "as wrapped in `keys?`" do
      container =
        BiMultiMap.new(one: %{a: 1, b: 2},
                       two: %{a: 11, b: 22},
                       one: %{a: 111, b: 222})
      lens = Bi.keys?([:one, :two, :missing]) |> Lens.key!(:a)
      assert Deeply.get_all(container, lens) |> Enum.sort == [1, 11, 111]

      actual = Deeply.put(container, lens, :NEW)
      expected =
        BiMultiMap.new(one: %{a: :NEW, b: 2},
                       two: %{a: :NEW, b: 22},
                       one: %{a: :NEW, b: 222})

      assert actual == expected
    end
  end

  describe "to_key?" do
    test "no such value" do
      container = BiMultiMap.new(%{1 => %{a: 1, b: 2}, 2 => %{a: 11, b: 22}})
      lens = Bi.to_key?(:missing)
      assert Deeply.get_all(container, lens) == []
    end

    test "one level" do
      container =
        BiMultiMap.new
        |> BiMultiMap.put({1, "one"})
        |> BiMultiMap.put({2, "two"})
        |> BiMultiMap.put({1.0, "one"})

      lens = Bi.to_key?("one")
      {gotten, updated} = Deeply.get_and_update(container, lens, & {&1, &1*2})

      assert Enum.sort(gotten) == [1, 1.0]
      assert updated == (BiMultiMap.new
      |> BiMultiMap.put({2, "one"})
      |> BiMultiMap.put({2, "two"})
      |> BiMultiMap.put({2.0, "one"}))
    end

    test "two levels" do
      container =
        BiMultiMap.new
        |> BiMultiMap.put({%{a: 3, b: 2}, 1})
        |> BiMultiMap.put({%{a: 33, b: 22}, 2})
        |> BiMultiMap.put({%{a: 333, b: 222}, 1})
      lens = Bi.to_key?(1) |> Lens.key!(:a)
      {gotten, updated} = Deeply.get_and_update(container, lens, & {&1, inspect(&1)})
      assert Enum.sort(gotten) == [3, 333]
      assert updated == (BiMultiMap.new
      |> BiMultiMap.put({%{a: "3", b: 2}, 1})
      |> BiMultiMap.put({%{a: 33, b: 22}, 2})
      |> BiMultiMap.put({%{a: "333", b: 222}, 1}))
    end
  end

  @tag :skip
  test "key and keys" do
    container =
      BiMultiMap.new(one: %{a: 1, b: 2},
                     two: %{a: 11, b: 22},
                     one: %{a: 111, b: 222})
    assert Deeply.get_all(container, Bi.key(:one)) == %{a: 1, b: 2}


    # lens = Bi.keys([:one, :two, :missing]) |> Lens.key!(:a)
    # assert Deeply.get_all(container, lens) |> Enum.sort == [1, 11, 111]

    # actual = Deeply.put(container, lens, :NEW)
    # expected =
    #   BiMultiMap.new(one: %{a: :NEW, b: 2},
    #                  two: %{a: :NEW, b: 22},
    #                  one: %{a: :NEW, b: 222})

    # assert actual == expected
  end


  describe "copied from BiMap tests, and occasionally modified" do

    test "all_values" do
      input = BiMultiMap.new(%{1 => %{a: 1, b: 2}, 2 => %{a: 11, b: 22}})

      lens = Bi.all_values |> Lens.key(:a)

      assert Deeply.get_all(input, lens) == [1, 11]

      actual = Deeply.put(input, lens, :xyzzy)
      assert actual == BiMultiMap.new(%{1 => %{a: :xyzzy, b: 2}, 2 => %{a: :xyzzy, b: 22}})

      actual = Deeply.update(input, lens, & &1 * 1000)
      assert actual == BiMultiMap.new(%{1 => %{a: 1000, b: 2}, 2 => %{a: 11_000, b: 22}})

      # Unlike BiMap, BiMultiMap allows duplicate values.
      Deeply.put(BiMultiMap.new(a: 1, b: 2), Bi.all_values, 5)
      |> assert_equal(BiMultiMap.new(a: 5, b: 5))

    end

    @tag :skip
    test "keys/1" do
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


      lens = Bi.keys([:a, :missing]) # |> Lens.filter(& &1 == nil)
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
      lens = Bi.key(:a) |> Lens.key(:aa)

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
      missing_ok =      Bi.keys ([:a, :b, :c])
      missing_omitted = Bi.keys?([:a, :b, :c])

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
end
