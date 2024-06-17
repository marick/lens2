defmodule Lens2.Helpers.TracingTest do
  use Lens2.Case
#  alias Lens2.Helpers.Tracing
#  alias Tracing.LogItem
#  alias Tracing.Mutable

  # test "building the log" do
  #   assert Mutable.current_nesting == nil
  #   assert Mutable.peek_at_log == nil

  #   outer = %{a: %{b: 1}}
  #   Tracing.log_entry(:key, [:a], outer)
  #   assert Mutable.peek_at_log(level: 0) == LogItem.on_entry(:key, [:a], outer)
  #   assert Mutable.current_nesting == 1

  #   Tracing.log_entry(:key?, [:b], outer.a)
  #   assert Mutable.peek_at_log(level: 1) == LogItem.on_entry(:key?, [:b], outer.a)
  #   assert Mutable.current_nesting == 2

  #   Tracing.log_exit({[:inner_gotten], :inner_updated})
  #   expected =
  #     LogItem.on_entry(:key?, [:b], outer.a)
  #     |> LogItem.on_exit([:inner_gotten], :inner_updated)
  #   assert Mutable.peek_at_log(level: 1) == expected
  #   assert Mutable.current_nesting == 1

  #   # Normally the log is spilled when pop out of final level
  #   log =
  #     Tracing.log_exit({[:outer_gotten], :outer_updated},
  #                      &Mutable.peek_at_log/0)

  #   expected =
  #     LogItem.on_entry(:key, [:a], outer)
  #     |> LogItem.on_exit([:outer_gotten], :outer_updated)
  #   assert log[0] == expected

  #   # IO.inspect log

  #   # ready for next go-round
  #   assert Mutable.current_nesting == nil
  #   assert Mutable.peek_at_log == nil
  # end


  @tag :skip
  test "trace" do

    map = %{a: %{b: %{c: %{d: 1}}}}
    lens = Lens.key?(:a) |> Lens.key?(:b) |> Lens.key?(:c) |> Lens.key?(:d)

    Deeply.put(map, lens, :NEW) |> dbg

    IO.puts("======")

    lens = Lens.tracing_key?(:a) |> Lens.tracing_key?(:b) |> Lens.tracing_key?(:c) |> Lens.tracing_key?(:d)
    Deeply.put(map, lens, :NEW) |> dbg

    # # map = %{a: %{bb: %{c: 1, d: 2},
    # #              cc: %{c: 3}}}
    # # lens = Lens.key(:a) |> Lens.keys?([:bb, :cc]) |> Lens.key!(:c) # |> Lens.map_values


    # # lens = Lens.tracing_key(:a) |> Lens.tracing_keys?([:bb, :cc]) |> Lens.tracing_key!(:c) # |> Lens.tracing_map_values
    # # Deeply.to_list(map, lens) |> dbg


  end

end
