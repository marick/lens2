# How lenses work

> I really hate this damn machine.    
> I wish that they would sell it.    
> It never does quite what I want,     
> But only what I tell it.    
> – Traditional    

When using simple composed lenses like `Lens.key(:a) |>
Lens.keys([:aa, :bb])`, you don't have to understand what's happening
behind the scenes. The lens descends through key `:a`, then through
keys `:aa` and `:bb`, and either returns a list of values or an
updated complete container.

But sometimes – especially if you use some of the more unusual
combining lenses – you'll get surprised. I've reluctantly concluded
that the surest way to un-perplex yourself is to work through the
detailed steps of what's happening in the lens code. To do that, you
need to understand lenses well enough to write one from
scratch. That's what this section is about.

The implementation is somewhat tricksy, so I'll work my way up to full
complexity. I'll start with an implementation that works for
`Deeply.get`, then I'll expand it to work with `Deeply.update` and
related operations.  I'll finish with some explanations of why
particular compositions work as they do.

## Getting

Every lens function has three jobs, in order. I'll pile on details shortly,
but first a summary:

1. The function is given a container and must point to zero or more components
   of that container. For example, `Lens.at(1)` points at the second
   element of a list. `Lens.keys!([:a, :b])` points at two values in a
   map.
   
2. It must pass those 0, 1, or _n_ values to the next lens in a
   sequence of lenses. They're the containers *it* will work on.

   Importantly, a lens does not know its position in
   the sequence.  It may be the only element, the first element, or
   the last element. The code must work in all those cases.
   
3. It must collect the results into a list. A lens like that made by 
   `Lens.at(1)` may "know" it has a single element to return to the
   lens before it, but it has to wrap that in a list: the
   previous lens (if any) doesn't know what lens it's calling, so it
   has to rely on an "I'll get a list of zero or more values"
   convention.
   
A lens is a function that takes two arguments, a **container** and a
**descender**. So the `Lens2.Lenses.Indexed.at/1` maker returns such a
function:

     def at(index) do
       fn container, descender ->   # <<< this is the lens function
          ...
       end
     end

In the case of `Lens.at`, the value to be passed to the next lens is
gotten with `Enum.at/2`, as in this code:

     def at(index) do
       fn container, descender ->
         gotten = 
           Enum.at(container, index)   # Step 1 above
           |> descender.()             # Step 2 above
         [gotten]                      # Step 3 above
       end
     end

Note that the descender is *not* a lens. Lenses take two arguments,
whereas a descender takes only a single value. This often requires
slightly fancy footwork, which I'll show later. (But not more fancy
than what you're probably already used to with functions like `Enum.map/2`.)

Also, you can't descend into a container *forever*. Eventually, the
descender has to be something that stops the descent. It is the
`Deeply` functions that provide that final non-descending descender.
For example, `Lens2.Deeply.get_all/2` could be implemented like this:

    def get_all(container, lens) do
      getter = & &1    # Just return the leaf value
      lens.(container, getter)
    end


### Walkthrough

To see how `get_all` works with the lens from `at`, let's walk through this example: 

    get_all(["0", "1", "2"], at(1))`

(I'm leaving off the `Lens` qualifier because I'll be showing you some simplified functions. Their source and tests are [here](../test/mostly_words/tutorial/by_hand_get_test.exs).)

A neat thing about functional programming is
[*evaluation is substitution*](https://ocw.mit.edu/courses/6-001-structure-and-interpretation-of-computer-programs-spring-2005/182629e35d886325280dbc1bb4b5643c_lecture3webhand.pdf). Suppose you have code like this:

    a = 1
    b = 2
    a + double(b)
    
Wherever you see a use of a variable, you can substitute its
value. For the expression above, you'd get this:

    1 + double(2)
    
We can do more substitution because `double` is just as much a name as
`a` and `b` are. Although Elixir makes a distinction between functions
attached to modules, typically defined with `def`, and freestanding
functions defined with `fn ... end`, at base every kind of
function has a `fn` behind it. So we can replace `double` with its definition:

    1 + (fn arg -> arg + arg end).(2)
    
There's another name now: `arg`. But we know that `arg` is to be
bound to the value `2` when the function executes, so we can make
another substitution:

    1 + (2 + 2)
    
Since there's nothing left but a *primitive function* (`+/2`) and values, we
can just execute that primitive (twice) to get `5`.

(Note that the order of substitutions makes no difference. I could
have substituted for `double` as the first step and left `a` and `b` for later.)

------

Now, given `get_all(["0", "1", "2"], at(1))` and `get_all`'s definition:


    def get_all(container, lens) do
      getter = & &1    # Just return the leaf value
      lens.(container, getter)
    end

... we can substitute the given values for `container` and `lens`:

       getter = & &1
       at(1).(["0", "1", "2"], getter)
       
... or, after substituting the value of `getter`:

       at(1).(["0", "1", "2"], & &1)    # I'll refer back to this as "expression 1"

What's the value of `at(1)`? Here's `at`'s definition again, slightly
rearranged to not use `|>`:

     def at(index) do
       fn container, descender ->
         gotten = descender.(Enum.at(container, index))
         [gotten]
       end
     end

Substituting `1` into that definition, we get:

       fn container, descender -> 
         gotten = descender.(Enum.at(container, 1))
                                               ^^^
         [gotten]
       end

Let's replace `at(1)` in expression 1 with its expansion: 

       (fn container, descender -> 
         gotten = descender.(Enum.at(container, 1))
         [gotten]
       end).(["0", "1", "2"], & &1)


Let's substitute uses of `container` and `descender` with their actual values:
       
       gotten = (& &1).(Enum.at(["0", "1", "2"], 1))
                ^^^^^^          ^^^^^^^^^^^^^^^
       [gotten]
       
We could now substitute in
[the definition of `Enum.at`](https://github.com/elixir-lang/elixir/blob/v1.17.2/lib/elixir/lib/enum.ex#L478),
but that would be silly. We know the `Enum.at` expression will yield
`"1"`, so I'll skip the busywork and substitute that in:

       gotten = (fn value -> value end).("1")
       #                                 ^^^
       [gotten]

We can now substitute `"1"` for `value` in the `fn`, giving:

       gotten = "1"
                ^^^
       [gotten]
       
On the first line, pattern matching (binding) associates `"1"` with `gotten`, so we can make a substitution in the final line to get the return value:

       ["1"]
       
Zowie!

### Pipelines

Now let's see the "descender" argument earn that name.

Recall that `Lens.at(1) |> Lens.at(2)` is shorthand for this code:

    Lens.seq(Lens.at(1), Lens.at(2))
    
Since the result is a lens, `seq` has to have this form:

    def seq(lens1, lens2) do
      fn container, descender ->
        ...
      end
    end
    
In that definition, `container` is what's given to the *first* lens (to
produce a value to hand on down), whereas `descender` has to be given
to the *second* lens (where it will be used to pluck out the final
return value). So let's have some better variable names:

    def seq(lens1, lens2) do
      fn lens1_container, lens2_descender ->
         ^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^
        ...
      end
    end
    
That means the body of the `fn` will have to *make* a
`lens1_descender` to pass to `lens1`:

    def seq(lens1, lens2) do
      fn lens1_container, lens2_descender ->
        lens1_descender = fn ... end                # <<

        gotten = 
          lens1.(lens1_container, lens1_descender)  # <<

        ???? calculate the return value
      end
    end

As a descender, `lens1_descender` has to take a value extracted by
`lens1` and pass it along to `lens2`. It's not `seq`'s business how
`lens1` gets that value. I think that leaves the following as the only possible definition for 
`lens1_descender`:

    def seq(lens1, lens2) do
      fn lens1_container, lens2_descender ->
        lens1_descender =                              # <<
           fn lens2_container ->                       # <<
             lens2.(lens2_container, lens2_descender)  # <<
           end                                         # <<

        gotten = 
          lens1.(lens1_container, lens1_descender)
        ???? calculate the return value
      end
    end

In order to know how to fill in the rest of `seq` – what goes in the line marked
???? – I think it's worthwhile to walk through a specific example.
      
### Walkthrough

Here's the example:

    composed_lens = Lens.seq(Lens.at(1), Lens.at(2))
    get_all([ [], [0, 1, "TARGET"], []], composed_lens)

... which expands to:

    Lens.seq(Lens.at(1), Lens.at(2)).([ [], [0, 1, "TARGET"], []], & &1)
    
Substituting the two arguments:

        # This is the code implementing seq(...)
        lens1_descender =                             
           fn lens2_container ->                      
             lens2.(lens2_container, & &1)
           end                       ^^^^

        gotten = 
          lens1.([ [], [0, 1, "TARGET"], []], lens1_descender)
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^
        ???? calculate the return value
    
Might as well substitute the specific values for `lens1` and `lens2`:

        # This is the code implementing seq(...)
        lens1_descender =                             
           fn lens2_container ->                      
             at(2).(lens2_container, & &1)
             ^^^^^
           end                       
        gotten = 
          at(1).([ [], [0, 1, "TARGET"], []], lens1_descender)
          ^^^^^
            
        ???? calculate the return value
    


       lens1_descender = ...
       gotten = (
         gotten =
           lens1_descender.(Enum.at([ [], [0, 1, "TARGET"], []], 1))
         [gotten]
       )

       ???? calculate the return value
 


Let's expand out `at(1)`, combining a few steps:

        # This is the code implementing seq(...)
        lens1_descender =                             
           fn lens2_container ->                      
             at(2).(lens2_container, & &1)
             ^^^^^
           end                       
        gotten = 
          at(1).([ [], [0, 1, "TARGET"], []], lens1_descender)
          ^^^^^
            
        ???? calculate the return value

To keep down the clutter, let's (1) expand `at(1)` and then substitute the two arguments:

        lens1_descender = ...
        gotten = (
           gotten = 
        


Now let's replace `lens1` with the code for `at(1)`:

      gotten =
        (fn lens2_container ->                # the descender
          lens2.(lens2_container, & &1)
        end).(
               Enum.at([ [], [0, 1, "TARGET"], []], 1))
      [gotten]

or:

      gotten =
        (fn lens2_container ->                # the descender
          lens2.(lens2_container, fn value -> value end)
        end).([0, 1, "TARGET"])
      #       ^^^^^^^^^^^^^^^^
      [gotten]

Expanding the descender:

      gotten = 
        lens2.([0, 1, "TARGET"], fn value -> value end)
      [gotten]

Since `lens2` is constructed from `at(2)`, we know that the value of
the call to `lens2` will be the *list* `["TARGET]`. That is, after processing
`lens2`, we have this:

      # still in lens1
      gotten = ["TARGET"]  # from lens2
      [gotten]
      
Or:

      # return value from lens1
      [["TARGET"]]
      
Hmm.

### Unwrapping

To recapitulate, here is the code for the `seq` lens:

      fn lens1_container, lens2_descender ->
        lens1_descender =                   
           fn lens2_container ->                
             lens2.(lens2_container, lens2_descender)
           end                                       

        gotten = 
          lens1(lens1_container, lens1_descender)   # <<< you are here
        ...
      end

`lens1` has, in the case, returned `[["TARGET"]]`. What do we do about
that? It might be tempting to let the caller deal with it, but we
don't know who the caller is. It might be another lens, which would
add another layer of wrapping. That is, we can't rely on `get_all` to
patch things up because it doesn't know the internal structure of the
lens it calls. Instead, `seq` has to remove the nesting. 

That is done by concatenating the singleton list:

    def seq(lens1, lens2) do
      fn lens1_container, lens2_descender ->
        lens1_descender =
          fn lens2_container -> lens2.(lens2_container, lens2_descender) end
  
        gotten =
          lens1.(lens1_container, lens1_descender)
  
        Enum.concat([["TARGET"]])    # <<<<<<<<<<<<
      end
    end

(I'll answer "Why `concat`?" in the next section.)

What this means is that when you have a pipeline of lens makers like this:

    Lens.whatever |> Lens.foo |> Lens.bar |> Lens.quux

... what you've got is a bunch of lenses that finish by wrapping their
return values, only for `seq` to immediately remove the
wrappers. Seems inelegant, but without it, there would be special
cases that no single function has enough information to solve. (Are
these multiple values *in* a list, or a single value that *is* a
list?)

### The garden of forking paths

> With apologies to [Jorge Luis Borges](https://en.wikipedia.org/wiki/The_Garden_of_Forking_Paths)

The previous examples were linear: the code descended to a single
"leaf" node, then returned the value found, wrapping and unwrapping as
needed. But lenses are built on the assumption that a single `Deeply`
operation may require the lenses to descend to a leaf, retreat to some
intermediate position in the container, descend again to another leaf,
retreat again, and so on.

<<<picture>>>

Here's a simple example:

    iex> nested = [ [0, 1, 2], [0, 1111, 2222]] 
    iex> lens = Lens.all |> Lens.at(1)
    iex> Deeply.get_all(nested, lens)
    [1, 1111]
    
The question is: how is it arranged such that the result is `[1, 1111]`
and not something like `[[1], [1111]]`? It turns out to be pretty
simple. That is, lenses that "naturally" return lists don't have to do
anything special.

Here's a version of `all` that works with the makers we previously defined:

    def all do
      fn container, descender ->
        for item <- container, do: descender.(item)
      end
    end

Following the simple example, we'll examine how it fits in with this composed lens:

    seq(all(), at(1))

`seq` will expand to something like this:

    fn all_lens_container, at_lens_descender ->
      all_lens_descender =
        fn at_lens_container -> at_lens.(at_lens_container, at_lens_descender) end

      gotten =
        all_lens.(all_lens_container, all_lens_descender)

      Enum.concat(gotten)
    end

... or, plugging in a doubly-nested list:

      all_lens_descender =
        fn at_lens_container -> at_lens.(at_lens_container, & &1) end

      gotten =
        all_lens.([ [0, 1, 2], [0, 1111, 2222]], all_lens_descender)

      Enum.concat(gotten)

`all_lens` will call the `all_lens_descender` twice:

      at_lens.([0, 1, 2], & &1)
      at_lens.([0, 1111, 2222], & &1)
      
Each of them will return a wrapped value: 

      [1]
      [1111]
      
The `for` comprehension in the `all` lens will bundle those into a larger list:

      [ [1], [1111] ]
      
Which is what will be returned to the `seq` lens, which will subject it to:

      Enum.concat([ [1], [1111] ])  # or
      [1, 1111]

## Updating


### Deeply.put

`Deeply.update` and `Deeply.put` work the same way: all that's
different is whether a new "leaf node" is created with a function
(`update`) or a constant (`put`). Think of `put` as just `update` with
the following function as the update function:

    fn _ignore_current_value -> put_constant end

# `Lens.into`


# `Lens.const`