defmodule Lens2.Lenses.KeyedTest do
  use Lens2.Case, async: true

  defmodule SomeStruct do
    defstruct [:a, :b]
  end

  doctest Lens2.Lenses.Keyed

  describe "use with structures" do
    test "key" do
      lens = Lens.key(:a)

      assert [1] == %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)
      actual = %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      assert %SomeStruct{a: 1000, b: 2} == actual

      lens = Lens.key(:missing)

      assert [nil] == %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)

      actual = %SomeStruct{a: 1, b: 2} |> Deeply.put(lens, :NEW)
      expected = %{missing: :NEW, a: 1, __struct__: Lens2.Lenses.KeyedTest.SomeStruct, b: 2}
      assert actual == expected # ick
    end

    test "key!" do
      lens = Lens.key!(:a)

      assert [1] == %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)
      actual = %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      assert %SomeStruct{a: 1000, b: 2} == actual

      lens = Lens.key!(:missing)

      assert_raise(KeyError, ~r/key :missing.*SomeStruct/, fn ->
        %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)
      end)

      assert_raise(KeyError, ~r/key :missing.*SomeStruct/, fn ->
        %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      end)
    end

    test "key?" do
      lens = Lens.key?(:a)

      assert [1] == %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)
      actual = %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      assert %SomeStruct{a: 1000, b: 2} == actual

      lens = Lens.key?(:missing)

      assert [] == %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)

      actual = %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      assert %SomeStruct{a: 1, b: 2} == actual
    end


    # Multiples

    test "keys" do
      lens = Lens.keys([:a])

      assert [1] == %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)
      actual = %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      assert %SomeStruct{a: 1000, b: 2} == actual

      lens = Lens.keys([:missing])

      assert [nil] == %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)

      actual = %SomeStruct{a: 1, b: 2} |> Deeply.put(lens, :NEW)
      expected = %{missing: :NEW, a: 1, __struct__: Lens2.Lenses.KeyedTest.SomeStruct, b: 2}
      assert actual == expected # ick
    end

    test "keys!" do
      lens = Lens.keys!([:a])

      assert [1] == %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)
      actual = %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      assert %SomeStruct{a: 1000, b: 2} == actual

      lens = Lens.keys!([:missing])

      assert_raise(KeyError, ~r/key :missing.*SomeStruct/, fn ->
        %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)
      end)

      assert_raise(KeyError, ~r/key :missing.*SomeStruct/, fn ->
        %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      end)
    end

    test "keys?" do
      lens = Lens.keys?([:a])

      assert [1] == %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)
      actual = %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      assert %SomeStruct{a: 1000, b: 2} == actual

      lens = Lens.keys?([:missing])

      assert [] == %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens)

      actual = %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      assert %SomeStruct{a: 1, b: 2} == actual
    end

    test "map_values" do
      lens = Lens.map_values
      actual = %SomeStruct{a: 1, b: 2} |> Deeply.get_all(lens) |> Enum.sort
      assert [1, 2] == actual


      actual = %SomeStruct{a: 1, b: 2} |> Deeply.update(lens, & &1*1000)
      assert %SomeStruct{a: 1000, b: 2000} == actual
    end

    test "an excess of caution about nesting of map_values" do
      container = %{outer: %SomeStruct{a: ["zero", "one"], b: ["a", "b", "c"]}}

      lens = Lens.key(:outer) |> Lens.map_values |> Lens.at(1)

      actual = Deeply.get_all(container, lens) |> Enum.sort
      assert actual == ["b", "one"]

      actual = Deeply.update(container, lens, & &1 <> &1)
      assert actual == %{outer: %SomeStruct{a: ["zero", "oneone"], b: ["a", "bb", "c"]}}
    end
  end


  test "useful error message" do
    assert_raise(RuntimeError, "keys/1 takes a list as its argument.", fn ->
      Lens.keys(:a, :b)
    end)

    assert_raise(RuntimeError, "keys?/1 takes a list as its argument.", fn ->
      Lens.keys?(:a, :b)
    end)

    assert_raise(RuntimeError, "keys!/1 takes a list as its argument.", fn ->
      Lens.keys!(:a, :b)
    end)
  end
end
