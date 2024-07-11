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


  describe "how to align a line" do
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


    test "continuing deeper finds match among previous", %{s: s} do
      data = s.data_at.(1);
      confirm(data, type: ContainerLine, action: Coordinate.continue_deeper)

      actual = Data.describe_adjustment(data)
      assert actual == [align_under_substring: s.coordinate_at.(0)]
    end

    test "beginning retreat centers under previous container", %{s: s} do
      data = s.data_at.(4);
      confirm(data, type: GottenLine, action: Coordinate.begin_retreat)

      actual = Data.describe_adjustment(data)
      assert actual == [center_under: s.coordinate_at.(3)]
    end

    test "continuing to retreat leaves a blank line", %{s: s} do
      data = s.data_at.(5);
      confirm(data, type: GottenLine, action: Coordinate.continue_retreat)

      assert Data.describe_adjustment(data) == :erase
    end

    test "turning deeper", %{s: s} do
      # Here are the lines that need adjusting
      all_to_adjust = [6, 11, 16]
      for i <- all_to_adjust do
        s.data_at.(i)
        |> confirm(type: ContainerLine, action: Coordinate.turn_deeper)
      end

      # Here are the controlling lines. Note that are always "continue"
      all_controlling = [2, 1, 12]
      for i <- all_controlling do
        s.data_at.(i)
        |> confirm(type: ContainerLine, action: Coordinate.continue_deeper)
      end

      # Here are the coordinates that need adjusting
      assert s.coordinate_at.( 6) == Coordinate.new(:>, [1, 0, 0])
      assert s.coordinate_at.(11) == Coordinate.new(:>,    [1, 0])
      assert s.coordinate_at.(16) == Coordinate.new(:>, [3, 1, 0])

      # Here are the coordinates whose position should be copied
      assert s.coordinate_at.( 2) == Coordinate.new(:>, [0, 0, 0])
      assert s.coordinate_at.( 1) == Coordinate.new(:>,    [0, 0])
      assert s.coordinate_at.(12) == Coordinate.new(:>, [2, 1, 0])

      # And here's showing the work done:
      for {needy_index, guiding_index}
          <- Enum.zip(all_to_adjust, all_controlling) do
        data = s.data_at.(needy_index)
        actual = Data.describe_adjustment(data)
        assert actual == [copy: s.coordinate_at.(guiding_index)]
      end
    end
  end

  @guidance_coordinate :guidance_coordinate # internals not used
  @subject_coordinate :subject_coordinate

  def make_map(guidance, subject) do
    %{@guidance_coordinate => guidance, @subject_coordinate => subject}
  end
  alias Adjustable.Adjuster

  describe "aligning ContainerLines under another one" do
    test "align under substring" do
      map =
        make_map(
          %{indent: 5, action: Coordinate.continue_deeper,
            string:    "[%{a: 5}]"},
          %{type: ContainerLine, indent: 0,
            string:     "%{a: 5}"})

      Adjuster.adjust(map, @subject_coordinate,
                      align_under_substring: @guidance_coordinate)
      |> Map.get(@subject_coordinate)
      |> assert_field(indent: 6)
    end

  @tag :skip
    test "one that shows a guidance that has two identical values" do
      # something like [0, 0, 0, 0, 0]      applying Lens.indices([0, 4])
      #                [0]
      #                   [0]
      # Even better would be
      #
      #                            [0]
      # ... but I don't think that's generally possible.                          # Or maybe the confusion the first would cause
      # makes this better:
      #
      #         >      [0, 0, 0, 0, 0]
      #         <      [0]
      #         >      [0, 0, 0, 0, 0]
      #         <      [0]
      #
    end

  end
end
