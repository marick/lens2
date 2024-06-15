alias Lens2.Helpers.Tracing

defmodule Tracing do
  @moduledoc false

  import TypedStruct
  use Private
  use Lens2
  alias Tracing.{Mutable, Pretty, Log}

  defmodule LogItem do
    typedstruct do
      field :call, String.t, enforce: true
      field :container, String.t, enforce: true
      field :gotten, String.t
      field :updated, String.t
    end

    def on_entry(name, args, container) do
      %__MODULE__{call: call_string(name, args), container: inspect(container)}
    end

    def on_exit(log_item, gotten, updated) do
      %{log_item | gotten: inspect(gotten), updated: inspect(updated)}
    end

    defp call_string(name, args) do
      formatted_args = Enum.map(args, & inspect(&1))
      "#{name}(#{Enum.join(formatted_args, ",")})"
    end
  end


  # External entry points

  def function_name(original_name) do
    String.to_atom("tracing_#{original_name}")
  end


  def log_entry(name, args, container) do
    case Mutable.current_nesting() do
      nil ->
        Mutable.remember_nesting(0)
        log_entry(name, args, container)
      _ ->
        log(name, args, container)
        Mutable.increment_nesting()
    end
  end

  def log_exit(result, on_level_zero \\ &spill_log/0) do
    Mutable.decrement_nesting()

    log(result)

    if Mutable.current_nesting() == 0 do
      result = on_level_zero.()
      Mutable.forget_log()
      result  # result is used by a test
    end
  end

  def spill_log() do
    log = Mutable.peek_at_log() |> Pretty.prettify
    for item <- Log.outer_to_inner_items(log) do
      IO.puts("#{item.call} || #{item.container}")
    end

    for item <- Log.inner_to_outer_items(log) do
      IO.puts("#{item.call} || #{item.gotten} || #{item.updated}")
    end
  end

  private do # Manipulating the process map
    def log(name, args, container) do
      LogItem.on_entry(name, args, container)
      |> Mutable.remember_new_item
    end

    def log({gotten, updated}) do
      Mutable.peek_at_log()[Mutable.current_nesting()]
      |> LogItem.on_exit(gotten, updated)
      |> Mutable.update_previous_item
    end

  end


end
