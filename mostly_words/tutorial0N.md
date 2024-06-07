## Missing values

There's another difference, though, which has to do with the handling of missing values. Consider fetching the value of keys `:a` and `:missing`:

```elixir
iex> Map.take(map, [:a, :missing])
%{a: 1}

iex(31)> Deeply.to_list(map, Lens.keys([:a, :missing]))
[1, nil]
```

This lens follows the Elixir convention of using `nil` to mean both a
specific existing value (`nil`) *and* a signal that there *is* no such
value.








