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

  test "pad right" do
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

    actual = Pretty.pad_right(input, [:a, :b])
    assert actual == expected
  end

  # describe "prettifying call strings" do

  #   test "prettification" do
  #     input = %{
  #       0 => %{call: "key(:a)"},
  #       1 => %{call: "map_values()", other: :ignored},
  #       2 => %{call: "keys([:aa, :bb])"}
  #     }

  #     expected = %{
  #       0 => %{call: "key(:a)                      "},
  #       1 => %{call: "   map_values()              ", other: :ignored},
  #       2 => %{call: "             keys([:aa, :bb])"}
  #     }

  #     assert Pretty.prettify_calls(input) == expected
  #   end

  #   test "indented call strings" do
  #     input = %{
  #       0 => %{call: "key(:a)"},
  #       1 => %{call: "map_values()", other: :ignored},
  #       2 => %{call: "keys([:aa, :bb])"}
  #     }

  #     expected = %{
  #       0 => %{call: "key(:a)"},
  #       1 => %{call: "   map_values()", other: :ignored},
  #       2 => %{call: "             keys([:aa, :bb])"}
  #     }

  #     assert Pretty.indent_calls(input, :call) == expected
  #   end

  #   test "length_of_name" do
  #     assert Pretty.length_of_name("key(:a)") == 3
  #   end

  #   test "max_length" do
  #     input = %{
  #       0 => %{gotten: "1234"},
  #       1 => %{gotten: "12345"},
  #       2 => %{gotten: "12"}
  #     }

  #     assert Pretty.max_length(input, :gotten) == 5
  #   end

  #   test "pad_right" do
  #     input = %{
  #       0 => %{gotten: "1234"},
  #       1 => %{gotten: "12345"},
  #       2 => %{gotten: "12"}
  #     }

  #     expected = %{
  #       0 => %{gotten: "1234 "},
  #       1 => %{gotten: "12345"},
  #       2 => %{gotten: "12   "}
  #     }

  #     assert Pretty.pad_right(input, :gotten) == expected
  #   end

  # end

end
