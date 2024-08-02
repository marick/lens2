defmodule Tutorial.MissingTest do
  use ExUnit.Case
  use TypedStruct
  use FlowAssertions
  use Lens2

  typedstruct module: Point do
    field :x, integer
    field :y, integer
  end

  test "handling of structs by Lens.key" do
    assert Deeply.get_all(%Point{x: nil}, Lens.key(:x)) == [nil]
    assert Deeply.get_all(%Point{}, Lens.key(:missing)) == [nil]

    assert Deeply.put(%Point{x: nil}, Lens.key(:x), :NEW) == %Point{x: :NEW}

    Deeply.put(%Point{x: 1, y: 2}, Lens.key(:missing), :NEW)
    |> assert_fields(x: 1, y: 2, missing: :NEW, __struct__: Point)

    put_in(%Point{x: 1, y: 2}, [Access.key(:missing)], :NEW)
    |> assert_fields(x: 1, y: 2, missing: :NEW, __struct__: Point)

    Deeply.update(%Point{x: 1, y: 2}, Lens.key(:missing), &inspect/1)
    |> assert_fields(x: 1, y: 2, missing: "nil", __struct__: Point)

    update_in(%Point{x: 1, y: 2}, [Access.key(:missing)], &inspect/1)
    |> assert_fields(x: 1, y: 2, missing: "nil", __struct__: Point)
  end

  test "handling of structs by Lens.key?" do
    assert Deeply.get_all(%Point{x: nil}, Lens.key?(:x)) == [nil]
    assert Deeply.get_all(%Point{}, Lens.key?(:missing)) == []

    assert Deeply.put(%Point{x: nil}, Lens.key?(:x), :NEW) == %Point{x: :NEW}

    p = %Point{x: 1, y: 2}
    assert Deeply.put(p, Lens.key?(:missing), :NEW) == p

    Deeply.update(%Point{x: 1, y: 2}, Lens.keys?([:x, :y, :missing]), &inspect/1)
    |> assert_equal(%Point{x: "1", y: "2"})
  end

  test "handling of structs by Lens.key!" do
    assert_raise(KeyError, fn ->
      Deeply.get_all(%Point{}, Lens.key!(:missing))
    end)

    assert_raise(KeyError, fn ->
      Deeply.put(%Point{x: nil}, Lens.key!(:missing), :NEW)
    end)

    assert_raise(KeyError, fn ->
      Deeply.update(%Point{x: 1, y: 2}, Lens.keys!([:x, :y, :missing]), &inspect/1)
    end)
  end


  test "at on lists" do
    assert Deeply.get_all(["0", "1"], Lens.at(2)) == [nil]
    assert Deeply.get_all(["0", "1"], Lens.indices([0, 10000])) == ["0", nil]

    assert Deeply.put(["0", "1"], Lens.at(2), :NEW) == ["0", "1"]
    assert Deeply.update([0, 1], Lens.indices([0, 2]), &inspect/1) == ["0", 1]


    # This is a bug? See the tutorial on missing values.
    assert_raise(FunctionClauseError, fn ->
      Deeply.update(["0", "1"], Lens.at(2), &Integer.parse/1)
    end)
  end

  test "at on tuples" do
    assert_raise(ArgumentError, fn ->
      Deeply.get_all({"0", "1"}, Lens.at(2))
    end)

    assert_raise(ArgumentError, fn ->
      Tuple.append({"0", "1"}, "2")  # Prevent compiler warning
      |> elem(3)
    end)


    assert_raise(ArgumentError, fn ->
      Deeply.put({"0", "1"}, Lens.at(2), :NEW)
    end)
  end





end
