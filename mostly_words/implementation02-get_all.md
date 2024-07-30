# Version 1: `get_all`

Although the previous page showed that lenses have a family
resemblance to continuation-passing style, there are some differences:

* I had a single "launcher" function, `do_to` that is reminiscent of
  `Deeply.put`. But lenses have several launcher functions for different
  purposes. That is, a single lens can accommodate `get_all`, `put`, and
  `update` functions.

* Put a bit differently, `make_put_fn` can only be used to put
  values. What's being put is defined in the function that's like a
  lens maker, rather than in the launcher function (like `Deeply.put`).

This page is a first step toward showing how lenses accomplish those
differences. It starts by adding just just a smidge onto the
continuation-passing style example.

Since there will be multiple implementations of lenses coming up, I'll
distinguish them by using a version number prefix instead of
`Lens`. Code on this page is version `V1`, and it will define
`V1.at/1`, `V1.seq/2`, and `V2.all/0`, as well as a `Deeply`-style
`get_all` function. The normal `Deeply` operations only work with the
`V4` implementation, so each version will have its own operations
defined in a module I can't resist naming
[Derply](https://knowyourmeme.com/memes/derp).

The code and tests for version 1 can be found in
[`implementation_v1_get_test.exs`](../test/mostly_words/tutorial/implementation_v1_get_test.exs).

## `V1.at`

If we're using continuation-passing style as a model, a lens should
take a container as an argument, plus a continuation-ish function. I
say "continuation-ish" because, while the argument has the effect of
continuing a computation by descending more deeply into a container, a
proper continuation is the last thing a function does. A lens
function takes the return value of the continuation-ish function and does something with
it. So I'm going to call that argument a *descender* instead of a continuation. 

Here is the definition of `V1.at/1`:

    def at(index) do
      fn container, descender ->
        gotten =
          Enum.at(container, index)
          |> descender.()
        [gotten]            # <<<<<
      end
    end

The difference is that the `descender`'s return value is wrapped in a list: 
that's the contract a lens must follow. There has to be a way to
distinguish between returning a list of values and a single value
that's a list. That's done by wrapping everything in a list, so that a
single value that's a list is returned like this:

    [ [0, 1, 2] ]
    
... which is distinct from two values that are lists:

    [ [0, 1, 2], [3, 4, 5] ]
    
... or six independent values (as you might get from `Lens2.Lenses.Enum.all/0`):

    [ 0, 1, 2, 3, 4, 5 ]

The difference between `V1` and continuation-passing style comes down
entirely to the little bit of code that executes after the descender.

(Note that this version of `at` only works with lists, whereas the
real one also works with tuples. Nothing informative about lenses
would be gained by dragging in tuples, so I won't.)

## Derply.get_all

As with the previous page's `do_to` function, `get_all` says what the last continuation in a chain should do. And that is... nothing: just return the value handed it back up the chain. 
So the implementation is simple:

    def get_all(container, lens) do
      getter = & &1    # Just return the leaf value
      lens.(container, getter)
    end

Now this works: 

    iex> Derply.get_all(["0", "1"], V1.at(1))
    ["1"]
    
    
## V1.seq

As you've seen (I hope) a couple of times in this documentation, piping the lens from one
lens maker into another makes use of `seq`. That is, this:

    Lens.at(1) |> Lens.at(2) 
    
... means that the second maker should produce code equivalent to this:

    Lens.seq(Lens.at(1), Lens.at(2))
    
We can use the previous page's `step_combiner` as a template. Instead
of `step1` and `step2`, there'll be `outer_lens` and `inner_lens`:

     def seq(outer_lens, inner_lens) do
       fn outer_container, inner_descender ->
         ...
       end
     end

The `outer_descender` has to be constructed by `seq`. I'll give it an explicit name:

     def seq(outer_lens, inner_lens) do
       fn outer_container, inner_descender ->
         outer_descender =                                 # <<<
          fn inner_container ->                            # <<<
            inner_lens.(inner_container, inner_descender)  # <<<
          end                                              # <<<
       ...
       end
     end
    
In our quasi continuation-passing style, `seq` has to do something
with the value returned by the `outer_descender`:

     def seq(outer_lens, inner_lens) do
       fn outer_container, inner_descender ->
         outer_descender =                                 
          fn inner_container ->                            
            inner_lens.(inner_container, inner_descender)  
          end                                              
       
        gotten =
          outer_lens.(outer_container, outer_descender)
        ????.(gotten)
        ^^^^^^^^^^^^^
       end
     end
     
What? Consider this container: `[ [], [1, 2, 3] ]` and the
pipeline from `V1.at(1)` to `V1.at(2)`. 

1. `V1.at(1)`'s lens first uses `Enum.at(..., 1)` to extract
   `[1, 2, 3]`, which it passes to the `outer_descender` and thus to
   the lens from `V1.at(2)`.

2. `V1.at(2)`'s lens extracts `2` and passes it to the inner descender,
   which immediately returns it.
   
3. Now, the `V1.at(2)` lens wraps the result in a list, and returns it
   to the `V1.at(1)` lens function. That function's `descender` returns it. 
   
   At this point, we can represent the state of the `V1.at(1)` lens function as this:
   
   
        fn container = [ [], [1, 2, 3] ], descender ->
          gotten =
            # Enum.at(container, 1)
            # |> descender.()
            [2]
            ^^^
          [gotten]
        end

4. As night follows day, the function will wrap `[2]` in a list, and
   so return `[[2]]` to `seq`, which I'll represent as:
   
        fn outer_container, inner_descender ->
          outer_descender = ...

          gotten =
            # outer_lens.(outer_container, outer_descender)
            [[2]]
            ^^^^^
          ????(gotten)
        end

   We've doubly-wrapped the return value. Returning it would violate the
   lens contract. Unwrapping could be done in several ways, but this is
   the right one:

        fn outer_container, inner_descender ->
          outer_descender = ...
          gotten = ...

          Enum.concat(gotten)
        end
        
   Why that instead of, say, this:

          [gotten] =
            # outer_lens.(outer_container, outer_descender)

          gotten
          
   Well...


## The garden of forking paths

> With apologies to [Jorge Luis Borges](https://en.wikipedia.org/wiki/The_Garden_of_Forking_Paths)

The previous example was linear: the code descended to a single
"leaf" node, then returned the value found, wrapping and unwrapping as
needed. But lenses are built on the assumption that a single `Deeply`
operation may require the lenses to descend to a leaf, retreat to some
intermediate position in the container, descend again to another leaf,
retreat again, and so on.

Here's a simple example:

    iex> nested = [ [0, 1, 2], [0, 1111, 2222]] 
    iex> lens = V1.all |> V1.at(1)
    iex> Derply.get_all(nested, lens)
    [1, 1111]
    
The `Enum.concat/1` call in `seq` is what produces that result. Let's
step through that, meaning I need to shgow you the code for `V1.all`. It's simple:

    def all do
      fn container, descender ->
        for item <- container, do: descender.(item)
      end
    end

In our example, `all` will do this, in effect:

        for item <- [ [0, 1, 2], [0, 1111, 2222]],
          do: descender.(item)
      
... which is the same as this:

        [
          descender.([0, 1, 2])
          descender.([0, 1111, 2222])
        ]
        
Since the `descender` calls `at(1)`, that's equivalent to this:

        [
          [1],
          [1111]
        ]
        
... and *that's* why `seq` uses `Enum.concat/1`:

        iex> Enum.concat([ [1], [1111] ])
        [1, 1111]

The upshot of all this is that unless you're writing a special lens
maker like `V1.seq`, you won't have to worry about any unwrapping or
rewrapping. Just follow two rules:

1. If you're fetching exactly one element, wrap it.
2. If you're fetching zero to many elements, you've probably already got a list. Just return it. 

`V1.at` is an example of the first rule. `V1.all` is an example of the second.

Now let's implement `Derply.update` and lenses that will work with that.