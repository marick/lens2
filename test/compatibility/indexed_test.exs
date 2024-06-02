defmodule Lens2.Compatibility.IndexedTest do
  use ExUnit.Case
  require Integer
  use Lens2.Compatible


  # These are doctests scavenged from the original Lens

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
