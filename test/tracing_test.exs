defmodule Lens2.TracingTest do
  use Lens2.Case
  alias Lens2.Helpers.Tracing
  alias Tracing.LogItem

  test "log entry and exit" do
    item = LogItem.on_entry(:key?, [:a], %{a: 4})

    item
    |> assert_fields(call: "key?(:a)", container: "%{a: 4}")
    |> assert_fields(gotten: nil, updated: nil)

    LogItem.on_exit(item, [4], %{a: 5})
    |> assert_fields(call: "key?(:a)", container: "%{a: 4}")
    |> assert_fields(gotten: "[4]", updated: "%{a: 5}")
  end

  test "building the log" do
    assert Tracing.current_nesting == nil
    assert Tracing.peek_at_log == nil

    outer = %{a: %{b: 1}}
    Tracing.entry(:key, [:a], outer)
    assert Tracing.peek_at_log(level: 0) == LogItem.on_entry(:key, [:a], outer)
    assert Tracing.current_nesting == 1

    Tracing.entry(:key?, [:b], outer.a)
    assert Tracing.peek_at_log(level: 1) == LogItem.on_entry(:key?, [:b], outer.a)
    assert Tracing.current_nesting == 2

    Tracing.exit({[:inner_gotten], :inner_updated})
    expected =
      LogItem.on_entry(:key?, [:b], outer.a)
      |> LogItem.on_exit([:inner_gotten], :inner_updated)
    assert Tracing.peek_at_log(level: 1) == expected
    assert Tracing.current_nesting == 1

    # Normally the log is spilled when pop out of final level
    log =
      Tracing.exit({[:outer_gotten], :outer_updated},
                   &Tracing.peek_at_log/0)

    expected =
      LogItem.on_entry(:key, [:a], outer)
      |> LogItem.on_exit([:outer_gotten], :outer_updated)
    assert log[0] == expected

    # IO.inspect log

    # ready for next go-round
    assert Tracing.current_nesting == nil
    assert Tracing.peek_at_log == nil
  end

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

      assert Tracing.prettify_calls(input) == expected
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

      assert Tracing.indent_calls(input, :call) == expected
    end

    test "length_of_name" do
      assert Tracing.length_of_name("key(:a)") == 3
    end

    test "max_length" do
      input = %{
        0 => %{gotten: "1234"},
        1 => %{gotten: "12345"},
        2 => %{gotten: "12"}
      }

      assert Tracing.max_length(input, :gotten) == 5
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

      assert Tracing.pad_right(input, :gotten) == expected
    end

  end

  @tag :skip
  test "trace" do

    map = %{a: %{b: %{c: %{d: 1}}}}
    lens = Lens.key?(:a) |> Lens.key?(:b) |> Lens.key?(:c) |> Lens.key?(:d)

    Deeply.put(map, lens, :NEW) |> dbg

    IO.puts("======")

    lens = Lens.tracing_key?(:a) |> Lens.tracing_key?(:b) |> Lens.tracing_key?(:c) |> Lens.tracing_key?(:d)
    Deeply.put(map, lens, :NEW) |> dbg

    # map = %{a: %{bb: %{c: 1, d: 2},
    #              cc: %{c: 3}}}
    # lens = Lens.key(:a) |> Lens.keys?([:bb, :cc]) |> Lens.key!(:c) # |> Lens.map_values


    # lens = Lens.tracing_key(:a) |> Lens.tracing_keys?([:bb, :cc]) |> Lens.tracing_key!(:c) # |> Lens.tracing_map_values
    # Deeply.to_list(map, lens) |> dbg


  end

end
