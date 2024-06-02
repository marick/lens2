defmodule Lens2.Compatibility.MaplikeTest do
  use ExUnit.Case
  require Integer
  use Lens2.Compatible


  # These are doctests scavenged from the original Lens

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
end
