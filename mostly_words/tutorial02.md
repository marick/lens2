# Pointing into nested containers

Lenses claim to fame is the ability to descend through nested data
structures in a variety of ways, for a variety of structures. This
page is about how that's done.


## Composing lens makers

Lens-creating functions can be combined using the pipe (`|>`)
function.

Suppose I've `use`d `Lens2` and so can refer to lens-maker functions
with `Lens`. Here, again, are pictures showing the pointed-at values
from applying, respectively, `Lens.key(:c)` and `Lens.key([:a, :e])`
to two copies of the same five-element map.


![Alt-text is coming](pics/tutorial02-two-maps.png)

However, let's suppose the second map is actually embedded within the first, as the value of the key `:c`:


![Alt-text is coming](pics/tutorial02-blended-maps.png)

We want the pointers into that nested map, specifically at the values of the `:a` and `:e` keys:


![Alt-text is coming](pics/tutorial02-nested-pointers.png)

That's easy to do by composing the Lens-making functions:


```elixir
iex>  lens = Lens.key(:c) |> Lens.keys([:a, :e])
#Function<13.52599976/3 in Lens2.Lenses.Combine.seq/2>
```

Let's see the new composed lens at work.

```elixir
iex>  map = %{a: 1, b: 2, c: 3, d: 4, e: 5}
%{c: 3, a: 1, d: 4, e: 5, b: 2}
iex>  nested = %{map | c: map}
%{c: %{c: 3, a: 1, d: 4, e: 5, b: 2}, a: 1, d: 4, e: 5, b: 2}

iex>  Deeply.get_all(nested, lens)
[1, 5]
iex>  Deeply.put(nested, lens, :NEW)
%{c: %{c: 3, a: :NEW, d: 4, e: :NEW, b: 2}, a: 1, d: 4, e: 5, b: 2}
                ^^^^           ^^^^
```

## Another example: filtering pointers

Lenses don't have to descend into a data structure. Some lenses can
remove pointers. For example, consider this map from numbers to names:

     iex> map = %{1 => "one", 2 => "two", 3 => "three"}
     
`Lens.map_values` will transform a pointer to the map into pointers to the values:

     iex> Deeply.get_all(map, Lens.map_values)
     ["one", "two", "three"]

We can use `Lens.filter` to make a lens that retains only pointers to three-character names:

     iex> lens = Lens.map_values |> Lens.filter(& String.length(&1) == 3)
     
... and use it to boost those names' visibility:

    iex> Deeply.update(map, lens, & String.upcase(&1))
    %{1 => "ONE", 2 => "TWO", 3 => "three"}


## How pipelining works

The function we call as `Lens.map_values` takes no arguments. How,
then, does this pipeline work?

    iex> lens = Lens.map_values() |> Lens.keys([:a, :b])
    
... given that's just syntactic sugar for the following?

    iex> lens = Lens.keys(Lens.map_values(), [:a, :b])
    
What's happening is that every predefined lens maker comes in two versions:

    @spec keys(any) :: Lens2.lens
    def keys(key_list), do: ...
    
    @spec keys(Lens2.lens, any) :: Lens2.lens
    def keys(previous_lens, key_list), do: ...
    
The second just doesn't appear in documentation.

If you're like me, that can trip you up. A few times I've had a lens defined for a particular
data structure, like this one for a two-level map:

    iex> two_level_lens = Lens.key(:a) |> Lens.key(:aa)
    ...
    
... and then I have a list of such maps and want a lens that will pick
out all the `:aa` values of all the maps in the list:

    iex> Deeply.get_all(list_of_maps, a_bigger_lens)
    [1, 2]
    
The question is: how to easily make `a_bigger_lens`? Because I know
that `Lens2.Lenses.Enum.all` will give me all elements of a list, a simple
composition should do it:

    iex> a_bigger_lens = Lens.all |> two_level_lens.()
    ** (BadArityError) #Function<19.51288540/3 in Lens2.Lenses.Combine.seq/2>
    with arity 3 called with 1 argument
    (#Function<1.73076862/3 in Lens2.Lenses.Enum.all/0>)

Here I'm passing a lens (constructed by the lens maker `Lens.all`) to
another *lens*, not to a lens maker.

You have been warned. 

The way to compose with an existing lens is to use `Lens2.Lenses.Combine.seq/2`:

    iex> a_bigger_lens = Lens.all |> Lens.seq(two_level_lens)
    # or, without the pipeline:
    iex> a_bigger_lens = Lens.seq(Lens.all, two_level_lens)

In fact, the definition of the hidden version of, for example, `Lens.keys` uses `Lens.seq/2`:

    def keys(previous_lens, key_list) do
      Lens.seq(previous_lens, keys(key_list))
    end


## Defining a lens maker






    


It's easy to forget that we've been talking about two types of
functions: lenses (which are functions) and lens *makers* (which are
functions that make lenses). It's not often necessary to be careful
about the distinction, but sometimes it is.

Suppose you're comfortable with composed lenses like this one:

   



lens |> lens2 

Lens.key(:a) |> Lens.keys([:a, :b])


Lens.keys(Lens.key(:a), [:a, :b])

lens2.(lens1)





feeding the lens function into another lens function, when that function expects a container.


## Naming composed lens makers



BREAK



I lied by omission about the example map. I didn't mention that it's
more accurate to consider the map a container of *tuples*, each of
which contains two values: the first element (key) and the second
(value).

To see this, you can use `Lens.all` to get the tuples:

```elixir
iex>    map = %{a: 1, b: 2, c: 3, d: 4, e: 5}
iex>    Deeply.get_all(map, Lens.all)
[c: 3, a: 1, d: 4, e: 5, b: 2]
```

We've gotten back a list of tuples, which is the definition of a
`Keyword` list, so IEX (via the `Inspect` protocol) doesn't show the
tuples. To make the output clearer, let's use a map with non-atom
keys:

```elixir
iex>  map = %{[:a] => 1, [:b] => 2}
%{[:a] => 1, [:b] => 2}
```

Now the `Inspect` protocol highlights the tuples:

```elixir
iex>  Deeply.get_all(map, Lens.all)
[{[:a], 1}, {[:b], 2}]
```

As containers, tuples have lenses that apply to them. For example,
`Lens2.Lenses.Indexed.at/1` (aliased to `Len2.at`) will take the nth element of a `Tuple` (as well
as of any `Enumerable`):

```elixir
iex>  Deeply.get_only({:key, :value}, Lens.at(1))
:value
```

What this means is that it seems like `Lens2.Keyed.map_values/0` be defined by the
composition of lenses:

```elixir
iex(9)>  Deeply.get_all(map, Lens.all |> Lens.at(1))
[1, 2]
```

But not quite, because `Deeply.put` (or `put_in/3`) produces an odd result:

```elixir
iex>  put_in(map, [Lens.all |> Lens.at(1)], :NEW)
[{[:a], :NEW}, {[:b], :NEW}]
```

Where's the map? What's happening here? 

Consider how you might write your own code to `put` all the values of a map. 
First, you'd iterate over the elements of the map. I'll use `for/1`:

```elixir
for {key, value} <- map do
  # ...
end
```

Within the body of the `for`, you'd set the value of the tuple's second element:

```elixir
for {key, _overwritten} <- map do
  {key, :NEW}
end
```

That produces this:

```
[{[:a], :NEW}, {[:b], :NEW}]
```

The problem is there's no code to reconstitute from the list of...........
tuples. `for/1` has a way to handle that, the `:into` clause, which builds on `Enum.into/2`:

```elixir
for {key, _overwritten} <- map, into: %{} do
  {key, :NEW}                   ^^^^^^^^^
end

# returns:
%{[:a] => :NEW, [:b] => :NEW}
```

Reconstituting the expected map requires a similar step. The lens version of `Enum.into` is `Lens2.Lenses.Enum.into/2`, and the 



Working with nested containers is inherently a recursive
operation. `Lens.all` is the first level of recursion. When applied to
a `Map`, it produces tuples. These it passes to the second level,
which deals with individual tuples. But what is the `Lens.all` code to
do with the second level's return values? 


