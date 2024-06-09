defmodule Lens2.Lenses.IndexedTest do
  use ExUnit.Case
  use Lens2
  use FlowAssertions

  doctest Lens2.Lenses.Indexed

  test "way negative for Lens.at" do
    lens = Lens.at(-30)
    assert Deeply.to_list([0, 1, 2], lens) == [nil]

    assert Deeply.put([0, 1, 2], lens, :NEW) == [0, 1, 2]
  end

end
