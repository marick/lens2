defmodule Lens2.Deflens do
  @moduledoc """
  `deflens` creates lenses compatible with the pipeline (`|>`) operator.


  """
  defmacro __using__(_) do
    quote do
      require Lens2.Deflens
      import Lens2.Deflens
    end
  end

  alias Lens2.Lenses.Combine

  @doc ~S"""
  A convenience to define a lens that can be piped into with `|>`.

      deflens some_lens(foo, bar), do: some_lens_combination(foo, bar)

  Is equivalent to:

      def some_lens(foo, bar), do: some_lens_combination(foo, bar)
      def some_lens(previous, foo, bar), do: Lens2.seq(previous, some_lens_combination(foo, bar))
  """
  defmacro deflens(header = {name, metadata, args}, do: body) do
    args =
      case args do
        nil -> []
        _ -> args
      end

    tracing_header = {tracing_name(name), metadata, args}

    quote do
      def unquote(header), do: unquote(body)

      @doc false
      def unquote(name)(previous, unquote_splicing(args)) do
        Combine.seq(previous, unquote(name)(unquote_splicing(args)))
      end

      def unquote(tracing_header) do
        lens = unquote(body)
        fn
          selector, data, implementation ->
            shift_right(unquote(name), data)
            result = unquote(body).(selector, data, implementation)
            shift_left(unquote(name), result)
            result
        end
      end

      def unquote(tracing_name(name))(previous, unquote_splicing(args)) do
        Combine.seq(previous, unquote(tracing_name(name))(unquote_splicing(args)))
      end
    end
  end


  @doc ~S"""
  Same as `deflens` but creates private functions instead.
  """
  defmacro deflensp(header = {name, _, args}, do: body) do
    args =
      case args do
        nil -> []
        _ -> args
      end

    quote do
      defp unquote(header), do: unquote(body)

      @doc false
      defp unquote(name)(previous, unquote_splicing(args)) do
        Combine.seq(previous, unquote(name)(unquote_splicing(args)))
      end
    end
  end

  @doc false
  defmacro deflens_raw({name, metadata, args}, do: body) do
    args =
      case args do
        nil -> []
        _ -> args
      end
    [make_raw({name, metadata, args}, body),
     make_raw({tracing_name(name), metadata, args}, tracing_body(name, body))]
  end

  def tracing_name(name) do
    String.to_atom("tracing_#{name}")
  end

  defp tracing_body(name, body) do
    quote do
      fn data, fun ->
        lens = unquote(body)
        shift_right(unquote(name), data)
        result = lens.(data, fun)
        shift_left(unquote(name), result)
        result
      end
    end
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


  defp make_raw(header = {name, _, args}, body) do
#    dbg header
    quote do
      def unquote(header) do
        lens = unquote(body)

        fn
          :get, data, next ->
            {list, _} = lens.(data, &{&1, &1})
            next.(list)

          :get_and_update, data, mapper ->
            lens.(data, mapper)
        end
      end

      @doc false
      def unquote(name)(previous, unquote_splicing(args)) do
        Combine.seq(previous, unquote(name)(unquote_splicing(args)))
      end
    end
  end
end
