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

Note: you might want to defer reading this page until you actually
*are* perplexed or need to write a lens. Maybe you'll never need it!

The lens implementation is somewhat conceptually tricksy, so I'll work my way up to full
complexity. I'll start with an implementation that works for
`Deeply.get`, then I'll expand it to work with `Deeply.update` and
related operations.  I'll finish with some explanations of why
particular compositions work as they do.


## Get

Suppose we want to make this work:

    iex> get_all(["0", "1"], at(1))
    ["1"]
    
(I'm not using the `Deeply` or `Lens` because I'm showing you simplified versions of the real ones.)
    
The lens is a function, so let's have `get_all` just call it:

    def get_all(container, lens) do
      lens.(container)
    end

Then the lens-maker `at/1` just returns a function that takes a container and does its thing:

    def at(index) do
      fn container ->
        gotten = Enum.at(container, index)
        [gotten]
      end
    end
    
Notice that this version of `at` only works with lists, whereas the
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

However, lenses are meant to be used in pipelines like this:

    lens = at(1) |> at(2)
    
The code for `at` given above assumes it's at the end of a
pipeline. That can't work: it may, but it may not be. It has to work
in both cases.

Since the lens can't know where it is in a pipeline, it needs to be
told what to do after it finishes extracting a value from inside a
container. It might be told to return that value (as in the `at`
above), or it might be told to pass the value to the next lens, for it
to work with as *its* container.

This is done by passing a second argument to the lens function:

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

### seq

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

### The return value

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


### The garden of forking paths

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


### Summary 

When it comes to "getting", every lens function has three jobs, in order:


1. The function is given a container and must select (point to) zero or more
   elements of that container.

   
2. It must pass those 0, 1, or _n_ extracted elements to... it can't
   be sure. But it doesn't matter. Just to some `descender` function
   given to it. All the logistics about where the lens is in a
   pipeline are handled by its caller.

   
3. It must ensure the return value is a list. If it operates on a
   single element, it must wrap it into a singleton list.
   
   
Only the last job differs for `Deeply.update` and similar functions. I
wish it were as simple as saying `Deeply.update` passes a different
"descender" than `& &1`. Not quite, though. The complication is that
"update" functions need a way to refer to both the current and
updated values in a container.

With that teaser, ...

## Update



### Deeply.put

`Deeply.update` and `Deeply.put` work the same way: all that's
different is whether a new "leaf node" is created with a function
(`update`) or a constant (`put`). Think of `put` as just `update` with
the following function as the update function:

    fn _ignore_current_value -> put_constant end

# `Lens.into`


# `Lens.const`