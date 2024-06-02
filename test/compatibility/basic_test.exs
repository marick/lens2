defmodule Lens2.Compatibility.BasicTest do
  use ExUnit.Case
  require Integer
  use Lens2.Compatible
  use FlowAssertions


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
end
