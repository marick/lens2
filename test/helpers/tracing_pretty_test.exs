alias Lens2.Helpers.Tracing

defmodule Tracing.PrettyTest do
  use Lens2.Case
  alias Tracing.Pretty

  describe "prettifying call strings" do

    test "prettification" do
      input = %{
        0 => %{call: "key(:a)"},
        1 => %{call: "map_values()", other: :ignored},
        2 => %{call: "keys([:aa, :bb])"}
      }

      expected = %{
        0 => %{call: "key(:a)                      "},
        1 => %{call: "   map_values()              ", other: :ignored},
        2 => %{call: "             keys([:aa, :bb])"}
      }

      assert Pretty.prettify_calls(input) == expected
    end

    test "indented call strings" do
      input = %{
        0 => %{call: "key(:a)"},
        1 => %{call: "map_values()", other: :ignored},
        2 => %{call: "keys([:aa, :bb])"}
      }

      expected = %{
        0 => %{call: "key(:a)"},
        1 => %{call: "   map_values()", other: :ignored},
        2 => %{call: "             keys([:aa, :bb])"}
      }

      assert Pretty.indent_calls(input, :call) == expected
    end

    test "length_of_name" do
      assert Pretty.length_of_name("key(:a)") == 3
    end

    test "max_length" do
      input = %{
        0 => %{gotten: "1234"},
        1 => %{gotten: "12345"},
        2 => %{gotten: "12"}
      }

      assert Pretty.max_length(input, :gotten) == 5
    end

    test "pad_right" do
      input = %{
        0 => %{gotten: "1234"},
        1 => %{gotten: "12345"},
        2 => %{gotten: "12"}
      }

      expected = %{
        0 => %{gotten: "1234 "},
        1 => %{gotten: "12345"},
        2 => %{gotten: "12   "}
      }

      assert Pretty.pad_right(input, :gotten) == expected
    end

  end

end
