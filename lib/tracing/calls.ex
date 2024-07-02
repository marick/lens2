alias Lens2.Tracing
import TypedStruct

defmodule Tracing.Call do
  alias Tracing.Common

  typedstruct enforce: true  do
    field :direction,     :> | :<
    field :name,          :atom
    field :args,          [any]
    field :call_string,   String.t,   default: ""
    field :indent_before, integer,    default: 0
    field :padding_after, integer,    default: 0
  end

  def new(direction, name, args \\ []),
      do: %__MODULE__{direction: direction, name: name, args: args}

  def args_string(%__MODULE__{args: args}) do
    case args do
      [] -> ""
      _ ->
        string_args =
          for arg <- args, do: Common.stringify(arg)
        "(" <> Enum.join(string_args, ", ") <> ")"
    end
  end

  def call_string(%__MODULE__{} = call) do
    "#{to_string call.direction}#{to_string call.name}#{args_string(call)}"
  end

  def output_name(atom) do
    to_string(atom)
  end
end

defmodule Tracing.Calls do
  alias Tracing.Call

  def from(maps) when is_list(maps) do
    maps
    |> Enum.map(& Call.new(&1.direction, &1.name, &1.args))
  end

  def add_call_strings(log) do
    for call <- log do
      %{call | call_string: Call.call_string(call)}
    end
  end

  def add_indents(log) do
    reducer = fn call, running_indent ->
      output_name = Call.output_name(call.name)
      name_len =  output_name |> String.length
      case call.direction do
        :> ->
          next_indent = running_indent + name_len
          { %{call | indent_before: running_indent}, next_indent }
        :< ->
          next_indent = running_indent - name_len
          { %{call | indent_before: next_indent},    next_indent }
      end
    end

    log
    |> Enum.map_reduce(0, reducer)
    |> elem(0)
  end

  def indents(log) do
    for call <- log, do: call.indent_before
  end
  def call_strings(log) do
    for call <- log, do: call.call_string
  end
end
