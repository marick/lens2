defmodule Lens2.TracingTest do
  use Lens2.Case

  test "trace" do

    # alias Lens2.Lenses.Keyed

    # x = quote do
    #       Keyed.tracing_keys([:a])
    # end

    # Macro.expand_once(x, __ENV__) |> Macro.to_string |> IO.puts

#    lens = Lens.tracing_keys([:a]) |> Lens.tracing_key?(:b)
   lens = Lens.tracing_key(:a) |> Lens.tracing_keys?([:b])
    #    lens = Lens.tracing_key(:a)
    # lens = Lens.tracing_keys([:a])
    Deeply.to_list(%{a: %{b: 1}}, lens) |> dbg
#    assert Deeply.to_list(%{a: %{b: 1}}, lens) == [1]

    # assert Deeply.put(%{a: %{b: 1}}, lens, :NEW) == %{a: %{b: :NEW}}

    # Deeply.get_and_update(%{a: %{b: 1}}, lens, fn value ->
    #   {value, value * 1111}
    # end)

  end

end
