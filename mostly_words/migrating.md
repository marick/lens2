# Migrating from Lens 1

Migration is supposed to be easy.

Note that you can migrate one module at a time.

*There are perhaps gotchas yet to be discovered.*

1. Put `use Lens2` at the top of any module that defines or uses
   lenses. 
   
2. Code that *makes* lenses (`Lens.key(:a)`) need not be changed.

2. Replace the operations like `Lens.to_list` and `Lens.map` with their
   `Lens2.Deeply` equivalents. Note that you have to change the
   argument order:
   
        Lens.put(lens, container, value)     # Lens 1
        Deeply.put(container, lens, value)   # Lens 2
       
   Here is a list of changes:
   
   
        Lens.each(lens, container, f)         Deeply.each(container, lens, f)
        Lens.get_and_map(lens, container, f)  Deeply.get_and_update(container, lens, f)
        Lens.map(lens, container, f)          Deeply.update(container, lens, f)
        Lens.one!(lens, container)            Deeply.get_only(container, lens) or Deeply.one!(container, lens
        Lens.put(lens, container, v)          Deeply.put(container, lens, v)
        Lens.to_list(lens, container)         Deeply.get_all(container, lens) or Deeply.to_list(container, lens)
        
4. `use Lens2` will import macros `deflens` and `deflens_raw`, so you
   don't have to change them. However, it also imports `defmaker` and
   `def_raw_maker`, which I prefer.

3. If you use
   [`TypedStruct`](https://hexdocs.pm/typedstruct/readme.html) and
   [`TypedStructLens`](https://hexdocs.pm/typed_struct_lens/readme.html),
   you have to add an `alias Lens2.TypedStructLens` to your existing modules. 
   See the [module documentation](Lens2.TypedStructLens.html).
