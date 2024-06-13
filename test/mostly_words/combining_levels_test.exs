defmodule Lens2.CombiningLevelsTest do
  use ExUnit.Case
  use FlowAssertions
  use Lens2


  def values_to_list(tree) do
    case tree do
      %{value: value, deeper: deeper} ->
        [value | values_to_list(deeper)]
      %{} ->
        []
    end
  end

  @tag :skip
  test "values_to_list" do
    tree = %{value: 1,
             deeper: %{value: 2,
                       deeper: %{value: 3,
                                 deeper: %{}
    }}}

    assert [1, 2, 3] == values_to_list(tree)


    lens = Lens.add_levels_below(Lens.key?(:deeper)) |> Lens.key?(:value)

    dbg Deeply.to_list(tree, lens)

  end
end
