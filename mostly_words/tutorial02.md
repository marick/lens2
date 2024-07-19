# Pointing into nested containers

Lenses claim to fame is the ability to descend through nested data
structures in a variety of ways, for a variety of structures. This
page is about how that's done.


## Composing lens makers

Lens-creating functions can be combined using the pipe (`|>`)
macro.

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


Normally, we think of a maker like `Lens.keys` as taking a single argument:

   iex> Lens.keys[:a, :b]
   
However, each lens maker has a two-argument version whose first
argument is a *lens* (not a lens *maker*). Therefore this pipeline:

    iex> lens = Lens.map_values() |> Lens.keys([:a, :b])
    
is just syntactic sugar for this:

    iex> lens = Lens.keys(Lens.map_values(), [:a, :b])
    
The second variant doesn't explicitly appear in API documentation
because the documentation for dozens of lens makers would just say
"This works the same as every other lens maker that takes a first
`lens` argument."

----

If you're like me, pipelining can trip you up. A few times I've had a lens defined for a particular
data structure, like this one for a two-level map:

    iex> two_level_lens = Lens.key(:a) |> Lens.key(:aa)
    
... and then I have a list of such maps and want a lens that will pick
out all the `:aa` values of all the maps in the list:

    iex> Deeply.get_all(list_of_maps, a_bigger_lens)
    [1, 2]
    
The question is: how to easily make `a_bigger_lens`? Because I know
that `Lens2.Lenses.Enum.all/0` will give me all elements of a list, a simple
composition should do it:

    iex> a_bigger_lens = Lens.all |> two_level_lens.()
    
But oops:

    ** (BadArityError) #Function<19.51288540/3 in Lens2.Lenses.Combine.seq/2>
    with arity 3 called with 1 argument
    (#Function<1.73076862/3 in Lens2.Lenses.Enum.all/0>)

Here I'm passing a lens (constructed by the lens maker `Lens.all`) to
another *lens*, not to a lens maker. That is, I'm passing the new lens to the *result* of `Lens.key(:a) |> Lens.key(:aa)`, not – as I sometimes sloppily assume – to `Lens.key/1`. 


The way to compose a new lens with an existing lens is to use `Lens2.Lenses.Combine.seq/2`:

    iex> a_bigger_lens = Lens.all |> Lens.seq(two_level_lens)
    # or, without the pipeline:
    iex> a_bigger_lens = Lens.seq(Lens.all, two_level_lens)

In fact, the definition of the hidden two-argument version of, for
example, `Lens2.Lenses.Keyed.keys/1` uses `Lens.seq/2`:

    def keys(previous_lens, key_list) do
      Lens.seq(previous_lens, keys(key_list))
    end


## Defining a lens maker

There are two ways to define a lens maker: coding one up from scratch,
or composing existing functions. The first way is rare and more
complicated, so I'll put that off and talk only about composition.

Suppose I frequently want to descend two levels into a nested map. Rather than write code like:

    Lens.key(:level1_key) |> Lens.key(:level2_key)
    
... all over the place, I prefer to write a function that does the busywork for me:

    MyLens.nested(:level1_key, :level2_key)
    
I could use a simple `def`:

    def nested(level1, level2),
        do: Lens.key(level1) |> Lens.key(level2)
    
That works for making an isolated lens, but it doesn't work for composition:

    Lens.at(0) |> MyLens.nested(:a, :b)
    
The problem is that I haven't defined the extra-argument version. I could do that easily enough:

    def nested(lens, level1, level2),
        do: Lens.seq(lens, nested(level1, level2)
        
However, that code will always always look the same, so there's a macro that defines both versions with a single definition:

    def_composed_maker nested(level1, level2),
        do: Lens.key(level1) |> Lens.key(level2)

(That's not the most gracious name, I admit. In the Lens 1 package,
it's called `deflens` and you can still use that name if you
prefer. But I'm hoping that the more cumbersome name will help you
keep in mind that you're not defining a *lens* but rather a lens
*maker*, thus saving you from some mistakes. Also: in Lens 1, you
define a lens maker from scratch with `deflens_raw`. I prefer
`def_maker/2`, despite the annoyance of having the more common case
having the longer name.)

You'll probably write a lot of lens makers, so there will be more
examples later. But first, it'll be worth taking a little time to walk
through what happens at runtime when you use a lens operation like
`Lens.get_all`.

