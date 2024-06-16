alias Lens2.Helpers.Tracing


defmodule Tracing.Line do
  def call_string(name, args) do
    formatted_args = Enum.map(args, & inspect(&1))
    "#{name}(#{Enum.join(formatted_args, ",")})"
  end

end

defmodule Tracing.EntryLine do
  import TypedStruct

  typedstruct do
    field :call, String.t, enforce: true
    field :container, String.t, enforce: true
  end

  def new(name, args, container),
      do: %__MODULE__{call: Tracing.Line.call_string(name, args), container: inspect(container)}
end

defmodule Tracing.ExitLine do
  import TypedStruct

  typedstruct do
    field :call, String.t, enforce: true
    field :gotten, String.t
    field :updated, String.t
  end

  def new(name, args, gotten, updated) do
    %__MODULE__{call: Tracing.Line.call_string(name, args),
                gotten: inspect(gotten),
                updated: inspect(updated)}
  end

end
