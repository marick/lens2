defmodule Lens2.Lenses.Indexed do
  @moduledoc """
  Lenses specific to lists, plus one that works on both lists and tuples.

  `Deeply.put/3` and `Deeply.update/3` produce lists when applied to
  lists, tuples when applied to tuples. As always, `Deeply.get_all/2`
  produces a list whether it operates on a list or a tuple.

  These lenses do *not* work on `Enumerables` (except for lists).
  """
  use Lens2.Makers
  alias Lens2.Helpers.DefOps
  alias Lens2.Lenses.Combine
  alias Lens2.Deeply

  @doc ~S"""
  Returns a lens that points to the n-th element of a list or tuple.

      iex>  lens = Lens.at(1)
      iex>  Deeply.get_only({00, 10, 20}, lens)
      10
      iex>  Deeply.update([00, 10, 20], lens, & &1 / 10)
      [00, 1.0, 20]
      iex>  Deeply.put({"my", "whiny", "tuple"}, lens, "favorite")
      {"my", "favorite", "tuple"}

  Indexes that are out of bounds are not allowed for tuples:
      iex>  tuple = {1, 2, 3}
      iex>  assert_raise(ArgumentError, fn ->
      ...>    Deeply.get_all(tuple, Lens.at(-1))
      ...>  end)
      iex>  assert_raise(ArgumentError, fn ->
      ...>    Deeply.get_all(tuple, Lens.at(3))
      ...>  end)

  Negative indices *are* allowed for lists and have their usual meaning (count backwards):

      iex> Deeply.put([0, 1, 2], Lens.at(-1), :NEW)
      [0, 1, :NEW]

  Indexes beyond the end of the list are ignored. (This behavior is
  consistent with `List.update_at/3` and `List.replace_at/3`.)

      iex> Deeply.put([0, 1, 2], Lens.at(3), :NEW)
      [0, 1, 2]

  """
  @spec at(non_neg_integer) :: Lens2.lens
  def_raw_maker at(index) do
    fn container, descender ->
      {gotten, updated} = descender.(DefOps.at(container, index))
      {[gotten], DefOps.put_at(container, index, updated)}
    end
  end


  @doc ~S"""
  An alias for `at`.
  """
  @spec index(non_neg_integer) :: Lens2.lens
  defmaker index(index), do: at(index)



  @doc ~S"""
  Returns a lens that points before the first element of a list.

  Since there is nothing there, `Deeply.get_only/2` returns `nil`:

       iex> Deeply.get_only([0, 1, 2], Lens.front)
       nil

  However, you can use it to prepend to the list:

       iex> Deeply.put([0, 1, 2], Lens.front, :NEW)
       [:NEW, 0, 1, 2]

  `front` raises an error if used on a tuple.
  """
  @spec front :: Lens2.lens
  defmaker front, do: before(0)

  @doc ~S"""
  Returns a lens that points after the last element of a list.

  Since there is nothing there, `Deeply.get_only/2` returns `nil`:

       iex> Deeply.get_only([0, 1, 2], Lens.back)
       nil

  However, you can use it to append to the list:

       iex> Deeply.put([0, 1, 2], Lens.back, :NEW)
       [0, 1, 2, :NEW]

  Raises an error if used on a tuple.
  """
  @spec back :: Lens2.lens
  def_raw_maker back do
    fn container, descender ->
      lens = behind(Enum.count(container))
      Deeply.get_and_update(container, lens, descender)
    end
  end

  @doc ~S"""
  Returns a lens that points before the given index, but after the prevous element.

  Since there is nothing there, `Deeply.get_only/2` returns `nil`:

       iex> Deeply.get_only([0, 1, 2], Lens.before(2))
       nil

  However, you can use it to insert into the list:

       iex> Deeply.put([0, 1, 2], Lens.before(2), :NEW)
       [0, 1, :NEW, 2]

  Raises an error if used on a tuple.
  """
  @spec before(non_neg_integer) :: Lens2.lens
  def_raw_maker before(index) do
    fn container, descender ->
      {gotten, item} = descender.(nil)
      {init, tail} = Enum.split(container, index)
      {[gotten], init ++ [item] ++ tail}
    end
  end

  @doc ~S"""
  Returns a lens that points after the given index, but before the next element.

  Since there is nothing there, `Deeply.get_only/2` returns `nil`:

       iex> Deeply.get_only([0, 1, 2], Lens.behind(0))
       nil

  However, you can use it to insert into the list:

       iex> Deeply.put([0, 1, 2], Lens.behind(0), :NEW)
       [0, :NEW, 1, 2]

  Raises an error if used on a tuple.
  """
  @spec behind(non_neg_integer) :: Lens2.lens
  def_raw_maker behind(index) do
    fn container, descender ->
      {gotten, item} = descender.(nil)
      {init, tail} = Enum.split(container, index + 1)
      {[gotten], init ++ [item] ++ tail}
    end
  end


  @doc ~S"""
  Returns a lens that points to all of the supplied indices.

       iex> lens = Lens.indices([0, 2])
       iex> Deeply.get_all([00, 10, 20, 30], lens)
       [00, 20]
       iex> Deeply.put([00, 10, 20, 30], lens, :NEW)
       [:NEW, 10, :NEW, 30]

  Alas, you cannot use a range to refer to an `Enum.slice/2` of indices.

  The handling of out-of-bounds elements is consistent with
  `at/1`. Negative indices count from the end, and out-of-range
  indices are ignored.

       iex> lens = Lens.indices([0, 2, -1, 40])
       iex> Deeply.get_all([00, 10, 20, 30], lens)
       [00, 20, 30, nil]
       iex> Deeply.put([00, 10, 20, 30], lens, :NEW)
       [:NEW, 10, :NEW, :NEW]

  Raises an error if used on a tuple.
  """
  @spec indices([non_neg_integer]) :: Lens2.lens
  defmaker indices(indices), do: indices |> Enum.map(&index/1) |> Combine.multiple
end
