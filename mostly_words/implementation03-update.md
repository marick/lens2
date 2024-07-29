
# Version 3: update

Because updating and getting work so similarly, we can use the
previous major section as a model – but speed through it.

An `update` operation looks almost like `get_all`, except that the
identify function is replaced with the update function passed in:


    def update(container, lens, update_fn) do          def get_all(container, lens) do
                                ^^^^^^^^^
      lens.(container, update_fn)                        lens.(container, & &1)
                       ^^^^^^^^^                                          ^^^^
    end                                                end

(A `put` operation is the same, except that it codes up a constant-returning update function:

    def put(container, lens, constant) do
      lens.(container, fn _ -> constant end)
    end

I won't mention `put` any more.)

We can make a similar small change to `at` to make it work with `update`. Instead of returning an extracted element (wrapped in a list), we `put` the new element in the given index:


    def at(index) do                                    def at(index) do
      fn container, descender ->                          fn container, descender ->
        updated =                                           gotten = 
          Enum.at(container, index)                           Enum.at(container, index)
          |> descender.()                                     |> descender.()

        List.replace_at(container, index, updated)          [gotten]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^          ^^^^^^^^
      end                                                 end
    end                                                 end

You may wonder why I didn't use just `List.update`, as in:

    def at(index) do
      fn container, descender ->
        List.update_at(container, index, descender)
      end
    end

That would work just as well, but I'm using the other form for two reasons:

1. You may have noticed that this new version of `at` won't work with
   `get_all`. The next major section will fix that by taking advantage
   of the structural similarity between the two versions.
   
2. In both versions, the effect the effect is to descend into the
   container, do something, then retreat up out of the container,
   adjusting each successive container. But separating the `Enum.at` from the
   `List.replace_at` makes the sequence of events clearer.
   That is, consider this container:
   
        iex>     container =
        ...>         [
        ...>           [0],
        ...>           [
        ...>             [00],
        ...>             [11],
        ...>             [
        ...>               :---, :---, :---, 333
        ...>             ],
        ...>           [33]
        ...>          ],
        ...>          [2],
        ...>          [3]
        ...>        ]


   I want to change the triply-nested element `333`. I can't pipe my
   homegrown `at`-makers together because I used `def` instead of the
   `Lens2.Makers.def_maker/2` macro that would create the
   extra-argument version of `at` that works in a pipeline. So, I'll use
   `seq` again:
   
        iex> lens = seq(at(1), seq(at(2), at(3)))
       
    Now what happens during this?
    
        iex> update(container, lens, & &1 * 10000100001)
       
    1. The composed lens descends (via `Enum.at(..., 1`) and passes this interior container
       to its `descender`:
       
                  [
                    [00],
                    [11],
                    [
                      :---, :---, :---, 333
                    ],
                    [33]
                  ],
       
    2. The descender uses the `at(2)` lens to extract this:
    
                    [
                      :---, :---, :---, 333
                    ]

       ... and calls its descender.
    
    3. And the `at(3)` uses `Enum.at(..., 3)` to extract `333`, which – as usual – goes to its
       descender.
    4. But that descender is `& &1 * 10000100001`, which yields `3330033300333`. That is
       returned.
    5. Now the retreat begins. The new value replaces the 333 to yield:
    
                    [
                      :---, :---, :---, 3330033300333
                    ]
    5. The retreat continues, and *that* value is replaced in the `[00, 11, ... 33]` list.
    6. And the same happens in the top level.
    
    Descend, descend, descend, update, replace, replace, replace.    
    At, at, at, update, replace_at, replace_at, replace_at

Now, at this point, that won't actually work because our version of
`seq` unwraps what's assumed to be a doubly-wrapped list of gotten
values. So another one-line change is needed, to replace `Enum.concat`
with a plain return value:

      def seq(outer_lens, inner_lens) do
        fn outer_container, inner_descender ->
          outer_descender =
            fn inner_container ->
              inner_lens.(inner_container, inner_descender)
            end
    
          updated =
            outer_lens.(outer_container, outer_descender)

          updated                                          # Used to be `Enum.concat(gotten)`
          ^^^^^^^
        end
      end

And that's it!

