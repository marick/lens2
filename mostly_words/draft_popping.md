# DRAFT: Popping

`Access` supports "popping" elements from containers. There are two variants.


1. The first variant allows the tuple-returner passed to
   `get_and_update_in` to return a `:pop` value instead of a tuple. That informs
   the calling code to remove an element. Here's a rather contrived example. It pops
   a key if its value is negative, stringifies it otherwise:

        iex> pop_negative = 
        ...>  & if &1 < 0, do: :pop, else: {&1, inspect(&1)}
        iex> container = [%{a: 1}, %{a: -1}]
        iex> get_and_update_in(container, [Access.all, :a], pop_negative)
        {[1, -1], [%{a: "1"}, %{}]}

2. The second variant pops particular keys, regardless of their values:

        iex> container = [ %{a: %{aa: 1, bb: 2}},
                           %{a: %{aa: 11, bb: 22}}]
        iex> pop_in(container, [Access.all, :a, :aa])
        {[1, 11], [%{a: %{bb: 2}}, %{a: %{bb: 22}}]}
        
        
### The problem with `get_and_update`

`Access` works on a few data types and requires them each to implement
`get_and_update`. It's that data-structure-specific function that
handles `:pop` return values. Here, for example is `Map.get_and_update/3`

       def get_and_update(map, key, tuple_returner)
         current = get(map, key)

         case tuple_returner.(current) do
           {gotten, updated} ->
             {gotten, put(map, key, updated)}

           :pop ->
             {current, delete(map, key)}
         end
       end
       
We could not put a similar `:pop` clause in the function that
`def_maker` wraps around a lens function because it's too late. The
wrapper takes control *after* the lens (and descender) have modified
its container.  So a `:pop` case for a map would be working with an
`updated` value like `%{a: :pop}`, not a simple `:pop`-or-tuple return
value. Whereas `Map.get_and_update/3` has to work with exactly one
datatype, the generic wrapper would have to work with
*everything*. (And, given lenses like
`Lens2.Lenses.Combine.repeatedly/1`, it couldn't even just scan the
top level for `:pop`.)

So supporting this kind of popping would mean we'd have to change quite a number
of lenses: 

    def_maker key(key) do
      fn container, descender ->
        {gotten, updated} = descender.(Map.get(container, key))
        {[gotten], Map.put(container, key, updated)}
      end
    end
    
... to this:

    def_maker key(key) do
      fn container, descender ->

        current = Map.get(container, key)
        case descender.(current) do
          :pop ->
            {[current], Map.delete(container, key)}
          {gotten, updated} ->
            {[gotten], Map.put(container, key, updated)}
        end
      end
    end

The same would have to be done for `key?/1`, `key!/1`, `at/1`. So it's
not surprising the original author of Lens 1 left it out.

... though, now that I think about it, it wouldn't be *so* hard.



### The problem with pop_in

You can also directly instruct `Access`-compatible types to pop an element at a named key:


    iex> container = %{a: [0, 1, 2]}
    iex> pop_in(container, [:a, Access.at(1)])
    {1, %{a: [0, 2]}}

In this case, the accessor list contains a function (`Access.at(1)`),
so it's handled as in the `get_and_access_in`. Effectively, it's turned into:

    iex> always_pop = fn _ -> :pop end
    iex> get_and_update_in(container, [:a, Access.at(0)], always_pop)
    {0, %{a: [1, 2]}}
    
In the more common case, where all the access list elements are keys,
it's handled by the `Access`-compatible datatype's `pop(container,
key)` function, applied to the final container and key. So, in lens terminology,
the final descender is (for a `Map`):


    descender = fn Map.pop(%{a: "pop", b: "no"}, :a) end
    
The `Access` code can do that because the access list is a *list*, so
it can inspect the last element as it recursively descends the
container. The actual code pattern matches on a single-element
list. See the fifth and sixth lines below (from the `Access.pop/2` source):


    defp pop_in_data(data, [fun])        when is_function(fun),
      ...
    defp pop_in_data(data, [fun | tail]) when is_function(fun),
      fun.(:get_and_update, data, fn _ -> :pop end)
    defp pop_in_data(data, [key]),                  # <<<<
      do: Access.pop(data, key)                     # <<<<
    defp pop_in_data(data, [key | tail]),
      ...
    
Lens code operates on functions, not lists of keys and functions, so
it can't know when it's descended to the final element. Again, any
implementation of `Deeply.pop_in` would devolve to changing lenses to
handle a `:pop` result returned from a descender. 


