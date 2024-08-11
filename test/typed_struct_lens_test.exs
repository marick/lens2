defmodule Lens2.TypedStructLensTest do
  use Lens2.Case
  use TypedStruct

  defmodule Example do
    alias Lens2.TypedStructLens

    typedstruct do
      plugin TypedStructLens

      field :int, integer, default: 1000
      field :list, [atom], default: [:a]
    end

    use Lens2
    defmaker at(n), do: list() |> Lens.at(n)
  end


  test "using auto-generated lenses" do
    assert Deeply.get_all(%Example{}, Example.int) == [1000]
    assert Deeply.put(%Example{}, Example.list, [1]) == %Example{list: [1]}
    assert Deeply.get_all(%Example{}, Example.at(0)) == [:a]
  end
end
