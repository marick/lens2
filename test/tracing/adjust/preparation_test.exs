alias Lens2.Tracing
alias Tracing.Adjust

defmodule Adjust.PreparationTest do
  use Lens2.Case
  alias Tracing.Coordinate
  import Lens2.TestLogs
  alias Adjust.{Preparation,Data}

  test "how log lines are processed into adjustment-supporting data" do
      input = [deeper([%{a: 1}]),
                 deeper(%{a: 1}),
                 retreat([1]),
               retreat([[1]])]
      [line0, line1, line2, line3] =
        Preparation.prepare_lines(input, pick_result: :gotten)

      line0
      |> assert_fields(source: :container,
                       coordinate: Coordinate.first_descent,
                       string: "[%{a: 1}]",
                       index: 0,
                       action: :continue_deeper)

      line1
      |> assert_fields(source: :container,
                       coordinate: Coordinate.new(:>, [0, 0]),
                       string: "%{a: 1}",
                       index: 1,
                       action: Data.continue_deeper)


      line2
      |> assert_fields(source: :gotten,
                       coordinate: Coordinate.new(:<, [0, 0]),
                       string: "[1]",
                       index: 2,
                       action: Data.begin_retreat)

      line3
      |> assert_fields(source: :gotten,
                       coordinate: Coordinate.final_retreat,
                       string: "[[1]]",
                       index: 3,
                       action: Data.continue_retreat)
    end

  test "construction of aggregates" do
    {coordinate_list, coordinate_map} =
      Preparation.prepare_aggregates(typical_get_log(), pick_result: :gotten)

    assert Enum.at(coordinate_list, 0) == Coordinate.first_descent

    coordinate_map[Enum.at(coordinate_list, 0)]
    |> assert_fields(indent: 0,
                     string:
                       "%{zzz: [%{aa: %{a: 1}, bb: %{a: 2}}, %{aa: %{a: 3}, bb: %{a: 4}}]}",
                     coordinate: Coordinate.first_descent,
                     index: 0)

    assert Enum.at(coordinate_list, 6) == Coordinate.new(:>, [1, 0, 0])

    coordinate_map[Enum.at(coordinate_list, 6)]
    |> assert_fields(indent: 0,
                     string:
                       "%{aa: %{a: 1}, bb: %{a: 2}}",
                     coordinate: Coordinate.new(:>, [1, 0, 0]),
                     index: 6)
  end
end
