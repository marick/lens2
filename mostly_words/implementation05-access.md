# Version 4: compatibility with `Access`










To be compatible with `Access`, lens makers like `at/1` are defined
with the `Lens2.Makers.def_maker/2` macro. That macro does two things:

1. It defines a hidden `at/2` function that takes a lens as its first
   argument. It looks like this:
   
       def at(previous, index) do 
         seq(previous, at(index))
       end
       
   ... so that `at(0) |> at(1)` becomes `Lens.seq(at(0), at(1))`. 
   

2. It wraps definitions of the form we've been using above: 

        lens = fn container, descender -> ... end

   ... in a
   function that's compatible with the `Access` behaviour:
   
        fn
          :get, container, continuation -> ...
          :get_and_update, container, tuple_returner -> ...
        end
          
   The `:get_and_update` case is simplest:
           
          :get_and_update, container, tuple_returner -> 
            lens.(container, tuple_returner)

   That's the same as the `get_and_update` function above, except for
   the atom used to separate this pattern from the `:get` patterns
   (since the types of the second and third arguments are the same in
   both patterns).
   
   Essentially, this is an "extract method" refactoring of the version
   three `get_and_update`, leaving this behind: 
   
   
        def get_and_update(container, lens, tuple_returner) do
          get_and_update_in(container, [lens], tuple_returner)
        end
        
        
        
        
          
        fn
          :get, container, continuation ->
            {gotten, _} = lens.(container, & {&1, &1})
            continuation.(gotten)

           

     
## Handling of nils