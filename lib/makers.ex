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

  In both cases, there are actually *four* distinct functions defined,
  though the documentation only describes one. For the `leaf(key)`
  example above, those functions are:

  * `leaf(key)`: Takes a key and returns a lens. This is the documented version.

  * `leaf(lens, key)`: This composes the given lens with the one made
    from `leaf(key)`.  This is why you can build pipelines from lens
    makers (as in the definition of `leaf` itself).

  * tracing_leaf(key): Produces the same lens as `leaf(key)` except that, when the
    lens is used, it contributes to a trace of what a `Lens2.Deeply` function does:

       ![Alt-text is coming](pics/tracing_example.png)

  * `tracing_leaf(lens, key)`: the pipeline-friendly version of `tracing_leaf/1`.


  [[[[Move the following elsewhere.]]]

  ## Understanding the mechanism

  A lens function is of two forms. The first is a subtype of what `Access` calls type
  `Access.access_fun`. It is a function with this API:

      fn
        :get, container, getting_descender ->
          # returns a list with the gotten values.

        :get_and_update, container, getting_and_updating_descender ->
          # returns a tuple:
          #   { a list with the gotten values,
          #     an updated version of the original `data`.
          #   }
      end

  (It's a subtype because the gotten value must be a list, whereas `Access` functions
  can return `any` type, typically a leaf value rather than a list.)

  For this module, I'm going to call it a *composed* function because it's typically
  built from other lenses, like this:

      deflens keys(keys),
        do: keys |> Enum.map(&key/1) |> Lens.multiple

  or

      deflens clusters,
        do: Lens.key(:name_to_cluster) |> Lens.map_values

  Lenses can also be built by wrapping an `access_fun` around another
  type of function which I'll call a "raw" function (for backwards compatibility
  with code that uses [Lens 1](https://hexdocs.pm/lens/readme.html)).

  This is a function like this:

      fn container, descender ->
        # Returns a tuple
      end

  Instead of the caller choosing between one descender (used for
  `:get`, returns a single value) and another (used for
  `:get_and_update`, returns a two-value tuple), the single
  `descender` function always returns a two-value tuple.

  * For updating cases like `Deeply.put/2` or `Deeply.update/3`, it's
    the usual `{gotten, updated}` tuple (and the `gotten` value is just
    discarded).

  * In the `:get` case, there's no updating, so the tuple duplicates the
    `gotten` values, and the second one is ignored.

  The `deflens_raw` macro takes the code for such a function and
  produces a `def` that creates a legitimate (`Access.access_fun` or
  `Lens2.lens`) lens maker. It creates the pipeline and tracing versions, too.

  ## Tracing

  Tracing versions of a function are given the name of the lens function with `tracing_`
  prepended. They don't appear in documentation, but they're there.

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
  alias Lens2.Helpers.Tracing

  # The AST that comes from the `do:` block of the macro is named
  # `anonymous_function` because the typical usage is:
  #
  #    def_maker key!(key) do
  #      fn composed, descender -> ... end  <<<< here is the block
  #    end

  defp _def_maker(name, metadata, args, anonymous_function) do
    args = canonicalize_arglist(args)
    tracing_name = Tracing.function_name(name)
    quote do
      unquote(def_access_fun({name, metadata, args},
                             anonymous_function))

      @doc false
      unquote(def_access_fun({tracing_name, metadata, args},
                             wrap_function_with_tracing(name, args, anonymous_function)))

      unquote(def_with_lens_arg(name, args))
      unquote(def_with_lens_arg(tracing_name, args))
    end
  end


  # The AST that comes from the `do:` block of the macro is named
  # `plain_code` because it typically looks like this:
  #
  #    deflens keys(keys) do
  #      keys |> Enum.map(&key/1) |> Combine.multiple  <<<< here is the block
  #    end

  defp _def_composed_maker(name, metadata, args, plain_code) do
    args = canonicalize_arglist(args)
    tracing_name = Tracing.function_name(name)
    quote do
      unquote(def_composed_fun({name, metadata, args},
                                         plain_code))

      @doc false
      unquote(def_composed_fun({tracing_name, metadata, args},
                                         wrap_code_with_tracing(name, args, plain_code)))

      unquote(def_with_lens_arg(name, args))
      unquote(def_with_lens_arg(tracing_name, args))
    end
  end


  # -------------------


  # Defines a named function that implements the `Access` behaviour.
  # Used by `def_maker`. `def_compposed_maker` doesn't need it because
  # it's built on a predefined function.
  defp def_access_fun(header, anonymous_function) do
    quote do
      def unquote(header) do
        anonymous_function = unquote(anonymous_function)

        fn
          :get, container, access_list_continuation ->
            {list, _} = anonymous_function.(container, &{&1, &1})
            access_list_continuation.(list)

          :get_and_update, container, mapper ->
            anonymous_function.(container, mapper)
        end
      end
    end
  end

  # Composed functions are already consistent with the `Access.access_fun` interface,
  # so they need only be given a name.
  defp def_composed_fun(header, plain_code) do
    quote do
      def unquote(header) do
        unquote(plain_code)
      end
    end
  end

  # Create maker(lens, original_args...)
  defp def_with_lens_arg(name, args) do
    quote do
      @doc false
      def unquote(name)(previous_lens, unquote_splicing(args)) do
        Combine.seq(previous_lens, unquote(name)(unquote_splicing(args)))
      end
    end
  end

  # ----------------

  # Add tracing code on behalf of `def_maker`
  defp wrap_function_with_tracing(name, args, anonymous_function) do
    quote do
      fn container, descender ->
        lens_action = unquote(anonymous_function)
        Tracing.log_entry(unquote(name), unquote(args), container)
        result = lens_action.(container, descender)
        Tracing.log_exit(unquote(name), unquote(args), result)
        result
      end
    end
  end

  # Add tracing code on behalf of `def_composed_maker`
  defp wrap_code_with_tracing(name, args, plain_code) do
    quote do
      fn
        # We must support the `Access.access_fun` interface
        selector, container, access_function_arg ->
          lens_action = unquote(plain_code)
          Tracing.log_entry(unquote(name), unquote(args), container)
          result = lens_action.(selector, container, access_function_arg)
          Tracing.log_exit(unquote(name), unquote(args), result)
          result
      end
    end
  end

  # ----------------

  defp canonicalize_arglist(args) do
    case args do
      nil -> []
      _ -> args
    end
  end


  # ----------------

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
  defmacro def_maker({name, metadata, args}, do: anonymous_function),
           do: _def_maker(name, metadata, args, anonymous_function)


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

  defmacro def_composed_maker({name, metadata, args}, do: plain_code),
           do: _def_composed_maker(name, metadata, args, plain_code)

  @doc ~S"Alternate spelling of `def_maker/2`."
  defmacro defmaker({name, metadata, args}, do: anonymous_function),
           do: _def_maker(name, metadata, args, anonymous_function)

  @doc ~S"""
  Alternate spelling of `def_maker/2`.

  This is the equivalent macro from [Lens 1](https://hexdocs.pm/lens/readme.html).
  """
  defmacro deflens_raw({name, metadata, args}, do: anonymous_function),
           do: _def_maker(name, metadata, args, anonymous_function)



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
  defmacro deflens({name, metadata, args}, do: plain_code),
           do: _def_composed_maker(name, metadata, args, plain_code)
end
