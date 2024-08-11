defmodule Lens2.MakersTest do
  use Lens2.Case
  use TypedStruct

  doctest Lens2.Makers

  defmodule Private do
    use Lens2

    defmakerp a_lens, do: Lens.key(:a)
    deflensp b_lens, do: Lens.key(:b)

    def do_a(map), do: Deeply.get_all(map, a_lens())
    def do_b(map), do: Deeply.get_all(map, b_lens())
  end

  # Uncomment to see that they really truly were defined with `defp`
  # test "check privacy" do
  #   Private.a_lens
  #   Private.b_lens
  # end

  test "the private lenses work" do
    assert Private.do_a(%{a: 1}) == [1]
    assert Private.do_b(%{b: 2}) == [2]
  end
end
