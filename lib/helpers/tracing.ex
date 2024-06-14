defmodule Lens2.Helpers.Tracing do
  @moduledoc false

  def function_name(original_name) do
    String.to_atom("tracing_#{original_name}")
  end

  def entry(name, args, data) do
    case current_indent() do
      nil ->
        remember_indent(0)
        entry(name, args, data)
      margin ->   # Sigh. Emacs messes up indentation with `indent` because of the `in`.
        if margin == 0, do: IO.puts("\n")
        IO.puts([padding(margin), "> #{call(name, args)} ||   #{inspect data}"])
        remember_indent(margin + indent_due_to_name(name))
    end
  end

  def exit(name, args, result) do
    margin = current_indent() - indent_due_to_name(name)
    IO.puts([padding(margin), "< #{call(name, args)} ||   #{inspect result}"])
    Process.put(:lens_trace_indent, margin)
  end

  #

  defp indent_due_to_name(name),
       do: String.length(Atom.to_string(name))

  defp remember_indent(value),
       do: Process.put(:lens_trace_indent, value)

  defp current_indent(),
       do: Process.get(:lens_trace_indent)

  defp padding(n), do: String.duplicate(" ", n)

  defp call(name, args) do
    formatted_args = Enum.map(args, & inspect(&1))
    "#{name}(#{Enum.join(formatted_args, ",")})"
  end
end
