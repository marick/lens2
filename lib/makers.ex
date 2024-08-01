defmodule Lens2.Makers do
  @moduledoc """
  Two ways of defining named lens-making functions that improve on `def`.

  *Lens makers* are named functions that, when called, return a
   lens. Lens makers are created in three ways:

  1. Using plain old `def`:

         def leaf(key), do: Lens.key(:down) |> Lens.key(key)

     This is fine, but you *cannot* use `leaf` itself in a pipeline. That is, this
     will fail to compile:

         Lens.key(:upper) |> leaf(:bottom)
         error: undefined function leaf/2

  1. Because of that, it's better to use `def_composed_maker/2` (alternately, `deflens/2`).
     This creates a lens maker from one or more other lens makers, most often
     by piping them into each other. For example, a lens maker for two-level maps
     could be defined like this:

         def_composed_maker leaf(key), do: Lens.key(:down) |> Lens.key(key)
         # Works fine:
         Lens.key(:upper) |> leaf(:bottom)

  1. `def_maker/2` (alternately, `defmaker/2` or `deflens_raw/2` is used for cases where
     a lens maker can't be made from other lens makers. For example, the definition of
     ``Lens2.Lenses.Keyed.key!/1`` looks like this:

         @spec key!(any) :: Lens2.lens
         def_maker key!(key) do
           fn composed, descender ->
             {gotten, updated} = descender.(DefOps.fetch!(composed, key))
             {[gotten], DefOps.put(composed, key, updated)}
           end
         end

  """

  @doc """
  Import the maker macros.
  """

  defmacro __using__(_) do
    quote do
      require Lens2.Makers
      import Lens2.Makers
    end
  end

  alias Lens2.Lenses.Combine

  # These are the real versions of the two maker macros. There's a funny
  # name because there are synonyms for each.
  
  defp _def_maker({name, _metadata, args} = header, lens_code) do
    args = force_arglist(args)
    quote do

      def unquote(header) do
        lens = unquote(lens_code)

        fn
          :get, container, access_list_continuation ->
            {list, _} = lens.(container, &{&1, &1})
            access_list_continuation.(list)

          :get_and_update, container, tuple_returner ->
            lens.(container, tuple_returner)
        end
      end

      unquote(allow_pipeline(name, args))
    end
  end

  defp _def_composed_maker({name, metadata, args}, plain_code) do
    args = force_arglist(args)
    quote do
      def unquote({name, metadata, args}), do: unquote(plain_code)
      unquote(allow_pipeline(name, args))
    end
  end


  defp allow_pipeline(name, args) do
    quote do
      @doc false
      def unquote(name)(previous_lens, unquote_splicing(args)) do
        Combine.seq(previous_lens, unquote(name)(unquote_splicing(args)))
      end
    end
  end

  # A missing arglist is passed to a macro as `nil`, rather than `[]`.
  defp force_arglist(args) do
    case args do
      nil -> []
      _ -> args
    end
  end


  # -- Define the two maker functions plus a bunch of aliases.

  @doc """
  Write a lens maker without using other lens makers.

  The body of the function must return a two-argument function that takes a container
  and a "descender" function:

      @spec key!(any) :: Lens2.lens
      def_maker key!(key) do
        fn container, descender ->
          ...
        end
      end

  The job of the returned function is to take the container, take a
  value within it, and pass it to the descender:

      def_maker key(key) do
        fn container, descender ->
          ... = descender.(DefOps.fetch!(container, key))
          ...
        end
      end

  (`Defops.fetch!` calls `Map.fetch!/2` in the case of a map or
  `Access.fetch!/2` otherwise. I presume the map version of `fetch!`
  is more efficient than the `Access` version.)

  The result is a tuple:

  * If the original container was being operated on by
    `Lens2.Deeply.get_and_update/3` or `get_and_update_in/3`, the first
    element contains the "get" and the second is the "update".

  * If the operation was a put or an update, the same is done – I
    guess you've got the value right there, so you might as well pass it along. The
    original operation will discards it.

  * If the operation is a get, the gotten value will be both values of the tuple.

  Your code doesn't have to worry about that: it can simply assume
  `get_and_update` is being used.

        fn container, descender ->
          {gotten, updated} = descender.(...)
          ...
        end
      end

  Your code has to bundle up the `gotten` and `updated` functions into
  a tuple of its own and return that:

       fn container, descender ->
         {gotten, updated} = descender.(DefOps.fetch!(container, key))
         {[gotten], DefOps.put(container, key, updated)}
       end

  The "updated" case involves putting the new value in place of the
  one that was extracted "on the way down". The "gotten" case is more
  subtle **and I haven't figured out how to explain it. This paragraph
  should link to a tutorial I haven't written yet.**

  """
  defmacro def_maker(header, do: lens_code),
           do: _def_maker(header, lens_code)


  @doc """
  Create a lens maker from one or more other lens makers.

  Most often, this is used to name a pipeline of lenses (and make the
  resulting function suitable for including in other pipelines):

       def_composed_maker leaf(key), do: Lens.key(:down) |> Lens.key(key)
  
  The body after the `do:` can be arbitrary code:

       def_composed_maker keys(keys) do
         keys |> Enum.map(&key/1) |> Combine.multiple
       end

  The only requirement is that the last thing the code does must be to
  call a lens maker.  (Or, I suppose, produce a lens in some other
  way, but you'd probably use `def_maker/2` for that.)

  """

  defmacro def_composed_maker(header, do: plain_code),
           do: _def_composed_maker(header, plain_code)

  @doc ~S"Alternate spelling of `def_maker/2`."
  defmacro defmaker(header, do: lens_code),
           do: _def_maker(header, lens_code)

  @doc ~S"""
  Alternate spelling of `def_maker/2`.

  This is the equivalent macro from [Lens 1](https://hexdocs.pm/lens/readme.html).
  """
  defmacro deflens_raw(header, do: lens_code),
           do: _def_maker(header, lens_code)



  @doc ~S"""
  Alternate spelling of `def_composed_maker/2`.

  This is the equivalent macro from [Lens 1](https://hexdocs.pm/lens/readme.html). You won't break my heart
  if you prefer it to `def_composed_maker/1`, but I had early troubles confusing
  a lens and a lens *maker*. I suspect this name will help other novices avoid my
  mistakes.

  I suppose I should deprecate the `Lens` alias (`Lens.key?(:a)`, etc.), but:

  > Do I contradict myself?   
  > Very well then I contradict myself,   
  > (I am large, I contain multitudes.)   
  >   
  >    – Walt Whitman, Leaves of Grass   

  """
  defmacro deflens(header, do: plain_code),
           do: _def_composed_maker(header, plain_code)
end
