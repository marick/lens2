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
      field :x, integer, default: 0
      field :y, integer, default: 0
    end

    def_composed_maker x, do: Lens.key(:x)
    def_composed_maker y, do: Lens.key(:y)
  end

  IO.puts "you broke Deeply.get_all(..., :atom)"
  @tag :skip
  test "actions on atoms" do
    assert Deeply.get_all(%Point{}, :x) == [0]
  end
end
