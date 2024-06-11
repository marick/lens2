defmodule Lens2.Lenses.Enum do
  @moduledoc """
  Lenses that work on miscellaneous data structures. Ones that don't fit elsewhere.


  """
  use Lens2.Deflens
  alias Lens2.Deeply

  @doc ~S"""
  Returns a lens that focuses on all the values in an enumerable.

  Note the resulting lens works on lists but not tuples, and on maps but not structs.

  Does work with updates but produces a list from any enumerable by default:

  See [into](#into/2) on how to rectify this.
  """
  @spec all :: Lens2.lens
  deflens_raw all do
    fn data, fun ->
      {res, updated} =
        Enum.reduce(data, {[], []}, fn item, {res, updated} ->
          {res_item, updated_item} = fun.(item)
          {[res_item | res], [updated_item | updated]}
        end)

      {Enum.reverse(res), Enum.reverse(updated)}
    end
  end

  @doc ~S"""
  Returns a lens that does not change the focus of of the given lens, but puts the results into the given collectable
  when updating.

  Notice that collectable composes in a somewhat surprising way, for example:

  To prevent this, avoid using `|>` with `into`:

  """
  @spec into(Lens2.lens, Collectable.t()) :: Lens2.lens
  deflens_raw into(lens, collectable) do
    fn data, fun ->
      {res, updated} = Deeply.get_and_update(data, lens, fun)
      {res, Enum.into(updated, collectable)}
    end
  end

end
