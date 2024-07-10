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
      |> assert_fields(type: Adjustable.ContainerLine,
                       coordinate: Coordinate.new(:>, [0]),
                       string: "[%{a: 1}]",
                       index: 0,
                       action: :no_previous_direction)

      line1
      |> assert_fields(type: Adjustable.ContainerLine,
                       coordinate: Coordinate.new(:>, [0, 0]),
                       string: "%{a: 1}",
                       index: 1,
                       action: Coordinate.continue_deeper)


      line2
      |> assert_fields(type: Adjustable.GottenLine,
                       coordinate: Coordinate.new(:<, [0, 0]),
                       string: "[1]",
                       index: 2,
                       action: Coordinate.begin_retreat)

      line3
      |> assert_fields(type: Adjustable.GottenLine,
                       coordinate: Coordinate.new(:<, [0]),
                       string: "[[1]]",
                       index: 3,
                       action: Coordinate.continue_retreat)
    end

  end

  test "construction of 'get map'" do
    {in_order, coordinate_to_data} =
      Adjustable.Maker.condense(:gotten, typical_get_log())

    assert Enum.at(in_order, 0) == Coordinate.new(:>, [0])

    coordinate_to_data[Enum.at(in_order, 0)]
    |> assert_fields(indent: 0,
                     string:
                       "%{zzz: [%{aa: %{a: 1}, bb: %{a: 2}}, %{aa: %{a: 3}, bb: %{a: 4}}]}",
                     coordinate: Coordinate.new(:>, [0]),
                     index: 0,
                     start_search_at: 0)

    assert Enum.at(in_order, 6) == Coordinate.new(:>, [1, 0, 0])

    coordinate_to_data[Enum.at(in_order, 6)]
    |> assert_fields(indent: 0,
                     string:
                       "%{aa: %{a: 1}, bb: %{a: 2}}",
                     coordinate: Coordinate.new(:>, [1, 0, 0]),
                     index: 6,
                     start_search_at: 0)
  end


  describe "picking the coordinate to align yourself with" do
    alias Adjustable.Data
    alias Adjustable.{ContainerLine,GottenLine}

    setup do
      {in_order, coordinate_to_data} = Adjustable.Maker.condense(:gotten, typical_get_log())
      coordinate_at = fn index -> Enum.at(in_order, index) end
      data_at = fn index -> coordinate_to_data[coordinate_at.(index)] end

      [s: %{coordinate_at: coordinate_at, data_at: data_at}]
    end

    # Check that the setup is as I expect
    def confirm(data, type: type, action: action) do
      assert data.action == action
      assert data.type == type
    end


    test "continuing deeper adjusts to the previous", %{s: s} do
      data = s.data_at.(1);
      confirm(data, type: ContainerLine, action: Coordinate.continue_deeper)

      assert Data.guiding_coordinate_for(data) == s.coordinate_at.(0)
    end

    test "beginning retreat", %{s: s} do
      data = s.data_at.(4);
      confirm(data, type: GottenLine, action: Coordinate.begin_retreat)


      assert Data.guiding_coordinate_for(data) == s.coordinate_at.(3)
    end

  end


end
