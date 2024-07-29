# Version 1: `get_all`

In this series, I'm going to write four sets of lens makers. To make
it easy to refer back to previous versions, the makers will be put in
modules named after the version. So the examples on this page will
make lenses with, for example, `V1.at(1)`.

The normal `Deeply` operations will only work with the last version of
the lenses, so each version will have its own operations defined in a
module I can't resist naming
[`Derply`](https://knowyourmeme.com/memes/derp).

The code and tests for version 1 can be found in
[`implementation_v1_get_test.exs`](../test/mostly_words/tutorial/implementation_v1_get_test.exs).

## `V1.at`

Suppose we want to make this work:

    iex> Derply.get_all(["0", "1"], V1.at(1))
    ["1"]
    
The lens is a function, so let's have `Derply.get_all` just call it:

    def get_all(container, lens) do
      lens.(container)
    end

Then the lens-maker `V1.at/1` just returns a function that takes a container and does its thing:

    def at(index) do
      fn container ->
        gotten = Enum.at(container, index)
        [gotten]
      end
    end
    
Note that this version of `at` only works with lists, whereas the
real one also works with tuples.
    
Notice that the result of `Enum.at` is wrapped in a list, because
that's the contract a lens must follow. There has to be a way to
distinguish between returning a list of values and a single value
that's a list. That's done by wrapping everything in a list, so that a
single value that's a list is returned like this:

    [ [0, 1, 2] ]
    
... which is distinct from two values that are lists:

    [ [0, 1, 2], [3, 4, 5] ]
    
... or six independent values (as you might get from `Lens2.Lenses.Enum..all/0`):

    [ 0, 1, 2, 3, 4, 5 ]
    
### Descending

Fine, but lenses are meant to be used in pipelines like this:

    lens = V1.at(1) |> V1.at(2)
    
The code for `at` given above can only work at the end of a
pipeline. If it's before the end (as with the `at(1)` in the example
above), there's no code that passes control to the `at(2)` lens.

Complicating things is that a lens can't know whether it's at the end
or beginning of a pipeline (because it's put into a pipeline only
after it's been created). 

So we'll push the work onto the lens's caller. There's a style of
programming called
["continuation-passing style"](https://en.wikipedia.org/wiki/Continuation-passing_style). The
idea is that every function call is a two-part instruction:

1. Do that thing you do.
2. Pass the result to this function.


For example, consider `Map.put/3`. Let's make a version with a continuation:



For example, consider `1-2`. That can be rewritten as the rather complicated:

    iex> minus2 = fn minuend, continuation ->
    ...>      (minuend-2) |> continuation.()
    ...> end
    
    iex> minus2.(1, & &1)
    -1
    
The decision about what to do with the value has been pushed up to the
caller. (Yes, in subtraction, the number you're subtracting *from* is
the _minuend_, and the number you're subtracting is the _subtrahend_.)
    
Now consider `1-2-3-4`. Rather than define by hand `minus3` and `minus4`, I'll instead
write a `make_adder` function:

    iex> make_minus =
    ...>   fn subtrahend ->
    ...>     fn minuend, continuation -> 
    ...>       (minuend - subtrahend) |> continuation.()
    ...>     end
    ...>   end
    
    
    iex> make_minus.(2).(1,
    ...>                 fn minuend ->
    ...>                   make_minus.(3).(minuend,
    ...>                                   fn minuend -> 
    ...>                                     make_minus.(4).(minuend, & &1)
    ...>                                   end)
    ...>                 end)
    -8

That isn't wildly attractive, is it? So let's make a function named `seq` that writes some
of the boilerplate for us.

    seq =
      fn first_minus_fn, second_minus_fn -> 
        fn subtrahend, continuation -> 
           
        
        

, it needs to be
told what to do after it finishes extracting a value from inside a
container. It might be told to return that value (if it is the only
lens, or the last one in a pipeline), or it might be told to pass the
value to the next lens, for it to work with as *its* container.

A way to tell functions to do different things in different contexts
is to pass in a function that encapsulates the difference:

    def at(index) do
      fn container, descender ->
                    ^^^^^^^^^
        gotten =
          (Enum.at(container, index))
          |> descender.()
          ^^^^^^^^^^^^^^^
        [gotten]
      end
    end

The descender encapsulates the knowledge of what to do with an
extracted value. It's not the best name, since "what to do" might be
"just return it", not "descend deeper into the extracted value", but I
can't think of a better one. (This code and what follows, plus tests,
can be found
[here]((../test/mostly_words/tutorial/by_hand_get_test.exs)).

The need to handle the `get_all(..., at(1))` case means that `get_all` must pass the identity function to its lens:

    def get_all(container, lens) do
      getter = & &1
      lens.(container, getter)
    end

If `lens` is an isolated lens like a solitary, unpipelined `at`, by
calling the descender with the extracted value, it's really returning
the extracted value.

But what happens in the case where the `at` lens is followed by other
pipelined lenses? *Something* sitting between `get_all` and the `at`
lens has to create a new descender.

## V1.seq

That job is done by `seq`. Recall that the pipeline `at(1) |> at(2)`
is syntactic sugar for this expression:

    seq(at(1), at(2)
    
So we need to figure out the definition of `seq`. 

Since the result of `seq` is a lens that combines two lenses, it has to have this form:

    def seq(lens1, lens2) do
      fn container, descender ->
        ...
      end
    end
    
From the point of view of `get_all`, the function that `seq` returns
is a single lens with a single `container` and `descender`. But from
the point of view of `seq` itself, it has two lenses, each with a
container and descender. `seq`'s first argument is the container for
the *first* lens, but its second argument is the descender for the
*second*. Let's make that explicit. 

I'm going to refer to the *outer* and *inner* lenses, because lenses are
all about descending *into* structures. So:

    def seq(outer_lens, inner_lens) do
            ^^^^^^^^^^  ^^^^^^^^^^
      fn outer_container, inner_descender ->
         ^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^
      end
    end
    
Since no `outer_descender` is given, the `seq` code will have to make some. That is, it
must look like this:
    
    def seq(outer_lens, inner_lens) do
      fn outer_container, inner_descender ->
        outer_descender = fn ... end                     # <<

        gotten = 
          outer_lens.(outer_container, outer_descender)  # <<

        ???? calculate the return value
      end
    end
    

The `outer_descender`, passed to the `outer_lens`, must tell
`outer_lens` to call the `inner_lens` with whatever value the `outer_lens`
extracts from the `outer_container`. (What value that is, is none of `seq`'s business.)

    def seq(outer_lens, inner_lens) do
      fn outer_container, inner_descender ->
        outer_descender =                                  # <<
          fn inner_container ->                            # <<
            inner_lens.(inner_container, inner_descender)  # <<
          end                                              # <<

        gotten = 
          outer_lens.(outer_container, outer_descender)

        ???? calculate the return value
      end
    end

## The return value

We still have to know how `seq` calculates its return value. To see
what happens, consider this call:

    iex> lens = at(1) |> at(2)
    iex> get_all([0, [0, 1, "TARGET"]])
    
    
I'll substitute in the literal values into the code for `seq` to get:

          at(1).([0, [0, 1, "TARGET"]], fn inner_container ->
          ^^^^^
             at(2).(inner_container, & &1)
             ^^^^^                   ^^^^
          end
          
`at(1)` gets called first. When it executes, it'll run this code:

        gotten =
          Enum.at([0, [0, 1, "TARGET"]], 1)
          |> (fn inner_container ->
                at(2).(inner_container, & &1).()
          
        [gotten]

We can evaluate the `Enum.a` expression and simplify:

        gotten =
          at(2).([0, 1, "TARGET"], & &1)
        [gotten]

Let's inline `at(2)`:


        gotten =
          (
            gotten = 
              Enum.at([0, 1, "TARGET"], 2)
              |> (& &1).()
            [gotten]
          )
        [gotten]

or: 

        gotten =
          (
            gotten = 
              "TARGET"
              |> (& &1).()
            [gotten]
          )
        [gotten]

or:

        gotten =
          (
            gotten = 
              "TARGET"
            [gotten]
          )
        [gotten]

or: 

        gotten =
          ["TARGET"]
        [gotten]
        
or:

        [["TARGET"]]


That would be the wrong value for `seq`: there's an extra level of
wrapping. So `seq` uses `Enum.concat` to fix things up:

    def seq(outer_lens, inner_lens) do
      fn outer_container, inner_descender ->
        outer_descender =                                  
          fn inner_container ->                            
            inner_lens.(inner_container, inner_descender)  
          end                                              

        gotten = 
          outer_lens.(outer_container, outer_descender)

        Enum.concat(gotten)                             # <<
      end
    end

So a pipeline involves lenses wrapping too much and `seq` fixing their results.


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
    
The `all()` lens will be given this descender:

          fn outer_container -> 
            at(1).(outer_container, & &1)
            ^^^^^                   ^^^^
          end

This will be called many times in `all`'s `for` comprehension, each
time returning a singleton list. So after `seq` executes this:

        gotten = 
          all().(outer_container, outer_descender)

... `gotten` will be bound to something like this:

        [ [1], [2] ]
        
Not-at-all coincidentally, `seq`'s ending `Enum.concat(gotten)` will produce the desired list:

        [  1,  2   ]


## Summary 

When it comes to "getting", every lens function has three jobs, in order:


1. The function is given a container and must select (point to) zero or more
   elements of that container.

   
2. It must pass those 0, 1, or _n_ extracted elements to... it can't
   be sure. But it doesn't matter. Just to some `descender` function
   given to it. All the logistics about where the lens is in a
   pipeline are handled by its caller.

   
3. It must ensure the return value is a list. If it operates on a
   single element, it must wrap it into a singleton list.
   
   
Only the last job differs for `Deeply.update` and similar
functions. It turns out the change is easy.

