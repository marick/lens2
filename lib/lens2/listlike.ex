defmodule Lens2.Listlike do
  use Lens2.Deflens
  alias Lens2.Helpers.DefOps
  alias Lens2.{Combine}
  alias Lens2.Compatible.Operations

  @type lens :: Access.access_fun

  @doc ~S"""
  Returns a lens that focuses before the first element of a list. It will always return a nil when accessing, but can
  be used to prepend elements.

  FIXDOC

      iex> Lens2.front |> Lens2.one!([:a, :b, :c])
      nil
      iex> Lens2.front |> Lens2.map([:a, :b, :c], fn nil -> :d end)
      [:d, :a, :b, :c]
  """
  @spec front :: lens
  deflens front, do: before(0)

  @doc ~S"""
  Returns a lens that focuses after the last element of a list. It will always return a nil when accessing, but can
  be used to append elements.

  FIXDOC
      iex> Lens2.back |> Lens2.one!([:a, :b, :c])
      nil
      iex> Lens2.back |> Lens2.map([:a, :b, :c], fn nil -> :d end)
      [:a, :b, :c, :d]
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

  FIXDOC
      iex> Lens2.before(2) |> Lens2.one!([:a, :b, :c])
      nil
      iex> Lens2.before(2) |> Lens2.map([:a, :b, :c], fn nil -> :d end)
      [:a, :b, :d, :c]
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
  FIXDOC

      iex> Lens2.behind(1) |> Lens2.one!([:a, :b, :c])
      nil
      iex> Lens2.behind(1) |> Lens2.map([:a, :b, :c], fn nil -> :d end)
      [:a, :b, :d, :c]
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

      iex> Lens2.at(2) |> Lens2.one!({:a, :b, :c})
      :c
      iex> Lens2.at(1) |> Lens2.map([:a, :b, :c], fn :b -> :d end)
      [:a, :d, :c]
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

      iex> Lens2.indices([0, 2]) |> Lens2.to_list([:a, :b, :c])
      [:a, :c]
      iex> Lens2.indices([0, 2]) |> Lens2.map([1, 2, 3], &(&1 + 1))
      [2, 2, 4]
  """
  @spec indices([non_neg_integer]) :: lens
  deflens indices(indices), do: indices |> Enum.map(&index/1) |> Combine.multiple




end
