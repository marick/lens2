alias Lens2.Tracing
alias Tracing.Adjustable

defmodule Adjustable.ActionsTest do
  use Lens2.Case
  alias Tracing.Coordinate
  # alias Tracing.Coordinate.Maker

  def deeper(value), do: %{direction: :>, container: value}
  def retreat(value), do: %{direction: :<, gotten: value}

  def typical_get_log, do: [
    deeper(%{zzz: [%{aa: %{a: 1}, bb: %{a: 2}},   %{aa: %{a: 3}, bb: %{a: 4}}]}),
      deeper(     [%{aa: %{a: 1}, bb: %{a: 2}},   %{aa: %{a: 3}, bb: %{a: 4}}]),
        deeper(    %{aa: %{a: 1}, bb: %{a: 2}}),
          deeper(        %{a: 1}),
          retreat(           [1]),
        retreat(            [[1]]),
        deeper(    %{aa: %{a: 1}, bb: %{a: 2}}),
          deeper(                     %{a: 2}),
          retreat(                        [2]),
        retreat(                         [[2]]),
      retreat(                  [[1], [2]]),

      deeper(    [%{aa: %{a: 1}, bb: %{a: 2}},   %{aa: %{a: 3}, bb: %{a: 4}}]),
        deeper(                                  %{aa: %{a: 3}, bb: %{a: 4}}),
          deeper(                                      %{a: 3}),
          retreat(                                         [3]),
        retreat(                                          [[3]]),
        deeper(                                  %{aa: %{a: 3}, bb: %{a: 4}}),
          deeper(                                                   %{a: 4}),
         retreat(                                                       [4]),
       retreat(                                                        [[4]]),
     retreat(                                              [[3], [4]]),
   retreat(                   [1, 2, 3, 4])   # not the result of the lens, rather Deeply.get_all
                   ]



  describe "getting the various kinds of information together" do
    test "make_map_values: various lines" do
      input = [deeper([%{a: 1}]),
                 deeper(%{a: 1}),
                 retreat([1]),
               retreat([[1]])]
      [line0, line1, line2, line3] = Adjustable.Maker.make_map_values(:gotten, input)

      line0
      |> assert_fields(coordinate: Coordinate.new(:>, [0]),
                       string: "[%{a: 1}]",
                       index: 0,
                       action: :no_previous_direction)

      line1
      |> assert_fields(coordinate: Coordinate.new(:>, [0, 0]),
                       string: "%{a: 1}",
                       index: 1,
                       action: Coordinate.continue_deeper)


      line2
      |> assert_fields(coordinate: Coordinate.new(:<, [0, 0]),
                       string: "[1]",
                       index: 2,
                       action: Coordinate.begin_retreat)

      line3
      |> assert_fields(coordinate: Coordinate.new(:<, [0]),
                       string: "[[1]]",
                       index: 3,
                       action: Coordinate.continue_retreat)
    end

  end

  describe "building the Maker map" do
    @tag :skip
    test "little example" do
      input = [deeper(%{a: 1}), retreat([1])]
      [line0, _line1] = Adjustable.Maker.make_map(:gotten, input)

      line0
      |> assert_fields(string: "%{a: 1}",
                       index: 0,
                       coordinate: Coordinate.new(:>, [0]),
                       action: Coordinate.continue_deeper)
    end

    @tag :skip
    test "construction of 'get map'" do
      get_map = Adjustable.Maker.make_map(:gotten, typical_get_log())
      get_map[Coordinate.new(:>, [0])]
      |> assert_fields(indent: 0,
                       string:
                         %{zzz: [%{aa: %{a: 1}, bb: %{a: 2}},   %{aa: %{a: 3}, bb: %{a: 4}}]},
                       coordinate: Coordinate.new(:>, [0]),
                       index: 0,
                       start_search_at: 0)
    end
  end
end
