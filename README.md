# Lens2

Lens2 is a library for working with values deep within a nested data structure.

For reasons why you might prefer it to Elixir's built-in
`Kernel.update_in` and friends, see
["Are lenses worth it to you?"](./mostly_words/are_lenses_for_you.md).

This library is descended from
[`Lens`](https://hexdocs.pm/lens/readme.html). To see why it's a
different project, see the
[rationale](./mostly_words/rationale.md). The short version is:

1. Lots of beginner and intermediate documentation.
2. An alternate API for operating on data with lenses (but the same API for creating lenses).
3. Operations that encourage (but do not require) information hiding.
4. Extra lenses and utility functions.


## Installation

The package can be installed by adding it to your list of dependencies in mix.exs:

    def deps do
      [
        {:lens2, "~> 0.2"},
      ]
    end



## TODO?

* Consider separating `:get` and `:get_and_update` cases.
    * some performance advantage for lists
    * Lens.at would work with Enumerables for getting.
    * Makes writing `def_raw_maker` style lenses more complicated.
* Make Deeply.pop?
* Fix the bug where `Deeply.update(["0", "1"], Lens.at(2), &Integer.parse/1)` calls the
  update function with a nil.
* Figure out if it's possible to make TypedStructLens work with this, or include a
  Lens2.TypedStructLens. 
* add defmakerp  