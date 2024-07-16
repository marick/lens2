alias Lens2.Tracing

defmodule State.Macros do
  defmacro crud(suffix, key) do
    name_for = fn prefix -> String.to_atom("#{prefix}_#{suffix}") end

    quote do
      def unquote(name_for.(:put))(value), do: Process.put(unquote(key), value)  # C
      def unquote(name_for.(:get))(), do: Process.get(unquote(key))              # R
      def unquote(name_for.(:update))(f) do                                      # U
        current = Process.get(unquote(key))
        Process.put(unquote(key), f.(current))
      end
      def unquote(name_for.(:delete))(), do: Process.delete(unquote(key))        # D
    end
  end
end

defmodule Tracing.State do
  import State.Macros
  import TypedStruct

  @log :_lens_tracing_log
  crud(:log, @log)
  def add_to_log(log_entry), do: update_log(& [log_entry | &1])

  def tracing_already_in_progress?, do: get_log() != nil

  typedstruct module: DescentItem, enforce: true do
    field :name, :atom
    field :args, [any]
    field :direction, :> | :<, default: :>
    field :container, any
  end

  typedstruct module: RetreatItem, enforce: true do
    field :name, :atom
    field :args, [any]
    field :direction, :> | :<, default: :<
    field :gotten, any
    field :updated, any
  end

  def start_log(), do: put_log([])

  def has_accumulated_a_log?, do: get_log() != []

  def log_descent(name, args, container) do
    add_to_log(%DescentItem{name: name, args: args, container: container})
  end

  def log_retreat(name, args, gotten, updated) do
    add_to_log(%RetreatItem{name: name, args: args, gotten: gotten, updated: updated})
  end

  def peek_at_log, do: get_log() |> Enum.reverse

  def patch_final_gotten(new_gotten) do
    [final | rest] = get_log()
    [%{final | gotten: new_gotten} | rest] |> put_log()
  end

  def reset do
    delete_log()
  end
end
