alias Lens2.Tracing

defmodule Tracing.GetFormattingTest do
  use Lens2.Case
  alias Tracing.Get
  alias Get.Worker

  def log_line(direction, value) do
    %{direction: direction, container: value}
  end


  @tag :skip
  test "there is no log at all" do
  end

  @tag :skip
  test "entry and immediate exit" do

  end

  describe "construction: nesting" do
    test "The initial line" do
      value = %{z: [64, 12], m: 1, a: 5}
      {get_line, worker} = Worker.new(log_line(:>, value))

      assert_fields(get_line,
                    indent: 0,
                    value: value,
                    # Note alphabetic order, plus no weird ~c"@\f".
                    string: "%{a: 5, m: 1, z: [64, 12]}",
                    order: 0)

      assert Deeply.get_only(worker, Worker.line_for([0])) == get_line
    end

    test "construction of a further line: going into" do
      value0 = %{a: %{b: 1}}
      value1 =      %{b: 1}
              #12345
      {get_line0, worker} = Worker.new(log_line(:>, value0))
      {get_line1, worker} = Worker.add(worker, log_line(:>, value1), after: get_line0)

      assert_fields(get_line1, order: 1,
                               value: value1,
                               nesting: [0, 0],
                               direction: :>)

      assert Deeply.get_only(worker, Worker.line_for([0, 0])) == get_line1
    end
  end




  # def line(:>, value), do: %{direction: :>, container: value}
  # def line(:<, value), do: %{direction: :<, gotten: value}

  # test "step 1: initialize with lines" do
  #   map =
  #     Indentation.step1_init([
  #       line(:>, %{a: [0, 1, 2]}),
  #       line(  :>,    [0, 1, 2]),
  #       line(  :<,       [1]),
  #       line(:<,        [[1]])
  #     ])

  #   map[0]
  #   |> assert_fields(direction: :>,
  #                    left_margin: 0,
  #                    indentation_source: :uncalculated,
  #                    output: Common.stringify(%{a: [0, 1, 2]}))

  #   map[1]
  #   |> assert_fields(direction: :>,
  #                    left_margin: 0,
  #                    indentation_source: :uncalculated,
  #                    output: Common.stringify([0, 1, 2]))

  #   map[2]
  #   |> assert_fields(direction: :<,
  #                    left_margin: 0,
  #                    indentation_source: :uncalculated,
  #                    output: Common.stringify([1]))

  #   map[3]
  #   |> assert_fields(direction: :<,
  #                    left_margin: 0,
  #                    indentation_source: :uncalculated,
  #                    output: Common.stringify([[1]]))
  # end

  # describe "recording text to consult to check indentation" do
  #   test "descent and ascent - 2 levels" do
  #     map =
  #       [
  #         line(:>, %{a: [0, 1, 2]}    ),
  #         line(  :>,    [0, 1, 2]     ),
  #         line(  :<,       [1]        ),
  #         line(:<,         [1]        )
  #       ]
  #       |> Indentation.step1_init()
  #       |> Indentation.step2_note_indentation_source

  #     # 0 has no source
  #     assert map[1].indentation_source == 0
  #     assert map[2].indentation_source == 1
  #     # 3 has no source.
  #   end

  #   test "descent and ascent - 3 levels" do
  #     map =
  #       [
  #         line(:>, %{a: %{b: [0, 1, 2]}}     ), # 0
  #         line(  :>,    %{b: [0, 1, 2]}      ), # 1
  #         line(    :>,       [0, 1, 2]       ), # 2
  #         line(    :<,          [1]          ), # 3
  #         line(  :<,                       ""), # 4 - output later replaced with blank
  #         line(:<,              [1]          )  # 5
  #       ]
  #       |> Indentation.step1_init()
  #       |> Indentation.step2_note_indentation_source

  #     # 0 has no source
  #     assert map[1].indentation_source == 0
  #     assert map[2].indentation_source == 1
  #     assert map[3].indentation_source == 2
  #     # Don't care about 4 - it becomes a blank line
  #     # 5 has no source.
  #   end

  #   test "a complicated case" do

  #     map =
  #       [
  #         line(:>, %{a: %{b: %{c: [0, 1, 2], d: [0, 1, 2]}}}    ), # 0  key(:a)
  #         line(   :>,   %{b: %{c: [0, 1, 2], d: [0, 1, 2]}}     ), # 1  key(:b)
  #         line(      :>,     %{c: [0, 1, 2], d: [0, 1, 2]}      ), # 2  keys(:c, :d) - :c
  #         line(         :>,       [0, 1, 2]                     ), # 3  at(1)
  #         line(         :<,          [1]                        ), # 4
  #         line(      :<,                                      ""), # 5
  #         line(      :>,     %{c: [0, 1, 2], d: [0, 1, 2]}      ), # 6  keys(:c, :d) - :d
  #         line(         :>,                     [0, 1, 2]       ), # 7
  #         line(         :<,                        [1]          ), # 8
  #         line(      :<,                                      ""), # 9
  #         line(   :<,                                         ""), # 10
  #         line(:<,                   [1,            1]          )  # 11
  #       ]
  #       |> Indentation.step1_init()
  #       |> Indentation.step2_note_indentation_source

  #     # 0 has no source
  #     assert map[1].indentation_source == 0
  #     assert map[2].indentation_source == 1
  #     assert map[3].indentation_source == 2
  #     assert map[4].indentation_source == 3
  #     # Don't care about 5 - it becomes a blank line
  #     assert map[6].indentation_source == 1
  #     assert map[7].indentation_source == 6
  #     assert map[8].indentation_source == 7
  #     # don't care about 9 or 10
  #     # 11 is a special case


  #   end
  # end



  # def mod_adjust(_, _), do: nil

  # def add_editable(map, line, direction, text) do
  #   Map.put(map, line, %{direction: direction, text: text, consumed: 0})
  # end

  # # describe "indenting lines to match lines from which they were extracted" do
  # #   @tag :skip
  # #   test "entering  a container" do
  # #     editables =
  # #       %{}
  # #       |> add_editable(0, :>, "%{a: %{aa: %{aaa: 1}}, b: %{aa: %{aaa: 1}}}")
  # #       |> add_editable(1, :>,      "%{aa: %{aaa: 1}}")

  # #     adjust(line: 1, 0




  # #     previous = %{direction: :>, consumed: 0, output: cause_line }
  # #     current =  %{direction: :>,              output: effect_line }

  # #     actual = mod_adjust()
  # #     assert String.split_at(cause_line, actual.consumed) ==
  # #              {"%{a: %{aa: %{aaa: 1}}", ", b: %{aa: %{aaa: 1}}}"}

  # #     assert actual.indented == "     %{aa: %{aaa: 1}}"
  # #                             # "%{a: %{aa: %{aaa: 1}}, b: %{aa: %{aaa: 1}}}"
  # #   end

  # #   @tag :skip
  # #   test "fetching a second value going in" do
  # #     cause_line = "%{a: %{aa: %{aaa: 1}}, b: %{aa: %{aaa: 1}}}"
  # #     effect_line =     "%{aa: %{aaa: 1}}"
  # #     previous = %{direction: :>, consumed: 19, output: cause_line }
  # #     #                                     ^^
  # #     current =  %{direction: :>,               output: effect_line }

  # #     actual = mod_adjust(previous, current)
  # #     assert String.split_at(cause_line, actual.consumed) ==
  # #              {"%{a: %{aa: %{aaa: 1}}, b: %{aa: %{aaa: 1}}", "}"}

  # #     assert actual.indented == "                          %{aa: %{aaa: 1}}"
  # #                             # "%{a: %{aa: %{aaa: 1}}, b: %{aa: %{aaa: 1}}}"
  # #   end


  # #   @tag :skip
  # #   test "the first pop from the stack" do
  # #     cause_line =      "            %{aa: %{aaa: 1}}"
  # #     effect_line =                             "[1]"
  # #     previous = %{direction: :>, consumed: 0, output: cause_line }
  # #     current =  %{direction: :<,              output: effect_line }

  # #     %{consumed: :not_applicable, output: output} = mod_adjust(previous, current)
  # #     assert output == # "            %{aa: %{aaa: 1}}"
  # #                        "                        [1]"
  # #   end

  # #   @tag :skip
  # #   test "later pops from the stack" do
  # #     cause_line = "            [1]"
  # #     effect_line = "[[1]]"
  # #     previous = %{direction: :<, consumed: 1000, output: cause_line }
  # #     current =  %{direction: :<,                 output: effect_line }

  # #     %{consumed: :not_applicable, output: output} = mod_adjust(previous, current)
  # #     assert output == ""
  # #   end
  # # end

end
