defmodule Lens2.Lenses.MapSetTest do
  use Lens2.Case, async: true
  import Integer, only: [is_even: 1]
  use TypedStruct

  doctest Lens2.Lenses.MapSet

  typedstruct module: Point do
    field :x, integer
    field :y, integer
  end


  describe "has!" do
    test "struct" do
      container = MapSet.new([ %Point{x: 1, y: 2}, %Point{x: 2, y: 3} ])
      lens = Lens.MapSet.has!(y: 2) |> Lens.key(:x)
      actual = Deeply.put(container, lens, :NEW)
      expected = MapSet.new([ %Point{x: :NEW, y: 2}, %Point{x: 2, y: 3} ])
      assert actual == expected
    end

    test "missing key: non-struct" do
      container = MapSet.new([ [name: "a", val: 1], [name: "b"], [name: "c", val: 2]])
      lens = Lens.MapSet.has!(val: 2) |> Lens.key(:name)

      assert_raise(KeyError, ~s/key :val not found in: [name: "b"]/, fn ->
        Deeply.get_all(container, lens)
      end)
    end


    test "missing key: struct" do
      container = MapSet.new([ %Point{x: 1, y: 2}, %Point{x: 2, y: 3} ])
      lens = Lens.MapSet.has!(missing: 2)

      msg = ~s/key :missing not found in: %Lens2.Lenses.MapSetTest.Point{y: 2, x: 1}/
      assert_raise(KeyError, msg, fn ->
        Deeply.put(container, lens, :NEW)
      end)
    end
  end

end
