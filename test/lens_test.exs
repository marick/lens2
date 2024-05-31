defmodule Lens2Test do
  use ExUnit.Case
  require Integer
  import Lens2.Macros
  doctest Lens2

  defmodule TestStruct do
    defstruct [:a, :b, :c]
  end

  describe "key" do
    test "to_list", do: assert(Lens2.to_list(Lens2.key(:a), %{a: :b}) == [:b])

    test "to_list on keyword", do: assert(Lens2.to_list(Lens2.key(:a), a: :b) == [:b])

    test "each" do
      this = self()
      Lens2.each(Lens2.key(:a), %{a: :b}, fn x -> send(this, x) end)
      assert_receive :b
    end

    test "map", do: assert(Lens2.map(Lens2.key(:a), %{a: :b}, fn :b -> :c end) == %{a: :c})
    test "map on keyword", do: assert(Lens2.map(Lens2.key(:a), [a: :b], fn :b -> :c end) == [a: :c])

    test "get_and_map" do
      assert Lens2.get_and_map(Lens2.key(:a), %{a: :b}, fn :b -> {:c, :d} end) == {[:c], %{a: :d}}
      assert Lens2.get_and_map(Lens2.key(:a), %TestStruct{a: 1}, fn x -> {x, x + 1} end) == {[1], %TestStruct{a: 2}}
    end
  end

  describe "keys" do
    test "get_and_map" do
      assert Lens2.get_and_map(Lens2.keys([:a, :e]), %{a: :b, c: :d, e: :f}, fn x -> {x, :x} end) ==
               {[:b, :f], %{a: :x, c: :d, e: :x}}

      assert Lens2.get_and_map(Lens2.keys([:a, :c]), %TestStruct{a: 1, b: 2, c: 3}, fn x -> {x, x + 1} end) ==
               {[1, 3], %TestStruct{a: 2, b: 2, c: 4}}
    end
  end

  describe "all" do
    test "to_list", do: assert(Lens2.to_list(Lens2.all(), [:a, :b, :c]) == [:a, :b, :c])

    test "each" do
      this = self()
      Lens2.each(Lens2.all(), [:a, :b, :c], fn x -> send(this, x) end)
      assert_receive :a
      assert_receive :b
      assert_receive :c
    end

    test "map",
      do:
        assert(
          Lens2.map(Lens2.all(), [:a, :b, :c], fn
            :a -> 1
            :b -> 2
            :c -> 3
          end) == [1, 2, 3]
        )

    test "get_and_map" do
      assert Lens2.get_and_map(Lens2.all(), [:a, :b, :c], fn x -> {x, :d} end) == {[:a, :b, :c], [:d, :d, :d]}
    end
  end

  describe "seq" do
    test "to_list", do: assert(Lens2.to_list(Lens2.seq(Lens2.key(:a), Lens2.key(:b)), %{a: %{b: :c}}) == [:c])

    test "each" do
      this = self()
      Lens2.each(Lens2.seq(Lens2.key(:a), Lens2.key(:b)), %{a: %{b: :c}}, fn x -> send(this, x) end)
      assert_receive :c
    end

    test "map",
      do: assert(Lens2.map(Lens2.seq(Lens2.key(:a), Lens2.key(:b)), %{a: %{b: :c}}, fn :c -> :d end) == %{a: %{b: :d}})

    test "get_and_map" do
      assert Lens2.get_and_map(Lens2.seq(Lens2.key(:a), Lens2.key(:b)), %{a: %{b: :c}}, fn :c -> {:d, :e} end) ==
               {[:d], %{a: %{b: :e}}}
    end
  end

  describe "seq_both" do
    test "get_and_map" do
      assert Lens2.get_and_map(Lens2.seq_both(Lens2.key(:a), Lens2.key(:b)), %{a: %{b: :c}}, fn
               :c -> {2, :d}
               %{b: :d} -> {1, %{b: :e}}
             end) == {[2, 1], %{a: %{b: :e}}}
    end
  end

  describe "both" do
    test "get_and_map" do
      assert Lens2.get_and_map(Lens2.both(Lens2.key(:a), Lens2.seq(Lens2.key(:b), Lens2.all())), %{a: 1, b: [2, 3]}, fn x ->
               {x, x + 1}
             end) == {[1, 2, 3], %{a: 2, b: [3, 4]}}
    end
  end

  describe "filter" do
    test "get_and_map" do
      lens =
        Lens2.both(Lens2.keys([:a, :b]), Lens2.seq(Lens2.key(:c), Lens2.all()))
        |> Lens2.filter(&Integer.is_odd/1)

      assert Lens2.get_and_map(lens, %{a: 1, b: 2, c: [3, 4]}, fn x -> {x, x + 1} end) ==
               {[1, 3], %{a: 2, b: 2, c: [4, 4]}}
    end

    test "usage with deflens" do
      assert Lens2.get_and_map(Lens2.all() |> test_filter(), [1, 2, 3, 4], fn x -> {x, x + 1} end) ==
               {[1, 3], [2, 2, 4, 4]}
    end

    deflensp test_filter() do
      Lens2.filter(&Integer.is_odd/1)
    end
  end

  describe "recur" do
    test "get_and_map" do
      data = %{
        data: 1,
        items: [
          %{data: 2, items: []},
          %{
            data: 3,
            items: [
              %{data: 4, items: []}
            ]
          }
        ]
      }

      lens = Lens2.recur(Lens2.key(:items) |> Lens2.all()) |> Lens2.key(:data)

      assert Lens2.get_and_map(lens, data, fn x -> {x, x + 1} end) ==
               {[2, 4, 3],
                %{
                  data: 1,
                  items: [
                    %{data: 3, items: []},
                    %{
                      data: 4,
                      items: [
                        %{data: 5, items: []}
                      ]
                    }
                  ]
                }}
    end
  end

  describe "at" do
    test "access on tuple" do
      assert Lens2.get_and_map(Lens2.at(1), {1, 2, 3}, fn x -> {x, x + 1} end) == {[2], {1, 3, 3}}
    end

    test "access on list" do
      assert Lens2.get_and_map(Lens2.at(1), [1, 2, 3], fn x -> {x, x + 1} end) == {[2], [1, 3, 3]}
    end
  end

  describe "match" do
    test "get_and_map" do
      lens =
        Lens2.seq(
          Lens2.all(),
          Lens2.match(fn
            {:a, _} -> Lens2.at(1)
            {:b, _, _} -> Lens2.at(2)
          end)
        )

      assert Lens2.get_and_map(lens, [{:a, 1}, {:b, 2, 3}], fn x -> {x, x + 1} end) == {[1, 3], [{:a, 2}, {:b, 2, 4}]}
    end
  end

  describe "empty" do
    test "get_and_map" do
      assert Lens2.get_and_map(Lens2.empty(), {:arbitrary, :data}, fn -> raise "never_called" end) ==
               {[], {:arbitrary, :data}}
    end
  end

  describe "composition with |>" do
    test "get_and_map" do
      lens1 = Lens2.key(:a) |> Lens2.seq(Lens2.all()) |> Lens2.seq(Lens2.key(:b))
      lens2 = Lens2.key(:a) |> Lens2.all() |> Lens2.key(:b)
      data = %{a: [%{b: 1}, %{b: 2}]}
      fun = fn x -> {x, x + 1} end

      assert Lens2.get_and_map(lens1, data, fun) == Lens2.get_and_map(lens2, data, fun)
    end
  end

  describe "root" do
    test "get_and_map" do
      assert Lens2.get_and_map(Lens2.root(), 1, fn x -> {x, x + 1} end) == {[1], 2}
    end
  end

  describe "lens as access key" do
    test "Kernel.get_in" do
      value =
        %{a: 1, b: 2, c: 3}
        |> get_in([Lens2.keys([:a, :c])])
        |> Enum.map(&to_string/1)

      assert value == ["1", "3"]
    end

    test "Kernel.update_in" do
      value =
        %{a: 1, b: 2, c: 3}
        |> update_in([Lens2.keys([:a, :c])], fn x -> x * 4 end)

      assert value == %{a: 4, b: 2, c: 12}
    end
  end
end
