defmodule Lens2.Compatibility.CombineTest do
  use ExUnit.Case
  require Integer
  use Lens2.Compatible


  # These are doctests scavenged from the original Lens

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
end
