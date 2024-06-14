defmodule Lens2.Helpers.Delegate do
  @moduledoc false

  alias Lens2.Helpers.Tracing

  defmacro delegate_to(module, heads) when is_list(heads) do
    for head <- heads do
      {name, arglist} = Macro.decompose_call(head)
      tracing_name = Tracing.function_name(name)
      composing_arglist = [Macro.var(:lens, __MODULE__) | arglist]
      quote do
        defdelegate unquote(name)(unquote_splicing(arglist)), to: unquote(module)
        defdelegate unquote(name)(unquote_splicing(composing_arglist)), to: unquote(module)
        defdelegate unquote(tracing_name)(unquote_splicing(arglist)), to: unquote(module)
        defdelegate unquote(tracing_name)(unquote_splicing(composing_arglist)), to: unquote(module)
      end
    end
  end
end
