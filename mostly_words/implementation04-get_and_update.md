# Version 3: `get_and_update`

The code and tests for this version can be found in
[`implementation_v3_get_and_update_test.exs`](../test/mostly_words/tutorial/implementation_v3_get_and_update_test.exs).


`Lens2.Deeply.get_and_update/3` is analogous to Elixir'sbuilt-in
`get_and_update_in/3`. As with `get_and_update_in/3`, it takes a function
that returns both an original value and its updated version:

    iex> tuple_returner = fn value -> {value, inspect(value)} end
    iex> Deeply.get_and_update(%{a: 1}, Lens.key(:a), tuple_returner)
    {[1], %{a: "1"}}

To implement this:

1. The descender function will, as before, take as its argument some
   container. But it will return a `{gotten, updated}` tuple.
   
2. A lens function will also return such a tuple to its caller.

3. `Derply.get_and_update` can just return the tuple:

        def get_and_update(container, lens, tuple_returner) do
          lens.(container, tuple_returner)
        end

Here is a new version of `at`. It gets a value, sends it to the
`descender`, and processes the two returned elements as in version 1
and version 2 (respectively):

    def at(index) do
      fn container, descender ->
        {gotten, updated} =
         ^^^^^^  ^^^^^^^
          Enum.at(container, index)
          |> descender.()

        {[gotten], List.replace_at(container, index, updated)}
         ^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      end
    end
    
Not a very big change. The same can be done for `seq`:

    def seq(outer_lens, inner_lens) do
      fn outer_container, inner_descender ->
        outer_descender =
          fn inner_container ->
            inner_lens.(inner_container, inner_descender)
          end

        {gotten, updated} =
         ^^^^^^  ^^^^^^^
          outer_lens.(outer_container, outer_descender)

        {Enum.concat(gotten), updated}
         ^^^^^^^^^^^^^^^^^^^  ^^^^^^^
      end
    end

## The other `Derply` operations

`Derply.update/3` uses a function that returns an updated container
(not a `{gotten, updated}` tuple). By converting that update function
into a "tuple returner", it can just use `Derply.get_and_update` and
ignore the `gotten` value:

    def update(container, lens, update_fn) do
      tuple_returner = & {&1, update_fn.(&1)}
                       ^^^^^^^^^^^^^^^^^^^^^^
      {_, updated} = get_and_update(container, lens, tuple_returner)
                                                     ^^^^^^^^^^^^^^
      updated
    end

`get_all` also calls `get_and_update`; it just returns the `gotten`
tuple element instead of `updated`. But there's a problem: What
tuple-returning function does it call?

    def get_all(container, lens) do
      tuple_returner = & {&1, ?????????}
                              ^^^^^^^^^
      {gotten, _} = get_and_update(container, lens, tuple_returner)
      gotten
    end

There's a sense in which it doesn't matter, because whatever update
happens is thrown away. So it uses the most innocuous function
possible: the identity function:

      tuple_returner = & {&1, &1}

## [Record scratch noise](pics/record-scratch.mp3)

But wait. The `at` lens's return value is constructed like this:

      {gotten, updated} = ...

      {[gotten],
       List.replace_at(container, index, updated)  ### ‽‽‽‽‽
      }

Isn't `List.replace_at/3` going to construct a *new* list, one that's
identical to the old list?  And in a pipeline of lenses, won't there
be a whole series of lenses doing that – going to a lot of work to
construct a container that's `==` to the original container,
allocating memory like mad? Only to throw away the newly-constructed
container?

Well, yes. In the case of `at`, that's exactly what
happens. Fortunately, composite structures like `Map`, structs, and
`MapSet` are clever enough not to allocate a new structure if they see
you're trying to `put` the same value that's already there. Instead,
they just return the original structure.

Still, for a large list (and other not-so-clever datetypes), there's
potentially a lot of wasted work. That means that `Deeply.get` might
get progressively slower than `get_in` as containers get bigger. 

I did some **extremely** crude benchmarking. For maps and structs, are
about twice as slow as `Access` functions, and the relationship seems
constant(ish). (I used the real `Lens` code, not `V3`.) For lists,
lenses get slower and slower as the lists get longer, but there's not
an alarming "knee" in a graph of 4,000,000 repetitions of probes into
lists of sizes up to 10,000 elements:


![alt text coming](pics/get_in_vs_get_all.png)

The ancient advice applies: let profiling tell you where your problems are.

(`Access` avoids the problem of pointless updates by having two paths
through the equivalent of lens functions: one that's purely a "get"
and one that's a "get and update". That means it's more work to add a
new data structure to `Access` than it is to write a lens for it, but you're more likely to need to replace a lens pipeline with a hand-coded get or update function.)

Speaking of `Access`...

