defmodule Lens2.Helpers.TracingTest do
  use Lens2.Case
#  alias Lens2.Helpers.Tracing
#  alias Tracing.LogItem
#  alias Tracing.Mutable

  @tag :skip
  test "trace" do

    map = %{a: %{aa: %{aaa: %{aaaa: 1,
                              bbbb: 2},
                       bbb: %{aaaa: 3,
                              bbbb: 4}},
                 bb: %{aaa: %{aaaa: 5}}}
    }
    lens = Lens.key?(:a) |> Lens.key?(:b) |> Lens.key?(:c) |> Lens.key?(:d)

    Deeply.put(map, lens, :NEW) |> dbg

    IO.puts("======")

    lens = Lens.tracing_key!(:a) |> Lens.tracing_keys([:aa, :bb])
    |> Lens.tracing_keys?([:aaa, :bbb]) |> Lens.tracing_keys?([:aaaa, :bbbb])
    Deeply.get_all(map, lens)

    # # map = %{a: %{bb: %{c: 1, d: 2},
    # #              cc: %{c: 3}}}
    # # lens = Lens.key(:a) |> Lens.keys?([:bb, :cc]) |> Lens.key!(:c) # |> Lens.map_values


    # # lens = Lens.tracing_key(:a) |> Lens.tracing_keys?([:bb, :cc]) |> Lens.tracing_key!(:c) # |> Lens.tracing_map_values
    # # Deeply.get_all(map, lens) |> dbg


  end

end
