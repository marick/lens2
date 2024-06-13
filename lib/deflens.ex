defmodule Lens2.Deflens do
  @moduledoc """
  Create a `def` that returns several variants of a lens.

  You can create a lens with predefined functions like
  `Lens2.Lenses.Keyed.key/1`. You can also create one by piping
  lens-creating functions into each other:

      two_level = Lens.key(:a) |> Lens.key(:b)

  If you wanted to create a named function that creates a lens, you could make a simple `def`:

      defmodule MyModule do
        ...
        def two_level(level_1_key, level_2_key),
          do: Lens.key(level_one_key) |> Lens.key(level_two_key)

  However, such a lens-maker cannot be piped into:

      Lens.key(:wrapper) |> MyModule.two_level(:a, :b)

  ... because `def` has arity2. You want an arity-three lens maker like this:

       def two_level(previous_lens, level_1_key, level_2_key),
         do: Lens.seq(previous_lens, two_level(level_1_key, level_2_key))

  The `deflens/1` macro writes that second variant for you. It also
  creates "tracing" versions of the two functions that print out their
  inputs and results, giving you traces like this: [[[update when tracing finished]][]

         > key %{a: %{b: 1}}
            > keys? %{b: 1}
            < keys? {[1], %{b: 1}}
         < key {[[1]], %{a: %{b: 1}}}

  That can help you debug complicated lens pipelines, should you be
  forced to write one.

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
  with code that uses Lens 1).

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
  defmacro __using__(_) do
    quote do
      require Lens2.Deflens
      import Lens2.Deflens
    end
  end

  alias Lens2.Lenses.Combine

  defmacro deflens_raw({name, metadata, args}, do: callback) do
    args = canonicalize_arglist(args)
    quote do
      unquote(def_access_fun_interface({name, metadata, args},
                                       callback))

      unquote(def_access_fun_interface({tracing_name(name), metadata, args},
                                       tracing_callback(name, callback)))

      unquote(def_pipe_version(name, args))
      unquote(def_pipe_version(tracing_name(name), args))
    end
  end

  defmacro deflens({name, metadata, args}, do: composed_fun) do
    args = canonicalize_arglist(args)
    quote do
      unquote(def_composed_fun_interface({name, metadata, args},
                                         composed_fun))

      unquote(def_composed_fun_interface({tracing_name(name), metadata, args},
                                         tracing_composed_function(name, composed_fun)))

      unquote(def_pipe_version(name, args))
      unquote(def_pipe_version(tracing_name(name), args))
    end
  end

  #

  defp def_access_fun_interface(header, callback) do
    quote do
      def unquote(header) do
        callback = unquote(callback)

        fn
          :get, container, access_list_continuation ->
            {list, _} = callback.(container, &{&1, &1})
            access_list_continuation.(list)

          :get_and_update, container, mapper ->
            callback.(container, mapper)
        end
      end
    end
  end

  # Composed functions are already consistent with the `Access.access_fun` interface,
  # so they need only be given a name.
  defp def_composed_fun_interface(header, composed_fun) do
    quote do
      def unquote(header) do
        unquote(composed_fun)
      end
    end
  end

  #


  defp tracing_callback(name, callback) do
    quote do
      fn data, fun ->
        callback = unquote(callback)
        shift_right(unquote(name), data)
        result = callback.(data, fun)
        shift_left(unquote(name), result)
        result
      end
    end
  end

  def tracing_composed_function(name, composed_fun) do
    quote do
      fn
        selector, data, implementation ->
          composed_fun = unquote(composed_fun)
          shift_right(unquote(name), data)
          result = composed_fun.(selector, data, implementation)
          shift_left(unquote(name), result)
          result
      end
    end
  end

  ######

  ###

  defp def_pipe_version(name, args) do
    quote do
      @doc false
      def unquote(name)(previous_lens, unquote_splicing(args)) do
        Combine.seq(previous_lens, unquote(name)(unquote_splicing(args)))
      end
    end
  end

  defp canonicalize_arglist(args) do
    case args do
      nil -> []
      _ -> args
    end
  end

  ###

  def tracing_name(name) do
    String.to_atom("tracing_#{name}")
  end

  def shift_right(name, data) do
    case Process.get(:lens_trace_indent) do
      nil ->
        Process.put(:lens_trace_indent, 0)
        shift_right(name, data)
      margin ->
        if margin == 0, do: IO.puts("\n")
        IO.puts([String.pad_leading("", margin),
                 "> #{name} #{inspect data}"])
        Process.put(:lens_trace_indent, margin + String.length(Atom.to_string(name)))
    end
  end

  def shift_left(name, result) do
    margin = Process.get(:lens_trace_indent) - String.length(Atom.to_string(name))
    IO.puts([String.pad_leading("", margin),
                 "< #{name} #{inspect result}"])
    Process.put(:lens_trace_indent, margin)
  end
end
