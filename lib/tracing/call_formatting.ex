alias Lens2.Tracing
import TypedStruct

defmodule Tracing.Call do
  alias Tracing.Common

  typedstruct enforce: true  do
    field :direction,     :> | :<
    field :name,          :atom
    field :args,          [any]
    field :string,        String.t,   default: ""  #builds over time
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

  def formatted_name(%{name: name}) do
    to_string(name)
  end

  def indented_width(call),
      do: call.indent_before + String.length(call.call_string)
end

defmodule Tracing.Calls do
  alias Tracing.Call

  def from(maps) when is_list(maps) do
    maps
    |> Enum.map(& Call.new(&1.direction, &1.name, &1.args))
  end

  def format_calls(log) do
    for call <- log do
      %{call | string: Call.call_string(call)}
    end
  end

  def add_indents(log) do
    update = fn call, indent_to_use ->
      Map.update!(call, :string, & String.duplicate(" ", indent_to_use) <> &1)
    end

    map_reducer = fn call, running_indent ->
      name_len = Call.formatted_name(call) |> String.length

      case call.direction do
        :> ->
          next_indent = running_indent + name_len
          { update.(call, running_indent), next_indent }
        :< ->
          next_indent = running_indent - name_len
          { update.(call, next_indent), next_indent }
      end
    end

    log
    |> Enum.map_reduce(0, map_reducer)
    |> elem(0)
  end

  def strings(calls),
      do: (for call <- calls, do: call.string)

  def max_width(log) do
    strings(log)
    |> Enum.map(&String.length/1)
    |> Enum.max
  end

  def pad_to_flush_right(log) do
    max_width = max_width(log)

    for call <- log do
      padding_to_use = max_width - String.length(call.string)
      Map.update!(call, :string, & &1 <> String.duplicate(" ", padding_to_use))
    end
  end

  #-

  def log_to_call_strings(log) do
    finished =
      from(log)
      |> format_calls
      |> add_indents
      |> pad_to_flush_right

    for call <- finished, do: call.string
  end
end
