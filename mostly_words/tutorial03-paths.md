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
combining lenses, you'll get surprised. I've reluctantly concluded
that the best way to un-perplex yourself is to work through the
detailed steps of what's happening in the lens code. To do that, you
need to understand lenses well enough to write one from
scratch. That's what this section is about.

The implementation is somewhat tricksy, so I'll work my way up to full
complexity. I'll start with an implementation that works for
`Deeply.get`, then I'll expand to work with `Deeply.update` and
related operations.  I'll finish with some explanations of why
peculiar compositions work as they do.

## Getting

Every lens function has three jobs, in order. I'll pile on details shortly,
but first a summary:

1. The function is given a container and must point to zero or more components
   of that container. For example, `Lens.at(1)` points at the second
   element of a list. `Lens.keys!([:a, :b])` points at two values in a
   map.
   
2. It must pass those 0, 1, or _n_ values to the next lens in a
   sequence of lenses. Importantly, it does not know its position in
   the sequence.  It may be the only element, the first element, or
   the last element. The code must work in all those cases.
   
3. It must collect the results into a list. A lens like that from
   `Lens.at(1)` may "know" it has a single element to return to the
   lens before it, but it has to wrap that in a list, because the
   previous lens (if any) doesn't know what lens it's calling, so it
   has to rely on an "I'll get a list of zero or more values"
   convention.
   
A lens is a function that takes two arguments, a *container* and a
*descender*. So the `Lens2.Lenses.Indexed.at/1` maker returns such a
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
than what you're already used to with functions like `Enum.map/2`.)

Also, you can't descend into a container *forever*. Eventually, the
descender has to be something that stops the descent. It is the
`Deeply` functions that provide that non-descending descender.
For example, `Deeply.get_all` could be implemented like this:

    def get_all(container, lens) do
      getter = fn value -> value end
      lens.(container, getter)
    end


### Walkthrough

Let's walk through this code: `get_all(["0", "1", "2"])`. A neat thing
about functional programming is that code can be evaluated by simply
successively substituting values into functions. So we substitute the
values given to `get_all` into its body:


       at(1).(["0", "1", "2"], & &1)
       
What's the value of `at(1)`? Substituting `1` into its definition, we get:

       fn container, descender -> 
         gotten = descender.(Enum.at(container, 1)
         #                                      ^
         [gotten]
       end
       

Now substitute the values for `container` and `descender`:

       gotten = (fn value -> value end).(Enum.at(["0", "1", "2"], 1))
       #        ^^^^^^^^^^^^^^^^^^^^^^^          ^^^^^^^^^^^^^^^
       [gotten]
       
Might as well evaluate `Enum.at`:

       gotten = (fn value -> value end).("1")
       #                                 ^^^
       [gotten]

... and now the not-actually-descending descender: 

       gotten = "1"
       #        ^^^
       [gotten]
       
We can finally substitute the value `gotten` is bound to to produce the return value:
 
       ["1"]
       
Zowie!

### Pipelines

Now let's see the "descender" argument earn that name.

Recall that `Lens.at(1) |> Lens.at(2)` is shorthand for this code:

    Lens.seq(Lens.at(1), Lens.at(2))
    
Since the result is a lens, `seq` has to look like this:

    def seq(lens1, lens2) do
      fn container, descender ->
        ...
      end
    end
    
Let's consider a concrete example to work through what the body of `seq` has to look like:

    composed_lens = Lens.seq(Lens.at(1), Lens.at(2))
    get_all([ [], [0, 1, "TARGET"], []], composed_lens)

Which, to be specific, expands to:

    composed_lens.([ [], [0, 1, "TARGET"], []], fn value -> value end)

If you look at the definition of `seq`, you can see that `container`
there is the container given to the *first* lens, whereas the
descender has to be given to the *second* lens (where it will be used
to pluck out the final return value). So let's have some better variable names:

    def seq(lens1, lens2) do
      fn lens1_container, lens2_descender ->
        #^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^
        ...
      end
    end
    
That means the body of the `fn` will have to *make* the
`lens1_descender` to pass to `lens1`:

    def seq(lens1, lens2) do
      fn lens1_container, lens2_descender ->
        lens1_descender = ...                    # <<
        ...
        lens1(lens1_container, lens1_descender)  # <<
      end
    end

As a descender, `lens1_descender` has to take a value extracted by
`lens1` and pass it along to `lens2`. It's not `seq`'s business how
`lens1` obtains that value. That suggests this definition for
`lens1_descender`:

    def seq(lens1, lens2) do
      fn lens1_container, lens2_descender ->
        lens1_descender =                              # <<
           fn lens2_container ->                       # <<
             lens2.(lens2_container, lens2_descender)  # <<
           end                                         # <<

        gotten = 
          lens1(lens1_container, lens1_descender)
        ...
      end
    end

I think it's worthwhile to quickly walk through the expansion of the call
to `lens1` (via `get_all`). 

      
### Walkthrough

`get_all` will pass these arguments to the composed lens produced by the call to `seq`:

    [ [], [0, 1, "TARGET"], []]
    fn value -> value end
    
Substituting in:

        # This is the code implementing seq(...)
        lens1_descender =                             
           fn lens2_container ->                      
             lens2.(lens2_container, fn value -> value end)
           end                       #^^^^^^^^^^^^^^^^^^^^

        gotten = 
          lens1([ [], [0, 1, "TARGET"], []], lens1_descender)
          #     ^^^^^^^^^^^^^^^^^^^^^^^^^^^
    
Now let's step into `lens1`; that is, the code from `at(1)`
`lens1_descender`. 

      # This is the code for `at(1)`
      gotten =
        (fn lens2_container ->                # the descender
          lens2.(lens2_container, fn value -> value end)
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

Given the "always return a list" convention, this is pretty straightforward.

Here's a simple example:

    iex> nested = [ [0, 1, 2], [00, 11, 22]] 
    iex> lens = Lens.all |> Lens.at(1)
    iex> Deeply.get_all(nested, lens)
    [1, 11]

The short version of how this works is:




## Updating


### Deeply.put

`Deeply.update` and `Deeply.put` work the same way: all that's
different is whether a new "leaf node" is created with a function
(`update`) or a constant (`put`). Think of `put` as just `update` with
the following function as the update function:

    fn _ignore_current_value -> put_constant end

# `Lens.into`


# `Lens.const`