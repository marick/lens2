
# Version 2: update

The code and tests for this version – version 2 – can be found in
[`implementation_v1_update_test.exs`](../test/mostly_words/tutorial/implementation_v2_update_test.exs).

Update-capable lens code has the same "shape" as get-capable code. For
example, here's `V2.update` vs. `V1.get_all`. `update` takes an update
function and uses it as the final "descender":


    def update(container, lens, update_fn) do      def get_all(container, lens) do
                                ^^^^^^^^^             
      lens.(container, update_fn)                    lens.(container, & &1)
                       ^^^^^^^^^                                      ^^^^
    end                                            end

(A `put` operation is the same, except that it codes up a constant-returning update function:

    def put(container, lens, constant) do
      lens.(container, fn _ -> constant end)
    end

I won't mention `put` any more.)

It's worth emphasizing what happens in a call like:

    iex> lens = Lens.key(:a) |> Lens.key(:b) |> Lens.key(:c)
    iex> container = %{a: %{b: %{c: 1}}}
    iex> update_fn = & &1 * 1111
    iex> Deeply.update(container, lens, update_fn)
    %{a: %{b: %{c: 1111}}}
    
The code descends all the way to the inner map `%{c: 1}`. It calls this function:

    Map.update!(%{c: 1}, :c, update_fn)
    
... which produces `%{c: 1111}`. Having descended as far as it can, it
begins to "retreat" back to the original container. That means that
the lens for `key(:b)` will have pointers to two pieces of data:

    %{b: %{c: 1}}  # embedded within the original container
    %{c: 1111}     # a value returned from the lower lens

It must do this: 

    Map.put(%{b: %{c: 1}}, :b, %{c: 1111})
    
... to make a *new* map `%{b: %{c: 1111}}`. And, retreating further up the pipeline, we
get this:

    Map.put(%{a: %{b: %{c: 1}}}, :a, %{b: %{c: 1111}})
    
Every step of retreat "back up to" the original container allocates a
new map. That's just the way it is in a language without
mutability. (Such languages can make optimizations to share structure
between original and updated versions of structures, so long as no
user code can tell. I don't know if the Erlang virtual machine's
optimizations for maps would help with this example.)

With that background, here's the definition of `V2.key`:

    def key(key) do
      fn container, descender ->
        updated =
          Map.get(container, key)
          |> descender.()

        Map.put(container, key, updated)
      end
    end

In the leaf (`%{c: 1}`) case, that code has this effect:

        updated =
          Map.get(%{c: 1}, :c)
          |> (&1 * 1111).()
        Map.put(%{c: 1}, :c, updated)
    
In the next level up, the code should look like this:

        updated =
          Map.get(%{b: {c: 1}}, :b)
          |> leaf_descender.()
        Map.put(%{b: %{c: 1}}, :b, updated)
    
However, there's a `V2.seq` in between the `key(:c)` leaf lens and the
preceding `key(:b)` lens. What must that look like?

The `V1` version of `seq` gets wrapped values and has to unwrap
them. But this `V2` version gets a sub-container that's had a
repacement done. It doesn't have to do anything but return that value
to the previous lens, which will put it into the enclosing container.
So that's easy:

    # `get_all` version                                     # `update` version
    def seq(outer_lens, inner_lens) do                      def seq(outer_lens, inner_lens) do
      fn outer_container, inner_descender ->                  fn outer_container, inner_descender ->
        outer_descender =                                       outer_descender =
          fn inner_container ->                                   fn inner_container ->
            inner_lens.(inner_container, inner_descender)           inner_lens.(inner_container, inner_descender)
          end                                                     end
                                                               
        gotten =                                                updated =
        ^^^^^^                                                  ^^^^^^^
          outer_lens.(outer_container, outer_descender)           outer_lens.(outer_container, outer_descender)
                                                             
        Enum.concat(gotten)                                     updated
        ^^^^^^^^^^^^^^^^^^^                                     ^^^^^^^
      end                                                     end
    end                                                     end


When it comes to ordinary lenses, the changes are equally trivial. Here's `at`:

    # `get_all` version                # `update` version
    def at(index) do                   def at(index) do
      fn container, descender ->        fn container, descender ->
        gotten =                          updated =
          Enum.at(container, index)         Enum.at(container, index)
          |> descender.()                   |> descender.()
        [gotten]                          List.replace_at(container, index, updated)
        ^^^^^^^^                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      end                               end
    end                               end

`all` doesn't have to change at all:

    def all do                          def all do
      fn container, descender ->          fn container, descender ->
        for item <- container,              for item <- container,
            do: descender.(item)                do: descender.(item)
      end                                 end
    end                                 end

Next is to combine the V1 and V2 lenses into a template that works for both getting and updating. 