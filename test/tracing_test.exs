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

    assert Tracing.indent_calls(input) == expected
  end

  test "length_of_name" do
    assert Tracing.length_of_name("key(:a)") == 3
  end

  @tag :skip
  test "trace" do

    # alias Lens2.Lenses.Keyed

    # x = quote do
    #       Keyed.tracing_keys([:a])
    # end

    # Macro.expand_once(x, __ENV__) |> Macro.to_string |> IO.puts

#    lens = Lens.tracing_keys([:a]) |> Lens.tracing_key?(:b)
   lens = Lens.tracing_key(:a) |> Lens.tracing_keys?([:b]) |> Lens.tracing_map_values
    #    lens = Lens.tracing_key(:a)
    # lens = Lens.tracing_keys([:a])
    Deeply.to_list(%{a: %{b: %{c: 1, d: 2}}}, lens) |> dbg
#    assert Deeply.to_list(%{a: %{b: 1}}, lens) == [1]

    # assert Deeply.put(%{a: %{b: 1}}, lens, :NEW) == %{a: %{b: :NEW}}

    # Deeply.get_and_update(%{a: %{b: 1}}, lens, fn value ->
    #   {value, value * 1111}
    # end)

  end

end
