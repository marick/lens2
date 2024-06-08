defmodule Lens2.Lenses.Basic do
  @moduledoc """
  Lenses that work on miscellaneous data structures. Ones that don't fit elsewhere.


  """
  use Lens2.Deflens
  alias Lens2.Compatible.Operations

  @type lens :: Access.access_fun

  @doc ~S"""
  Returns a lens that yields the entirety of the data currently under focus.

  """
  @spec root :: lens
  deflens_raw root do
    fn data, fun ->
      {res, updated} = fun.(data)
      {[res], updated}
    end
  end


  @doc ~S"""
  Returns a lens that does not focus on any part of the data.

  """
  @spec empty :: lens
  deflens_raw empty, do: fn data, _fun -> {[], data} end


  @doc ~S"""
  Returns a lens that ignores the data and always focuses on the given value.

  """
  @spec const(any) :: lens
  deflens_raw const(value) do
    fn _data, fun ->
      {res, updated} = fun.(value)
      {[res], updated}
    end
  end

  @doc ~S"""
  Returns a lens that focuses on all the values in an enumerable.

  Note the resulting lens works on lists but not tuples, and on maps but not structs.

  Does work with updates but produces a list from any enumerable by default:

  See [into](#into/2) on how to rectify this.
  """
  @spec all :: lens
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
  @spec into(lens, Collectable.t()) :: lens
  deflens_raw into(lens, collectable) do
    fn data, fun ->
      {res, updated} = Operations.get_and_map(lens, data, fun)
      {res, Enum.into(updated, collectable)}
    end
  end

  @doc ~S"""
  Returns a lens that focuses on a subset of elements focused on by the given lens that satisfy the given condition.

  """
  @spec filter(lens, (any -> boolean)) :: lens
  def filter(predicate), do: root() |> filter(predicate)

  deflens_raw filter(lens, predicate) do
    fn data, fun ->
      {res, changed} =
        Operations.get_and_map(lens, data, fn item ->
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
  @spec reject(lens, (any -> boolean)) :: lens
  def reject(lens, predicate), do: filter(lens, &(not predicate.(&1)))




end
