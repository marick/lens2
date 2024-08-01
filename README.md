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

