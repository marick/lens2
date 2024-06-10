# Working on multiple levels at once

`Lens2.Lenses.Combine.recur/1` can be used for recursive data
structures like collecting all the numbers (or operators) in an
arithmetic expression. I'll start with a simpler example, then do the
arithmetic example, then explain how `recur` works.

## Consistent levels

```elixir
    tree = %{value: 1,
             deeper: %{value: 2,
                       deeper: %{value: 3,
                                 deeper: %{}
    }}}
```

Every node has either the two keys or neither.

Rather than jump into the lens, here's a simple recursive implementation of `to_list`:

```elixir
  def to_list(tree) do
    case tree do
      %{value: value, deeper: deeper} ->
        [value | values_to_list(deeper)]
      %{} ->
        []
    end
```

This would not be a good implementation for a really deep data
structure because it's not tail-recursive. (In a tree 1000 levels
deep, 100 partially finished invocations of `values_to_list` would be
stacked up above the one that finally returns `[]`.) But really deep
structures deserve custom code. For other ones, this textbook
recursive implementation is fine. Even better is having a lens that
does the recursion for you.

That turns out to be easy:










If we want to
harvest or change all the values, we have to do two things:

1. Point at the value of `:value`, and then:
2. Descend through `:deeper` and do the whole thing over again.

The 

## Alternative leaves

## How `recur` works




