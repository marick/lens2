defmodule Lens2.ScratchTest do
  use Lens2.Case, async: true

  defmodule MyLenses do
    def_composed_maker as_mapset,
      do: Lens.all |> Lens.into(MapSet.new)
  end

  test "scratch" do
    #  Deeply.get_all(1..5, Lens.all |> Lens.into(MapSet.new)) |> dbg

    # Deeply.update(1..5, Lens.all |> Lens.into(MapSet.new), & &1*1111) |> dbg


    # lens = Lens.key!(:a) |> Lens.all |> Lens.into(MapSet.new)
    # Deeply.update(%{a: 1..5}, lens, & &1*1111) |> dbg

    # lens = (Lens.key!(:a) |> Lens.all) |> Lens.into(MapSet.new)
    # Deeply.update(%{a: 1..5}, lens, & &1*1111) |> dbg


    # l1 = Lens.all |> Lens.into(MapSet.new)
    # lens = Lens.seq(Lens.key!(:a), l1)
    # Deeply.update(%{a: 1..5}, lens, & &1*1111) |> dbg

    # # times = & &1 * &2
    # times = &*/2
    # plus = &+/2

    # 4 |> times.(2) |> plus.(3) |> dbg

    # (4 * 2) + 3 |> dbg
    # (4 * (2 + 3)) |> dbg


    # ast = quote do
    #         Lens.key!(:a) |> Lens.all |> Lens.into(MapSet.new)
    # end

    # Macro.expand(ast, __ENV__) |> Macro.to_string |> IO.puts

#    lens = Lens.seq(Lens.key!(:a), Lens.seq(Lens.all, Lens.into(MapSet.new)))

 #   lens = Lens.key(:a) |> MyLenses.as_mapset

#    Deeply.put(1..5, MyLenses.as_mapset, 555) |> dbg

#    Deeply.update(%{a: 1..5}, lens, & &1+1) |> dbg


    # lens = Lens.key(:a) |> Lens.update_into(MapSet.new, Lens.all)
    # assert Deeply.update(%{a: 1..5}, lens, & &1+1) == %{a: MapSet.new([2, 3, 4, 5, 6])}
    # assert Deeply.update(%{a: 1..5}, lens, & &1+1) == %{a: MapSet.new([2, 3, 4, 5, 6])}



#    Deeply.put(%{a: 1..5}, Lens.key(:a) |> Lens.all |> Lens.into(MapSet.new), 333) |> dbg
  end

end
