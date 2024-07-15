alias Lens2.Helpers.Tracing

defmodule Tracing.PrettyTest do
  use Lens2.Case
  alias Tracing.Pretty
  alias Tracing.{EntryLine,ExitLine}

  def funcall_entry(string),
      do: %EntryLine{call: string, container: "irrelevant"}
  def funcall_exit(string),
      do: %ExitLine{call: string, gotten: "irrelevant", updated: "irrelevant"}


  describe "abbreviate_long_calls" do
    test "rename_call" do
      assert Pretty.rename_call("key(:a)") == "key(:a)"

      input = "seq(#Function<22.71732265/3 in Lens2.Lenses.Keyed.tracing_map_values/0>,#Function<7.73076862/3 in Lens2.Lenses.Enum.tracing_into/2>)"
      assert Pretty.rename_call(input) == "seq(...)"
    end
  end


  describe "calculate leading spaces" do
    test "a simple entry and exit" do
      log = [funcall_entry("key(a)"),
             funcall_exit("key(a)")]
      expected = [">key(a)", "<key(a)"]

      actual =  Pretty.indent_calls(log) |> Enum.map(& &1.call)
      assert actual == expected
    end

    test "simple nesting" do
      log = [funcall_entry("key(a)"),
               funcall_entry("key!(b)"),
                 funcall_entry("map_values()"),
                 funcall_exit("map_values()"),
               funcall_exit("key!(b)"),
             funcall_exit("key(a)")]

      actual = Pretty.indent_calls(log) |> Enum.map(& &1.call)
      expected = [">key(a)",
                  "   >key!(b)",
                  "       >map_values()",
                  "       <map_values()",
                  "   <key!(b)",
                  "<key(a)"
      ]
      assert actual == expected
    end

    test "zig-zag nesting" do
      log = [funcall_entry("key(a)"),
               funcall_entry("keys([a, b])"),
                 funcall_entry("map_values()"),
                 funcall_exit("map_values()"),
                 funcall_entry("map_values()"),
                 funcall_exit("map_values()"),
               funcall_exit("keys([a, b])"),
             funcall_exit("key(a)")]

      actual = Pretty.indent_calls(log) |> Enum.map(& &1.call)
      expected = [">key(a)",
                  "   >keys([a, b])",
                  "       >map_values()",
                  "       <map_values()",
                  "       >map_values()",
                  "       <map_values()",
                  "   <keys([a, b])",
                  "<key(a)"
      ]
      assert actual == expected
    end
  end

  describe "aligning substrings with line above or below" do
    test "adjusting one line to match the previous" do
      actual = Pretty.shift_to_align(%{key: "1"}, %{key: "345"}, :key)
      assert actual == %{key: "1"}

      actual = Pretty.shift_to_align(%{key: "12"}, %{key: "ab 12 34"}, :key)
      assert actual == %{key: "   12"}
    end

    test "splitting lines by change of direction" do
      [funcall_entry("at(0)"), funcall_entry("at(1)"),
       funcall_exit("at(1)"), funcall_exit("at(0)")]
      |> Pretty.split_lines_at_change_of_direction
      |> assert_equal([[funcall_entry("at(0)"), funcall_entry("at(1)")],
                       [funcall_exit("at(1)"), funcall_exit("at(0)")]])
    end



    test "aligning EntryLines" do
      input =
        [EntryLine.new("some_call", "%{b: %{c: %{d: 1}}}"),
         EntryLine.new("some_call", "%{c: %{d: 1}}"),
         EntryLine.new("some_call", "%{d: 1}"),
         EntryLine.new("some_call", "%{d: 2}"),
         EntryLine.new("some_call", "88888888888888")
        ]

      actual =
        Pretty.align_one_direction(input, :gotten) |> Enum.map(& Map.get(&1, :container))

      expected =
        ["%{b: %{c: %{d: 1}}}",
         "     %{c: %{d: 1}}",
         "          %{d: 1}",
         "%{d: 2}",
         "88888888888888"]

      assert actual == expected
    end

    test "aligning ExitLines" do
      input =
        [ExitLine.new("some_call", "[nil]", "1"),
         ExitLine.new("some_call", "[[nil]]", "%{b: 1}"),
         ExitLine.new("some_call", "[[[nil]]]", "%{a: %{b: 1}}")
        ]

      actual = Pretty.align_one_direction(input, :gotten)

      expected =
        ["  [nil]",
         " [[nil]]",
         "[[[nil]]]"]
      assert Enum.map(actual, & Map.get(&1, :gotten)) == expected

      actual = Pretty.align_one_direction(input, :updated)

      expected =
        ["          1",
         "     %{b: 1}",
         "%{a: %{b: 1}}"
        ]
      assert Enum.map(actual, & Map.get(&1, :updated)) == expected

    end
  end

  describe "padding to equal-width lines" do
    test "calculating max lengths" do

      input = [%{a: "1234",                        },
               %{a: "1",    b: "1"                 },
               %{           b: "123456"            },
               %{           b: "123",  c: :ignored },
      ]

      actual = Pretty.max_lengths(input, [:a, :b])
      expected = %{a: 4, b: 6}
      assert actual == expected
    end

    test "non-ragged right margins" do
      input =    [%{a: "1234",                        },
                  %{a: "1",    b: "1"                 },
                  %{           b: "123456"            },
                  %{           b: "123",  c: :ignored },
      ]
      expected = [%{a: "1234",                        },
                  %{a: "1   ", b: "1     "            },
                  %{           b: "123456"            },
                  %{           b: "123   ",  c: :ignored },
      ]

      actual = Pretty.equalize_widths(input, [:a, :b])
      assert actual == expected
    end
  end

  describe "length_of_name" do
    test "normal case" do
      assert Pretty.length_of_name("key(:a)") == 3
    end

    test "not fooled by extra parentheses" do
      call = "into(#Function<5.7307686...>,MapSet.new([]))"
      assert Pretty.length_of_name(call) == 4
    end
  end
end
