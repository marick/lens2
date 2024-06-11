defmodule Lens2.Compatibility.BasicTest do
  use Compatibility.Case

  # These are doctests scavenged from the original Lens

  test "root" do
    actual = Lens.to_list(Lens.root, :data)
    assert actual == [:data]

    actual = Lens.map(Lens.root, :data, fn :data -> :other_data end)
    assert actual == :other_data

    actual = Lens.key(:a) |> Lens.both(Lens.root, Lens.key(:b)) |> Lens.to_list(%{a: %{b: 1}})
    assert actual == [%{b: 1}, 1]
  end

  test "empty" do
    actual = Lens.empty |> Lens.to_list(:anything)
    assert actual == []
    actual = Lens.empty |> Lens.map(1, &(&1 + 1))
    assert actual == 1
  end

  test "const" do
    actual = Lens.const(3) |> Lens.one!(:anything)
    assert actual == 3

    actual = Lens.const(3) |> Lens.map(1, &(&1 + 1))
    assert actual == 4

    import Integer
    lens = Lens.keys([:a, :b]) |> Lens.match(fn v -> if is_odd(v), do: Lens.root, else: Lens.const(0) end)
    actual = Lens.map(lens, %{a: 11, b: 12}, &(&1 + 1))
    assert actual == %{a: 12, b: 1}
  end


  test "all" do
    actual = Lens.all |> Lens.to_list([1, 2, 3])
    assert actual == [1, 2, 3]

    actual = Lens.all |> Lens.map(MapSet.new([1, 2, 3]), &(&1 + 1))
    assert actual == [2, 3, 4]
  end

  test "into" do
    actual = Lens.into(Lens.all(), MapSet.new) |> Lens.map(MapSet.new([-2, -1, 1, 2]), &(&1 * &1))
    assert actual == MapSet.new([1, 4])

    actual =
      Lens.map_values() |> Lens.all() |> Lens.into(%{}) |>
      Lens.map(%{key1: %{key2: :value}}, fn {k, v} -> {v, k} end)
    assert actual == %{key1: [{:value, :key2}]}

    actual =
      Lens.map_values() |> Lens.into(Lens.all(), %{}) |>
      Lens.map(%{key1: %{key2: :value}}, fn {k, v} -> {v, k} end)
    assert actual == %{key1: %{value: :key2}}
  end

  test "filter" do
    actual = Lens.map_values() |> Lens.filter(&Integer.is_odd/1) |> Lens.to_list(%{a: 1, b: 2, c: 3, d: 4})
    assert_good_enough(actual, in_any_order([1, 3]))
  end

  test "reject" do
    actual = Lens.map_values() |> Lens.reject(&Integer.is_odd/1) |> Lens.to_list(%{a: 1, b: 2, c: 3, d: 4})
    assert_good_enough(actual, in_any_order([2, 4]))
  end

  test "match" do
    selector = fn
      {:a, _} -> Lens.at(1)
      {:b, _, _} -> Lens.at(2)
    end
    actual = Lens.match(selector) |> Lens.one!({:b, 2, 3})
    assert actual == 3
  end


  test "multiple" do
    actual = Lens.multiple([Lens.key(:a), Lens.key(:b), Lens.root]) |> Lens.to_list(%{a: 1, b: 2})
    assert actual == [1, 2, %{a: 1, b: 2}]
  end

  test "both" do
    assert_raise(FunctionClauseError, "no function clause matching in Access.fetch/2", fn ->
      Lens.both(Lens.root, Lens.key(:a)) |> Lens.get_and_map(%{a: 1}, fn x -> {x, :foo} end)
    end)
    actual = Lens.both(Lens.key(:a), Lens.root) |> Lens.get_and_map(%{a: 1}, fn x -> {x, :foo} end)
    assert actual == {[1, %{a: :foo}], :foo}
  end

  test "seq" do
    actual = Lens.seq(Lens.key(:a), Lens.key(:b)) |> Lens.one!(%{a: %{b: 3}})
    assert actual == 3

    actual = Lens.key(:a) |> Lens.key(:b) |> Lens.one!(%{a: %{b: 3}})
    assert actual == 3
  end

  test "seq_both" do
    actual = Lens.seq_both(Lens.key(:a), Lens.key(:b)) |> Lens.to_list(%{a: %{b: :c}})
    assert actual == [:c, %{b: :c}]
  end

  test "recur" do
    data = %{
      items: [
        %{id: 1, items: []},
        %{id: 2, items: [
            %{id: 3, items: []}
          ]}
      ]}
    lens = Lens.recur(Lens.key(:items) |> Lens.all) |> Lens.key(:id)
    actual = Lens.to_list(lens, data)
    assert actual == [1, 3, 2]

    data = %{
      id: 4,
      items: [
        %{id: 1, items: []},
        %{id: 2, items: [
            %{id: 3, items: []}
          ]}
      ]
    }
    lens = Lens.both(Lens.recur(Lens.key(:items) |> Lens.all), Lens.root) |> Lens.key(:id)
    actual = Lens.to_list(lens, data)
    assert actual == [1, 3, 2, 4]
  end

  test "recur_root" do
    data = {:x, [{:y, []}, {:z, [{:w, []}]}]}
    actual = Lens.recur_root(Lens.at(1) |> Lens.all()) |> Lens.at(0) |> Lens.to_list(data)
    assert actual == [:y, :w, :z, :x]
  end

  test "context" do
    lens = Lens.context(Lens.keys([:a, :c]), Lens.key(:b) |> Lens.all())
    actual = Lens.to_list(lens, %{a: %{b: [1, 2]}, c: %{b: [3]}})
    assert actual == [{%{b: [1, 2]}, 1}, {%{b: [1, 2]}, 2}, {%{b: [3]}, 3}]

    actual = Lens.map(lens, %{a: %{b: [1, 2]}, c: %{b: [3]}}, fn({%{b: bs}, value}) ->
      length(bs) + value
    end)
    assert actual == %{a: %{b: [3, 4]}, c: %{b: [4]}}
  end

  test "either" do
    actual = get_in(%{a: 1}, [Lens.either(Lens.key?(:a), Lens.key?(:b))])
    assert actual == [1]
    actual = get_in(%{b: 2}, [Lens.either(Lens.key?(:a), Lens.key?(:b))])
    assert actual == [2]

    actual = get_in([%{id: 8}], [Lens.all |> Lens.filter(&(&1.id == 8)) |> Lens.either(Lens.const(:default))])
    assert actual == [%{id: 8}]
    actual = get_in([%{id: 8}], [Lens.all |> Lens.filter(&(&1.id == 1)) |> Lens.either(Lens.const(:default))])
    assert actual == [:default]

    upsert = Lens.all() |> Lens.filter(&(&1[:id] == 1)) |> Lens.either(Lens.front())
    actual = update_in([%{id: 0}, %{id: 1}], [upsert], fn _ -> %{id: 1, x: :y} end)
    assert actual == [%{id: 0}, %{id: 1, x: :y}]
    actual = update_in([%{id: 0}, %{id: 2}], [upsert], fn _ -> %{id: 1, x: :y} end)
    assert actual == [%{id: 1, x: :y}, %{id: 0}, %{id: 2}]
  end

  test "key" do
    actual = Lens.to_list(Lens.key(:foo), %{foo: 1, bar: 2})
    assert actual == [1]
    actual = Lens.map(Lens.key(:foo), %{foo: 1, bar: 2}, fn x -> x + 10 end)
    assert actual == %{foo: 11, bar: 2}


    actual = Lens.to_list(Lens.key(:foo), %{})
    assert actual == [nil]
    actual = Lens.map(Lens.key(:foo), %{}, fn nil -> 3 end)
    assert actual == %{foo: 3}
  end

  test "key!" do
    actual = Lens.key!(:a) |> Lens.one!(%{a: 1, b: 2})
    assert actual == 1
    actual = Lens.key!(:a) |> Lens.one!([a: 1, b: 2])
    assert actual == 1

    assert_raise(KeyError, "key :c not found in: %{a: 1, b: 2}", fn ->
      Lens.key!(:c) |> Lens.one!(%{a: 1, b: 2})
    end)
  end

  test "key?" do
    actual = Lens.key?(:a) |> Lens.to_list(%{a: 1, b: 2})
    assert actual == [1]
    actual = Lens.key?(:a) |> Lens.to_list([a: 1, b: 2])
    assert actual == [1]
    actual = Lens.key?(:c) |> Lens.to_list(%{a: 1, b: 2})
    assert actual == []
  end

  test "keys" do
    actual = Lens.keys([:a, :c]) |> Lens.to_list(%{a: 1, b: 2, c: 3})
    assert actual == [1, 3]
    actual = Lens.keys([:a, :c]) |> Lens.map([a: 1, b: 2, c: 3], &(&1 + 1))
    assert actual == [a: 2, b: 2, c: 4]

    actual = Lens.keys([:a, :c]) |> Lens.map(%{a: 1, b: 2}, fn nil -> 3; x -> x end)
    assert actual == %{a: 1, b: 2, c: 3}
  end

  test "keys!" do
    actual = Lens.keys!([:a, :c]) |> Lens.to_list(%{a: 1, b: 2, c: 3})
    assert actual == [1, 3]
    actual = Lens.keys!([:a, :c]) |> Lens.map([a: 1, b: 2, c: 3], &(&1 + 1))
    assert actual == [a: 2, b: 2, c: 4]
    assert_raise(KeyError, "key :c not found in: %{a: 1, b: 2}", fn ->
      Lens.keys!([:a, :c]) |> Lens.to_list(%{a: 1, b: 2})
    end)
  end

  test "keys?" do
    actual = Lens.keys?([:a, :c]) |> Lens.to_list(%{a: 1, b: 2, c: 3})
    assert actual == [1, 3]
    actual = Lens.keys?([:a, :c]) |> Lens.map([a: 1, b: 2, c: 3], &(&1 + 1))
    assert actual == [a: 2, b: 2, c: 4]
    actual = Lens.keys?([:a, :c]) |> Lens.to_list(%{a: 1, b: 2})
    assert actual == [1]
  end

  test "map_values" do
    actual = Lens.map_values() |> Lens.to_list(%{a: 1, b: 2})
    assert actual == [1, 2]
    actual = Lens.map_values() |> Lens.map(%{a: 1, b: 2}, &(&1 + 1))
    assert actual == %{a: 2, b: 3}
  end

  test "map_keys" do
    actual = Lens.map_keys() |> Lens.to_list(%{a: 1, b: 2})
    assert actual == [:a, :b]
    actual = Lens.map_keys() |> Lens.map(%{1 => :a, 2 => :b}, &(&1 + 1))
    assert actual == %{2 => :a, 3 => :b}
  end


  test "front" do
    actual = Lens.front |> Lens.one!([:a, :b, :c])
    assert actual == nil
    actual = Lens.front |> Lens.map([:a, :b, :c], fn nil -> :d end)
    assert actual == [:d, :a, :b, :c]
  end

  test "back" do
    actual = Lens.back |> Lens.one!([:a, :b, :c])
    assert actual == nil
    actual = Lens.back |> Lens.map([:a, :b, :c], fn nil -> :d end)
    assert actual == [:a, :b, :c, :d]
  end

  test "before" do
    actual = Lens.before(2) |> Lens.one!([:a, :b, :c])
    assert actual == nil
    actual = Lens.before(2) |> Lens.map([:a, :b, :c], fn nil -> :d end)
    assert actual == [:a, :b, :d, :c]
  end

  test "behind" do
    actual = Lens.behind(1) |> Lens.one!([:a, :b, :c])
    assert actual == nil
    actual = Lens.behind(1) |> Lens.map([:a, :b, :c], fn nil -> :d end)
    assert actual == [:a, :b, :d, :c]
  end

  test "at" do
    actual = Lens.at(2) |> Lens.one!({:a, :b, :c})
    assert actual == :c
    actual = Lens.at(1) |> Lens.map([:a, :b, :c], fn :b -> :d end)
    assert actual == [:a, :d, :c]
  end

  test "index" do
    actual = Lens.at(2) |> Lens.one!({:a, :b, :c})
    assert actual == :c
    actual = Lens.at(1) |> Lens.map([:a, :b, :c], fn :b -> :d end)
    assert actual == [:a, :d, :c]
  end

  test "indices" do
    actual = Lens.indices([0, 2]) |> Lens.to_list([:a, :b, :c])
    assert actual == [:a, :c]
    actual = Lens.indices([0, 2]) |> Lens.map([1, 2, 3], &(&1 + 1))
    assert actual == [2, 2, 4]
  end



end
