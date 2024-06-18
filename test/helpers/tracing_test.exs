defmodule Lens2.Helpers.TracingTest do
  use Lens2.Case
#  alias Lens2.Helpers.Tracing
#  alias Tracing.LogItem
#  alias Tracing.Mutable

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
