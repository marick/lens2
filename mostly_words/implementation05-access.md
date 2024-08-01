# Version 4: compatibility with `Access`

The code and tests for this version can be found in
[`implementation_v4_access_test.exs`](../test/mostly_words/tutorial/implementation_v4_access_test.exs).


We want lenses to be compatible with `get_in/2` and friends:


    iex> tuple_returner = & {&1, inspect(&1)}
    iex> lens = Lens.at(1)
    iex> get_and_update_in([0, 1, 2], [lens], tuple_returner)
                                      ^^^^^^
    {[1], [0, "1", 2]}
    

... including as only part of a list argument:


    iex> container = [0, %{a: 1}, 2]
    iex> get_and_update_in(container, [lens, :a], tuple_returner)
                                      ^^^^^^^^^^
    {[1], [0, %{a: "1"}, 2]}

In fact, let's just define our `Derply` functions in terms of the Elixir built-ins:


    def get_and_update(container, lens, tuple_returner) do
      Kernel.get_and_update_in(container, [lens], tuple_returner)
    end

    def update(container, lens, update_fn) do
      Kernel.update_in(container, [lens], update_fn)
    end

    def get_all(container, lens) do
      Kernel.get_in(container, [lens])
    end

Actually, we don't need to define `Derply` functions at all, as these
are the actual definitions used in `Lens2.Deeply`.

## The behaviour

A function suitable for `Access` is must have the following interface:

          fn
            :get, container, continuation ->
               ...

            :get_and_update, container, tuple_returner ->
               ...
          end

The `:get` and `:get_and_update` arguments are required to distinguish
the two branches because the tyhpes of the second and third arguments
are the same in both functions. The `container` can be `any` type, and
both `continuation` and `tuple_returner` are arity-one
functions. Let's look at the body of the `:get` case first:

            :get, container, continuation ->
              {gotten, _} = lens.(container, &{&1, &1})
              continuation.(gotten)

Except for the the use of the `continuation` argument, this does the
same thing as the V3 version of `get_all`. In particular it uses the
tuple-returner `&{&1, &1}` to produce the throw-away version of the
`updated` container. (So the wasteful multi-level allocation happens with
`get_in/2`.)

The continuation represents what comes after this function in a call to `get_in`. So, in this:


    get_in(..., [Lens.at(0), :a, :b])

... the continuation is a function representing the descent through
the keys `:a` and `:b`. Because `Deeply.get_all` uses a singleton
list:

    def get_all(container, lens) do
      Kernel.get_in(container, [lens])
                               ^^^^^^
    end

... there's nothing more to do, so the `continuation` will be our old
friend `& &1`. That is, when it comes to lenses, we don't need to
worry about it.

The `:get_and_update` clause looks just like the code for version 3's `Derply.get_and_update`:

            :get_and_update, container, tuple_returner ->
              lens.(container, tuple_returner)


The code for the actual lenses is the same as in version 3, except
that it should use the macro `Lens2.Makers.def_maker/2` instead of
`def`. `def_maker` wraps its body in a `:get`/`:get_and_update`
function, and also arranges to create the lens maker with an
additional argument – the one used in a pipeline. So, this use of `def_maker`:

    def_maker at(index) do
      fn container, descender -> ... end
    end

... will expand out to:

    def at(index) do 
      lens = fn container, descender -> ... end         # <<<<<
    
       fn
         :get, container, continuation -> 
           {gotten, _} = lens.(container, &{&1, &1})
           continuation.(gotten)

         :get_and_update, container, tuple_returner ->
           lens.(container, tuple_returner)
       end
    end
    
    def at(previously, index) do 
      Lens.seq(previous, at(index))
    end
    
