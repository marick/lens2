# Rationale

I've written this rationale for people who are already familiar with
Elixir's built-in `Access` module and its related
functions(`get_in/2`, `put_in/3`, `update_in/3`, etc. If you're not
familiar with that, you might want to read "For `Access` novices", then skip to [Part 2](#part-2-why-a-new-package) on this page.

## Part 1: Why not `Access`?

Lenses are a tool for working with nested data structures, which I'll
call *containers*. Elixir already comes with a tool for that:

     iex> container = %{top_level: [%{lower: 3}, %{lower: 4}]}
     iex> put_in(container, [:top_level, Access.all, :lower], :NEW)
     %{top_level: [%{lower: :NEW}, %{lower: :NEW}]}

Lenses provide an alternative:

     iex> container = %{a: [%{b: 3}, %{b: 4}]}
     iex> lens = Lens.key(:top_level_1) |> Lens.all |> Lens.], :NEW)
     %{a: [%{b: :NEW}, %{b: :NEW}]}

That looks like a lot of extra characters to achieve the same result. So: why lenses?

1. Lenses have more power. That is, there are more functions like
   `Access.all`. Things that are awkward or impossible with just `Access`
   are built in:
   
       # Increment all map values:
       iex> Deeply.update(%{a: 1, b: 2, c: 3}, Lens.map_values, & &1+1)
       %{c: 4, a: 2, b: 3}

2. Lenses can work with types that don't implement the `Access` behaviour. For example,
   `MapSets` don't have keys, so the `MapSet` module doesn't implement `fetch`. 
   
In a way, what you just read is a lie. The list given to a function
like `get_in` is a description of how to navigate into a nested data
structure. An element in the list can be any function that has this interface:

      fn
        :get, container, getting_descender ->
           ...
        :get_and_update, container, getting_and_updating_descender ->
           ...
      end

So you could write functions that obey that interface and descend just fine into MapSets. 

One way to look at lenses is to save you the trouble of writing such functions. 

1. You can just use `Lens.MapSet.all_values` instead of writing it yourself.

2. If you write a lot of such functions, you'll find that you're
   repeating yourself. The traditional function language approach to
   repetition is to factor it out into smaller functions that you
   compose together in different ways. But `Lens.multiple` and `Lens.repeatedly`
   have already been written.


## Part 2: Why a new package?

There already exist lens packages at
[hex.pm](https://hex.pm/packages?search=lens&sort=recent_downloads). I
used [`Lens`](https://hexdocs.pm/lens/readme.html) and originally
intended to add a few small things to it, but got carried away to the
point where a few pull requests wouldn't do it. Rather, a
fork-and-extensive-reworking seemed justified. So I dubbed the
previous package "Lens 1" and have called this one "Lens 2". Here are the
highlights:

1. Lens 2 is largely backwards compatible. All of the functions that
   make lenses still exist and are used the same way:
   
   
   ```elixir
   lens = Lens.key(:clusters) |> Lens.map_values |> Lens.key!(:age)
   ```

3. However, in Lens 1, the functions that *make* lenses and the functions that
   *use* them were in the same module. I've separated the latter out into
   the `Deeply` module and changed some names to ones I think are
   usefully closer to Elixir conventions. (So the lens version of
   `update_in/3` is `Deeply.update` rather than `Lens.map`.)
   
1. Lenses are notoriously hard to understand. A lot of that, I think,
   comes down to documentation. While Lens 1 is better
   than others I've seen, the amount of work it demands from the
   learner is still too much, in my opinion.
   So this package has lots of explanatory and tutorial documentation, longer docstrings,
   and some renamed functions. (With the old names still supported.)

2. Composing existing lenses to make new lenses is *usually* straightforward, but there
   are occasionally subtleties and gotchas. I try to call those out in
   docstrings and tutorials, but that may not be enough. So each predefined lens maker
   (and the ones you create yourself) has a `tracing_` variant that makes a lens
   which describes what it's doing as it moves around within a nested container.
   For example, suppose you have this lens:
   
   ```elixir
   lens = 
     Lens.tracing_seq(Lens.tracing_map_values,
                      Lens.tracing_all |> Lens.tracing_into(MapSet.new))
   ```
       
   ... and you use it with `Deeply.update`:

   ```elixir
   Deeply.update(%{a: 0..2, b: 3..4}, lens, &inspect/1)
   ```
       
   You'll see this:

   ![Alt-text is coming](pics/tracing_example.png)

   
3. The `Deeply` API encourages information hiding and the use of structs
   more than does Lens 1 (or `put_in` and friends). When I use
   lenses, I usually make them part of a module's interface. For
   example, I have a `Network` struct that connects named
   "clusters". The connections are somewhat complicated internally,
   but a client of `Network` needn't know that: it merely wants to
   ask for one cluster's downstream neighbors. This function:
   
        Network.downstream_from(name)
   
   ... returns a lens for clients to use in calls like this:
   
        Deeply.get_all(network, Network.downstream_from(cluster))
        
   Often, that code could be simpler. `Network.downstream_from/1`
   makes a lens that refers to a particular `cluster`. However,
   lens-making functions often don't. For example, `Lens.map_values/0`
   always refers to all the values of a map (or struct), and
   `Network.linear_clusters/0` refers to all the linear clusters. In this case, and
   because `Network` is a struct, client code can fetch all the linear clusters with:
   
        Deeply.get_all(network, :linear_clusters)
        
   I like the idea of "pointing at" struct values with a single name or atom, without
   client code having to care if the field is at the top level, is buried within the
   network, or is computed on the fly. 
   
   Information hiding still rules, though it's less emphasized in functional programming than object-oriented programming. Joe Bergin used to say of object-oriented
   code that "I should be able to ask you what you had for breakfast
   without knowing how to reach into your stomach to find out", and I
   think Lens 2 supports the functional programming equivalent.
   
   
4. It would be a tragic waste of human life for multiple people to
   write lenses for `MapSet` or
   [`BiMap`]([`BiMap`](https://hexdocs.pm/bimap/readme.html)), so this
   is a place where that can be done once and for all.
   
   Moreover, although you can combine lenses to do strange and wonderful things,
   a lot more people can *desire* some behavior than can easily *implement it*. So
   such frequently-desired combinations can be shared from here.
