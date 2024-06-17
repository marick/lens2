alias Lens2.Helpers.Tracing

defmodule Tracing.PrettyTest do
  use Lens2.Case
  alias Tracing.Pretty
  alias Tracing.{EntryLine,ExitLine}

  def funcall_entry(string),
      do: %EntryLine{call: string, container: "irrelevant"}
  def funcall_exit(string),
      do: %ExitLine{call: string, gotten: "irrelevant", updated: "irrelevant"}

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

  test "adjusting one string to match another" do
    assert Pretty.shift_to_align("1", "abc") == "1"
    assert Pretty.shift_to_align("12", "ab 12 34") == "   12"
  end

  test "splitting lines by change of direction" do
    [funcall_entry("at(0)"), funcall_entry("at(1)"),
     funcall_exit("at(1)"), funcall_exit("at(0)")]
    |> Pretty.split_lines_at_change_of_direction
    |> assert_equal([[funcall_entry("at(0)"), funcall_entry("at(1)")],
                     [funcall_exit("at(1)"), funcall_exit("at(0)")]])
  end

  test "length_of_name" do
    assert Pretty.length_of_name("key(:a)") == 3
  end
end
