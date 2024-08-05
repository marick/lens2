# Non-list enumerables

`Lens2.Lenses.Enum.all/0` is the building block for lens pipelines
that work with non-list `Enumerable` containers. 

To start the explanation, here it is applied to a keyword list:

    iex> use Lens2
    iex> Deeply.get_all([a: 1, b: 2], Lens.all)
    [a: 1, b: 2]
    
Since a keyword list is just a list of key/value tuples, the output looks the same as the input. 

Here's the same example for a map:

    iex> Deeply.get_all(%{a: 1, b: 2}, Lens.all)
    [a: 1, b: 2]
    
Again, we get key-value pairs. To make that explicit:

    iex> Deeply.get_all(%{1 => "1", 2 => "2"}, Lens.all)
    [{1, "1"}, {2, "2"}]

This is the usual Elixir behavior when working with maps as enumerables:

    iex> %{1 => "1", 2 => "2"} |> Enum.map(& &1)
    [{1, "1"}, {2, "2"}]

We can pipe lens makers together to work on elements. Here's an
implementation of `Lens2.Lenses.Keyed.map_values/0` that uses `all` and `Lens2.Lenses.Indexed.at/1`:

    iex> Deeply.get_all(%{a: 1, b: 2}, Lens.all |> Lens.at(1))
    [1, 2]

## Update

That's not *quite* `map_values`, though, because of `update`:

    
    iex> Deeply.update(%{a: 1, b: 2}, Lens.map_values, & &1 * 111)
    %{a: 111, b: 222}                 ^^^^^^^^^^^^^^^
    iex> Deeply.update(%{a: 1, b: 2}, Lens.all |> Lens.at(1), & &1 * 111)
    [a: 111, b: 222]                  ^^^^^^^^^^^^^^^^^^^^^^

`all` will always produce a `List` on update. The solution is to add
another lens that "pours" the list into a `Collectable` in a manner
analogous to `Enum.into/2`. Lens 1 provided `Lens.into` for that:

    iex> map_values = Lens.all |> Lens.at(1) |> Lens.into(%{})
    iex> Deeply.update(%{a: 1, b: 2}, map_values, & &1 * 111)
    %{a: 111, b: 222}

That exists in Lens 2 as well. Experience shows, though, that `Lens2.Lenses.Enum.into/2` is
error-prone. A pipeline like the above is a special case that's easy
to mis-generalize from. After writing a whole lot of text explaining
the issue (see [here](Lens2.Lenses.Enum.html#into/2) *and*
[here](draft_into.html)), I realized that I ought to [make the error harder to make](https://en.wikipedia.org/wiki/Poka-yoke). Hence `Lens2.Lenses.Enum.update_into/2`, which forces
you to make explicit which sub-pipeline produces the value to pour:

    iex> map_values = Lens.update_into(%{}, Lens.all |> Lens.at(1))
                      ^^^^^^^^^^^^^^^^
    iex> Deeply.update(%{a: 1, b: 2}, map_values, & &1 * 111)
    %{a: 111, b: 222}

This matters when you're updating a non-list `Enumerable` nested within a container, like this one:

    iex> container = [%{}, %{a: 1, b: 2}, %{}]
                           ^^^^^^^^^^^^^
    iex> lens = Lens.at(1) |> Lens.update_into(%{}, map_values)
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    iex> Deeply.update(container, lens, & &1 * 1111)
    [%{}, %{a: 1111, b: 2222}, %{}]
