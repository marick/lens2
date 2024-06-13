defmodule Lens2.Lenses.Filter do
  @moduledoc """
  Lenses that reduce a set of pointers into a smaller set of pointers.

  Consider a use of, say, `Enum.filter`:

      iex> [-2, -1, 0, 1, 2] |> Enum.filter(& &1 > 0)
      [1, 2]


  Functions in this module convert such a function into a lens that
  will (eventually) apply the same filter to already-selected elements
  of a container.

      iex> lens = Lens.keys([:a, :c]) |> Lens.filter(& &1 > 0)
      iex> container = %{a: 1, b: 9, c: -1}
      iex> Deeply.to_list(container, lens)
      [1]
      iex> Deeply.update(container, lens, & -1111 * &1)
      %{a: -1111, b: 9, c: -1}


  """
  use Lens2.Deflens
  alias Lens2.Deeply
  alias Lens2.Lenses.Combine

  @doc ~S"""
  Returns a lens that focuses on a subset of elements focused on by the given lens that satisfy the given condition.

  """
  @spec filter(Lens2.lens, (any -> boolean)) :: Lens2.lens


  # I can't imagine the use case for the following.
  def filter(predicate), do: Combine.root() |> filter(predicate)

  deflens_raw filter(lens, predicate) do
    fn data, fun ->
      {res, changed} =
        Deeply.get_and_update(data, lens, fn item ->
          if predicate.(item) do
            {res, changed} = fun.(item)
            {[res], changed}
          else
            {[], item}
          end
        end)

      {Enum.concat(res), changed}
    end
  end

  # TODO: why is reject's definition not parallel to filter, with the one-arity case?

  @doc ~S"""
  Returns a lens that focuses on a subset of elements focused on by the given lens that don't satisfy the given
  condition.

  """
  @spec reject(Lens2.lens, (any -> boolean)) :: Lens2.lens
  def reject(lens, predicate), do: filter(lens, &(not predicate.(&1)))


end
