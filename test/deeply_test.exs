defmodule Lens2.DeeplyTest do
  use Lens2.Case
  use TypedStruct

  doctest Deeply

  test "get_all" do
    %{a: 1, b: 2, c: 3}
    |> Deeply.get_all(Lens.map_values)
    |> assert_good_enough(in_any_order([1, 2, 3]))
  end

  test "get_only" do
    assert_raise(MatchError, fn ->
      %{a: 1, b: 2, c: 3}
      |> Deeply.get_only(Lens.map_values)
    end)

    assert_raise(MatchError, fn ->
      %{a: 1, b: 2, c: 3}
      |> Deeply.get_only(Lens.key?(:missing))
    end)
  end

  test "put" do
    lens = Lens.key(:a)
    keylist = [a: 1, other: 2, a: 3]

    # Surprising, yes, but consistent with `Access`.
    assert Deeply.put(keylist, lens, :NEW) == [a: :NEW, other: 2, a: 3]
  end

  test "get_and_update" do
    returner = fn value -> {value, inspect(value)} end
    assert Deeply.get_and_update(%{a: 1}, Lens.key(:a), returner) == { [1], %{a: "1"} }
  end


  defmodule Point do
    typedstruct do
      field :x, integer
      field :y, integer
    end

    defmaker x, do: Lens.key(:x)
    defmaker y, do: Lens.key(:y)
  end

  test "actions on atoms" do
    p = %Point{x: 0, y: 1}
    assert Deeply.each(p, :x, fn _ -> :for_side_effect end) == :ok
    assert Deeply.get_all(p, :x) == [0]
    assert Deeply.get_and_update(p, :x, & {&1, inspect(&1)}) == {[0], %Point{x: "0", y: 1}}
    assert Deeply.get_only(p, :x) == 0
    assert Deeply.one!(p, :x) == 0
    assert Deeply.put(p, :x, :NEW) == %Point{x: :NEW, y: 1}
    assert Deeply.to_list(p, :x) == [0]
    assert Deeply.update(p, :x, & &1+1) == %Point{x: 1, y: 1}
  end
end
