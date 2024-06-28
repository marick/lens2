alias Lens2.Helpers.Tracing

defmodule Tracing.HardCasesTest do
  use Lens2.Case

  @tag :skip
  test "implicit seqs in pipeline" do
    lens = Lens.tracing_keys([:a, :b]) |> Lens.tracing_key(:aa) |> Lens.tracing_key(:aaa)
    map =
      %{a: %{aa: %{aaa: 1}},
        b: %{aa: %{aaa: 2}}
      }

    Deeply.get_all(map, lens) |> dbg
  end

  @tag :skip
  test "no pipeline or fancy makers" do
    lens = Lens.tracing_key(:a)
    map =
      %{a: %{aa: %{aaa: 1}},
        b: %{aa: %{aaa: 2}}
      }

    Deeply.get_all(map, lens)
  end

  def i(value), do: {value, inspect(value)}

  @tag :skip
  test "simple pipeline" do
    # alias Lens2.Lenses.Combine
    lens = Lens.tracing_key(:a) |> Lens.tracing_key(:aa) |> Lens.tracing_key(:aaa)


    lens2 = Lens.tracing_seq(Lens.tracing_key(:a), Lens.tracing_seq(Lens.tracing_key(:aa), Lens.tracing_key(:aaa)))

    map =
      %{a: %{aa: %{aaa: 1}},
        b: %{aa: %{aaa: 2}}
      }
    Deeply.get_and_update(map, lens, &i/1) |> dbg
    Deeply.get_and_update(map, lens2, &i/1) |> dbg
  end

  @tag :skip
  test "both" do
    lens = Lens.tracing_keys([:a, :b])
    |> Lens.tracing_both(Lens.tracing_key(:aa), Lens.tracing_key(:bb))
    |> Lens.tracing_key(:aaa)
    map =
      %{a: %{aa: %{aaa: 1},
             bb: %{aaa: 2}},
        b: %{aa: %{aaa: 3},
             bb: %{aaa: 4}}
      }

    Deeply.get_all(map, lens) |> dbg
  end



  @tag :skip
  test "explicit seq and into" do
    lens = Lens.tracing_seq(Lens.tracing_map_values,
                            Lens.tracing_all |> Lens.tracing_into(MapSet.new))
#    Deeply.get_and_update(%{a: 0..2, b: 3..4}, lens, &{&1, inspect(&1)})
#   Deeply.update(%{a: 0..2, b: 3..4}, lens, &inspect/1)
#    Deeply.put(%{a: 0..2, b: 3..4}, lens, :NEW) |> dbg
    Deeply.get_all(%{a: 0..2, b: 3..4}, lens) |> dbg
  end
end
