defmodule Lens2.Lenses.Indexed do
  @moduledoc """
  Lenses meaningful for `List` and `Tuple` containers.


  The update operations (`Lens2.Deeply.put/3`,
  `Lens2.Deeply.update/3`) can take any sort of `Enumerable`, but they
  will always produce a list. That makes sense. Consider `at/1`, which
  points to an element at an index. What should be the result of
  putting 5 as the second item of the range `0..5`? You can't create a
  non-sequential range, so a `List` seems like the reasonable choice:

      iex> Deeply.put(0..5, Lens.at(2), 838383)
      [0, 1, 838383, 3, 4, 5]


  """
  use Lens2.Deflens
  alias Lens2.Helpers.DefOps
  alias Lens2.Lenses.Combine
  alias Lens2.Compatible.Operations

  @doc ~S"""
  Returns a lens that focuses before the first element of a list. It will always return a nil when accessing, but can
  be used to prepend elements.

  """
  @spec front :: Lens2.lens
  deflens front, do: before(0)

  @doc ~S"""
  Returns a lens that focuses after the last element of a list. It will always return a nil when accessing, but can
  be used to append elements.

  """
  @spec back :: Lens2.lens
  deflens_raw back do
    fn data, fun ->
      data |> Enum.count() |> behind |> Operations.get_and_map(data, fun)
    end
  end

  @doc ~S"""
  Returns a lens that focuses between a given index and the previous one in a list. It will always return a nil when
  accessing, but can be used to insert elements.

  """
  @spec before(non_neg_integer) :: Lens2.lens
  deflens_raw before(index) do
    fn data, fun ->
      {res, item} = fun.(nil)
      {init, tail} = Enum.split(data, index)
      {[res], init ++ [item] ++ tail}
    end
  end

  @doc ~S"""
  Returns a lens that focuses between a given index and the next one in a list. It will always return a nil when
  accessing, but can be used to insert elements.

  """
  @spec behind(non_neg_integer) :: Lens2.lens
  deflens_raw behind(index) do
    fn data, fun ->
      {res, item} = fun.(nil)
      {init, tail} = Enum.split(data, index + 1)
      {[res], init ++ [item] ++ tail}
    end
  end

  @doc ~S"""
  Returns a lens that focuses on the n-th element of a list or tuple.

  """
  @spec at(non_neg_integer) :: Lens2.lens
  deflens_raw at(index) do
    fn data, fun ->
      {res, updated} = fun.(DefOps.at(data, index))
      {[res], DefOps.put_at(data, index, updated)}
    end
  end

  @doc ~S"""
  An alias for `at`.
  """
  @spec index(non_neg_integer) :: Lens2.lens
  deflens index(index), do: at(index)




  @doc ~S"""
  Returns a lens that focuses on all of the supplied indices.

  """
  @spec indices([non_neg_integer]) :: Lens2.lens
  deflens indices(indices), do: indices |> Enum.map(&index/1) |> Combine.multiple
end
