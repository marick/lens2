alias Lens2.Tracing

defmodule Tracing.CasesTest do
  @moduledoc "Different kinds of odd lenses for tracing"
  use Lens2.Case

  @tag :skip
  test "no pipeline or fancy makers" do
    lens = Lens.tracing_key(:a)
    map =
      %{a: %{aa: %{aaa: 1}},
        b: %{aa: %{aaa: 2}}
      }

    Deeply.get_all(map, lens)
  end

  @tag :skip
  test "two-level pipeline" do
    # alias Lens2.Lenses.Combine
    lens = Lens.tracing_key(:a) |> Lens.tracing_key(:aa)

    map =
      %{a: %{aa: 1},
        b: %{aa: 2}
      }
    Deeply.get_all(map, lens) |> dbg
  end

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
  test "branching" do
    lens = Lens.tracing_keys([:a, :b]) |> Lens.tracing_keys([:aa, :bb]) |> Lens.tracing_keys([:aaa, :bbb])
    map =
      %{a: %{aa: %{aaa: 1, bbb: 2},
             bb: %{aaa: 3, bbb: 4}},
        b: %{aa: %{aaa: 5, bbb: 6},
             bb: %{aaa: 7, bbb: 8}}
      }

    Deeply.get_all(map, lens) |> dbg
  end


  def i(value), do: {value, inspect(value)}


  @tag :skip
  test "three-level pipeline" do
    # alias Lens2.Lenses.Combine
    lens = Lens.tracing_key(:a) |> Lens.tracing_key(:aa) |> Lens.tracing_key(:aaa)
    map =
      %{a: %{aa: %{aaa: 1}},
        b: %{aa: %{aaa: 2}}
      }
    # Deeply.get_and_update(map, lens, &i/1) |> dbg
    Deeply.get_all(map, lens) |> dbg
  end

  @tag :skip
  test "a three-level pipeline manually expanded" do
    lens2 = Lens.tracing_seq(Lens.tracing_key(:a), Lens.tracing_seq(Lens.tracing_key(:aa), Lens.tracing_key(:aaa)))

    map =
      %{a: %{aa: %{aaa: 1}},
        b: %{aa: %{aaa: 2}}
      }
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


  @tag :skip
  test "match" do
    matcher = fn
      {:noreply, _} -> Lens.at(1)
      {:noreply, _, _} -> Lens.at(1)
      {:reply, _, _} -> Lens.at(2)
      _ -> Lens.empty
    end
    lens = Lens.tracing_all |> Lens.tracing_match(matcher) |> Lens.tracing_key?(:code)
    returns = [{:noreply, %{code: 1}},
               {:reply, :ok, %{code: 2}},
               {:stop, 5, %{code: :ignore}}]
    Deeply.get_all(returns, lens) |> dbg
  end

  @tag :skip
  test "repeatedly" do
    lens = Lens.tracing_repeatedly(Lens.tracing_key?(:below))
    tree = %{below:
               %{value: 1, below:
                             %{value: 2}}}
    Deeply.get_all(tree, lens) |> dbg
  end

  @tag :skip
  test "and_repeatedly" do
    nested = %{value: 1,
               below: %{value: 2,
                        below: %{value: 3}}}
    values = Lens.tracing_and_repeatedly(Lens.tracing_key?(:below)) |> Lens.tracing_key(:value)
    Deeply.get_all(nested, values) |> Enum.sort |> dbg
  end

  @tag :skip
  test "context" do
    map_0 = %{a: [0, :t1, 2], name: "n0"}
    map_1 = %{a: [4, :t5, 6], name: "n1"}
    map_list = [map_0, map_1]

    into_map = Lens.tracing_key(:a) |> Lens.tracing_at(1)
    lens = Lens.tracing_at(0) |> Lens.tracing_context(into_map)

    Deeply.get_all(map_list, lens) |> dbg
  end

  @tag :skip
  test "nested context" do
    map_0 = %{a: [0, :t1, 2], name: "n0"}
    map_1 = %{a: [4, :t5, 6], name: "n1"}
    map_list = [map_0, map_1]

    lens = Lens.tracing_at(0) |> Lens.tracing_context(Lens.tracing_key(:a) |> Lens.tracing_context(Lens.tracing_at(1)))

    Deeply.get_all(map_list, lens) |> dbg
  end

  @tag :skip
  test "either" do
    lens = Lens.tracing_key?(:a) |> Lens.tracing_either(Lens.tracing_key?(:b))
    Deeply.get_only(%{a: 1}, lens) |> dbg
    Deeply.get_only(%{b: 2}, lens) |> dbg
  end

end
