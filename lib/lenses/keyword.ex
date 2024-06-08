alias Lens2.Lenses

defmodule Lenses.Keyword do
  @moduledoc """
  A variant of `Lens2.Lenses.Keyed` that applies to all matching `Keyword` keys.

  The `Kernel` "_in" functions apply only to the *first* matching key in a `Keyword` list:

      iex(3)> keylist = [a: 1, other: 2, a: 3]
      [a: 1, other: 2, a: 3]
      iex(4)> get_in(keylist, [:a])
      1
      iex(5)> put_in(keylist, [:a], 33)
      [a: 33, other: 2, a: 3]
      iex(6)> update_in(keylist, [:a], & &1 + 100)
      [a: 101, other: 2, a: 3]

  Lenses like `Lens2.Lenses.Keyed.key/1` mimic that behavior. (Indeed,
  they're implemented using it.) Given that the Joe Q. Average lens
  points at multiple places, that's counterintuitive. The lenses in this
  module will get, put, and update all matching keys.



  Problems: duplicate keys.

  Some set-type operations don't produce a keyword list.


  Deeply.put([a: 1], Lens.map_values, :NEW)
  %{NEW: 1}
  """


end
