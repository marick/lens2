# Migrating from Lens 1

Migration is supposed to be easy.

Note that you can migrate one module at a time.

*There are probably gotchas yet to be discovered.*

1. Put `use Lens2` at the top of any module that defines or uses
   lenses. 
   
2. Code that *makes* lenses (`Lens.key(:a)`) need not be changed.

2. Replace the operations like `Lens.to_list` and `Lens.map` with their
   `Lens2.Deeply` equivalents. Note that you have to change the
   argument order:
   
       Lens.put(lens, container, value)     # Lens 1
       Deeply.put(container, lens, value)   # Lens 2

3. If you use [`TypedStruct`](https://hexdocs.pm/typedstruct/readme.html) and [`TypedStructLens`](https://hexdocs.pm/typed_struct_lens/readme.html), you have to [I don't know what yet. Probably just adding `alias Lens2.TypedStructLens` to the head of the module].