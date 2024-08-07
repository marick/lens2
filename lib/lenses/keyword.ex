alias Lens2.Lenses

defmodule Lenses.Keyword do
  @moduledoc """
  Lenses that support duplicate keys in keyword lists.

  The lens makers in `Lens2.Lenses.Keyed` only operate on the first
  matching key. These operate on all values, as in the distinction
  between `Keyword.get/3` and `Keyword.get_values/2`.

  The `Deeply.update` and `Deeply.put` functions produce keyword
  lists. (Lenses from `Lens2.Lenses.Keyed` produce maps.)

  """

  use Lens2
  import Lens2.Helpers.Assert

  @doc ~S"""
  Returns a lens that points to all values of `key`.

      iex> kw = [a: 1, b: 2, a: 3]
      iex> lens = Lens.Keyword.key?(:a)
      iex> Deeply.get_all(kw, lens)
      [1, 3]
      iex> Deeply.update(kw, lens, & &1 * 1111)
      [a: 1111, b: 2, a: 3333]

  Note that a missing key cannot be added:

      iex> Deeply.put([a: 1, b: 2], Lens.Keyword.key?(:missing), :NEW)
      [a: 1, b: 2]

  If you want to add key/value pairs, consider lens makers like
  `Lens2.Lenses.Indexed.front/0`:

      iex> Deeply.put([a: 1, b: 2], Lens.front, {:missing, :NEW})
      [missing: :NEW, a: 1, b: 2]
  """

  @spec key?(atom) :: Lens2.lens
  defmaker key?(key) do
    assert_atom(key)
    Lens.all |> Lens.filter(fn {k, _v} -> k == key end) |> Lens.at(1)
  end


  @doc ~S"""
  Returns a lens that points to the values of the given keys. Missing
  keys are to be ignored.

      iex> kw = [a: 1, b: 2, a: 3]
      iex> lens = Lens.Keyword.keys?([:a, :missing])
      iex> Deeply.get_all(kw, lens)
      [1, 3]
      iex> Deeply.update(kw, lens, & &1 * 1111)
      [a: 1111, b: 2, a: 3333]

  """
  @spec keys?(list(atom)) :: Lens2.lens
  defmaker keys?(keys) do
    assert_list(keys)
    keys |> Enum.map(&key?/1) |> Lens.multiple
  end

  @doc ~S"""
  Returns a lens that points to all values of a keyword list.


      iex> kw = [a: 1, b: 2, a: 3]
      iex> lens = Lens.Keyword.values
      iex> Deeply.get_all(kw, lens)
      [1, 2, 3]
      iex> Deeply.update(kw, lens, & &1 * 1111)
      [a: 1111, b: 2222, a: 3333]
  """
  @spec values :: Lens2.lens
  defmaker values do
    Lens.all |> Lens.at(1)
  end
end
