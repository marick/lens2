alias Lens2.Tracing
alias Tracing.StringShifting

defmodule Tracing.StringShiftingTest do
  use Lens2.Case
  alias Tracing.Coordinate
  import Lens2.TestLogs

  describe "shifting" do
    test "trivial case" do
      input = [deeper(%{a: 1}),
               retreat([1])]
      actual = StringShifting.gotten_strings(input)
      expected = ["%{a: 1}",
                  "   [1]"]
      assert actual == expected
    end

    test "just in and out" do
      input = [deeper([%{a: 1}]),
               deeper( %{a: 1}),
               retreat(   [1]),
               retreat([1])]
      actual = StringShifting.gotten_strings(input)
      expected = ["[%{a: 1}]",
                  " %{a: 1}",
                   "    [1]",
                   "    [1]"

      ]
      assert actual == expected
    end

  end

  describe "how to align a line" do
    alias StringShifting.ShiftData
    alias Tracing.Adjust.{Preparation,Data}

    setup do
      {in_order, coordinate_to_data} =
        Preparation.prepare_aggregates(typical_get_log(), pick_result: :gotten)
      coordinate_at = fn index -> Enum.at(in_order, index) end
      data_at = fn index -> coordinate_to_data[coordinate_at.(index)] end

      [s: %{coordinate_at: coordinate_at, data_at: data_at}]
    end

    # Check that the setup is as I expect
    def confirm(data, source: source, action: action) do
      assert data.action == action
      assert data.source == source
    end


    test "continuing deeper finds match among previous", %{s: s} do
      data = s.data_at.(1);
      confirm(data, source: :container, action: Data.continue_deeper)

      actual = ShiftData.plan_for(data)
      assert actual == [align_under_substring: s.coordinate_at.(0)]
    end

    test "beginning retreat centers under previous container", %{s: s} do
      data = s.data_at.(4);
      confirm(data, source: :gotten, action: Data.begin_retreat)

      actual = ShiftData.plan_for(data)
      assert actual == [center_under: s.coordinate_at.(3)]
    end

    test "continuing to retreat leaves a blank line", %{s: s} do
      data = s.data_at.(5);
      confirm(data, source: :gotten, action: Data.continue_retreat)

      assert ShiftData.plan_for(data) == :make_invisible
    end

    test "turning deeper", %{s: s} do
      # Here are the lines that need adjusting
      all_to_adjust = [6, 11, 16]
      for i <- all_to_adjust do
        s.data_at.(i)
        |> confirm(source: :container, action: Data.turn_deeper)
      end

      # Here are the controlling lines. Note that are always "continue"
      all_controlling = [2, 1, 12]
      for i <- all_controlling do
        s.data_at.(i)
        |> confirm(source: :container, action: Data.continue_deeper)
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
        actual = ShiftData.plan_for(data)
        assert actual == [copy: s.coordinate_at.(guiding_index)]
      end
    end
  end


  @guidance_coordinate :guidance_coordinate # internals not used
  @subject_coordinate :subject_coordinate

  def make_map(guidance, subject) do
    %{@guidance_coordinate => guidance, @subject_coordinate => subject}
  end
  alias StringShifting.Adjuster
  alias Tracing.Adjust.Data

  describe "aligning :containers under another one" do
    test "align under substring" do
      map =
        make_map(
          %{indent: 5, action: Data.continue_deeper,
            string:    "[%{a: 5}]"},
          %{source: :container, indent: 0,
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

  describe "centering :gotten lines under their source" do
    test "center under substring" do
      map =
        make_map(
          %{indent: 5, action: Data.continue_deeper,
            string:    "%{a: 5}"},
          %{source: :container, indent: 0,
            string:        "[5]"})

      Adjuster.adjust(map, @subject_coordinate,
                      center_under: @guidance_coordinate)
      |> Map.get(@subject_coordinate)
      |> assert_field(indent: 8)
    end

    @tag :skip
    test "perhaps it should align under matching text in case where there is some" do
    end
  end

  def final_alignment_map(descriptors) do
    for [coordinate | opts] <- descriptors, into: %{} do
      {coordinate, Map.new([{:coordinate, coordinate} | opts])}
    end
  end



  describe "aligning the last line" do
    test "a single result" do
      [c1, c2, c3] = [
        Coordinate.new(:<, [0, 0, 0]),
        Coordinate.new(:<,    [0, 0]),
        Coordinate.new(:<,       [0])
      ]
      shift_data = [
        [c1, action: :begin_retreat,    string: "[1]", indent: 3, index: 6],
        [c2, action: :continue_retreat, string: "",    indent: 0],
        [c3, action: :continue_retreat, string: "[1]", indent: 0]
      ]
      shift_map = final_alignment_map(shift_data)
      actual = StringShifting.align_final_retreat(shift_map)
      assert actual[c3].indent == actual[c1].indent
      assert actual[c3].string == "[1]"
    end
  end
end
