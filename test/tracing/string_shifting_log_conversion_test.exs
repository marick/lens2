alias Lens2.Tracing
alias Tracing.StringShifting

defmodule StringShifting.LogConversionTest do
  use Lens2.Case
  alias Tracing.Coordinate
  import Lens2.TestLogs

  describe "getting the various kinds of information together" do
    test "make_map_values: various lines" do
      input = [deeper([%{a: 1}]),
                 deeper(%{a: 1}),
                 retreat([1]),
               retreat([[1]])]
      [line0, line1, line2, line3] =
        StringShifting.LogLines.convert_to_shift_data(input, pick_result: :gotten)

      line0
      |> assert_fields(source: :container,
                       coordinate: Coordinate.new(:>, [0]),
                       string: "[%{a: 1}]",
                       index: 0,
                       action: :continue_deeper)

      line1
      |> assert_fields(source: :container,
                       coordinate: Coordinate.new(:>, [0, 0]),
                       string: "%{a: 1}",
                       index: 1,
                       action: Coordinate.continue_deeper)


      line2
      |> assert_fields(source: :gotten,
                       coordinate: Coordinate.new(:<, [0, 0]),
                       string: "[1]",
                       index: 2,
                       action: Coordinate.begin_retreat)

      line3
      |> assert_fields(source: :gotten,
                       coordinate: Coordinate.new(:<, [0]),
                       string: "[[1]]",
                       index: 3,
                       action: Coordinate.continue_retreat)
    end

  end

  test "construction of 'get map'" do
    {in_order, coordinate_to_data} =
      StringShifting.LogLines.condense(typical_get_log(), pick_result: :gotten)

    assert Enum.at(in_order, 0) == Coordinate.new(:>, [0])

    coordinate_to_data[Enum.at(in_order, 0)]
    |> assert_fields(indent: 0,
                     string:
                       "%{zzz: [%{aa: %{a: 1}, bb: %{a: 2}}, %{aa: %{a: 3}, bb: %{a: 4}}]}",
                     coordinate: Coordinate.new(:>, [0]),
                     index: 0)

    assert Enum.at(in_order, 6) == Coordinate.new(:>, [1, 0, 0])

    coordinate_to_data[Enum.at(in_order, 6)]
    |> assert_fields(indent: 0,
                     string:
                       "%{aa: %{a: 1}, bb: %{a: 2}}",
                     coordinate: Coordinate.new(:>, [1, 0, 0]),
                     index: 6)
  end


end
