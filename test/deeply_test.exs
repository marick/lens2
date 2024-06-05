defmodule Lens2.DeeplyTest do
  use ExUnit.Case
  use Lens2
  use FlowAssertions
  doctest Deeply

  test "to_list" do
    %{a: 1, b: 2, c: 3}
    |> Deeply.to_list(Lens.map_values)
    |> assert_good_enough(in_any_order([1, 2, 3]))
  end

  test "one!" do
    assert_raise(MatchError, fn ->
      %{a: 1, b: 2, c: 3}
      |> Deeply.one!(Lens.map_values)
    end)

    assert_raise(MatchError, fn ->
      %{a: 1, b: 2, c: 3}
      |> Deeply.one!(Lens.key?(:missing))
    end)
  end

  test "put" do
    lens = Lens.key(:a)
    keylist = [a: 1, other: 2, a: 3]

    # Surprising, yes, but consistent with `Access`.
    assert Deeply.put(keylist, lens, :NEW) == [a: :NEW, other: 2, a: 3]
  end
end
