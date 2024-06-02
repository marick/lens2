# Lens2: a compatible successor to Lens

Lenses are a tool for working with nested data structures. They are
similar to what you get with `get_in/2` and `update_in/3`, but
somewhat more powerful and general-purpose. (For example, lenses work
with structures like `MapSet` that have neither indexes or keys.)

This package is derived from
[`Lens`](https://hexdocs.pm/lens/readme.html). If you `use` the
`Lens2.Compatible` module, you get the same API and functions. So what's the
point?


1. Lenses are notoriously hard to understand. A lot of that, I think,
   comes down to documentation. While the `Lens` package is better
   than others I've seen, the amount of work it demands from the
   learner still makes me sad.

   This package is a place to put lots of explanatory and tutorial
   documentation.
   
2. The API for *making* lenses is the same as the one for *using* lenses.
   I like the one for making lenses, but I think the one for using lenses
   should look like the familiar `get`/`put`/`update` (or `get_in`, etc.)
   So, you can create a lens that points into a data structure and names
   a few keys in there:
   
   ```elixir
   lens = Lens.key(:clusters) |> Lens.MapSet.values |> Lens.keys([:a, :z]) |> Lens.key(:age)
   ```
   
   ... and uses it as:
   
   ```elixir
   Deeply.put(structure, lens, 5)
   ```
   
   ... to set the age of deeply nested keys `:a` and `:z` (while
   leaving keys `:b` through `:y` alone).
   
3. The API encourages information hiding more than does base `Lens`
   (or `put_in` and friends). My preferred usage is to expose lenses in the module
   interface for, say, a structure. In such a case, the above would be written
   like this:
   

   ```elixir
   Deeply.put(structure, Network.age_of([:a, :z]), 5)
   ```
   
   Exactly where and how ages are stored is no business of the client.
   
   In the common case of working with structs, a lens that takes no
   arguments has a neat little shorthand parallel to the `Map`
   API:
   
   ```elixir
   Deeply.update(structure, :age, & &1+1)
   ```
   
   I find this reads nicely in pipelines.
   
   
4. It would be a tragic waste of human life for multiple people to
   write lenses for `MapSet` or
   [`BiMap`]([`BiMap`](https://hexdocs.pm/bimap/readme.html)), so this
   is a place where that can be done once and for all.
   
   Moreover, although you can combine lenses to do strange and wonderful things,
   a lot more people can *desire* the behavior than can easily *implement it*. So
   such combinations can be shared from here.
