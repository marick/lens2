defmodule Tutorial.NonListTest do
  use ExUnit.Case
  use FlowAssertions
  use Lens2


  test "all" do
    Deeply.get_all([a: 1, b: 2], Lens.all) |> Enum.sort
    |> assert_equal([a: 1, b: 2])

    Deeply.get_all(%{a: 1, b: 2}, Lens.all) |> Enum.sort
    |> assert_equal([a: 1, b: 2])

    Deeply.get_all(%{1 => "1", 2 => "2"}, Lens.all) |> Enum.sort
    |> assert_equal([{1, "1"}, {2, "2"}])

  end
end
