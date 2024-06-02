defmodule Lens2.Lenses.Listlike do
  @moduledoc """
  Lenses that work on `Enumerable`s and `Tuple`s.

  Note that, while `Map`s and `Keyword` lists are enumerables, you probably want the
  lenses in `MapLike`.
  """
  use Lens2.Deflens
  alias Lens2.Helpers.DefOps
  alias Lens2.Lenses.Combine
  alias Lens2.Compatible.Operations

  @type lens :: Access.access_fun

  @doc ~S"""
  Returns a lens that focuses before the first element of a list. It will always return a nil when accessing, but can
  be used to prepend elements.

  """
  @spec front :: lens
  deflens front, do: before(0)

  @doc ~S"""
  Returns a lens that focuses after the last element of a list. It will always return a nil when accessing, but can
  be used to append elements.

  """
  @spec back :: lens
  deflens_raw back do
    fn data, fun ->
      data |> Enum.count() |> behind |> Operations.get_and_map(data, fun)
    end
  end

  @doc ~S"""
  Returns a lens that focuses between a given index and the previous one in a list. It will always return a nil when
  accessing, but can be used to insert elements.

  """
  @spec before(non_neg_integer) :: lens
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
  @spec behind(non_neg_integer) :: lens
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
  @spec at(non_neg_integer) :: lens
  deflens_raw at(index) do
    fn data, fun ->
      {res, updated} = fun.(DefOps.at(data, index))
      {[res], DefOps.put_at(data, index, updated)}
    end
  end

  @doc ~S"""
  An alias for `at`.
  """
  @spec index(non_neg_integer) :: lens
  deflens index(index), do: at(index)




  @doc ~S"""
  Returns a lens that focuses on all of the supplied indices.

  """
  @spec indices([non_neg_integer]) :: lens
  deflens indices(indices), do: indices |> Enum.map(&index/1) |> Combine.multiple
end
