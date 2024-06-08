defmodule Lens2.Lenses.KeyedTest do
  use ExUnit.Case
  use Lens2
  use FlowAssertions

  defmodule SomeStruct do
    defstruct [:a, :b]
  end

  doctest Lens2.Lenses.Keyed


  test "useful error message" do
    assert_raise(RuntimeError, "keys/1 takes a list as its argument.", fn ->
      Lens.keys(:a, :b)
    end)

    assert_raise(RuntimeError, "keys?/1 takes a list as its argument.", fn ->
      Lens.keys?(:a, :b)
    end)

    assert_raise(RuntimeError, "keys!/1 takes a list as its argument.", fn ->
      Lens.keys!(:a, :b)
    end)
  end
end
