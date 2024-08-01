defmodule Lens2.Helpers.Delegate do
  @moduledoc false


  defmacro delegate_to(module, heads) when is_list(heads) do
    for head <- heads do
      {name, arglist} = Macro.decompose_call(head)
      composing_arglist = [Macro.var(:lens, __MODULE__) | arglist]
      quote do
        defdelegate unquote(name)(unquote_splicing(arglist)), to: unquote(module)
        @doc false
        defdelegate unquote(name)(unquote_splicing(composing_arglist)), to: unquote(module)
      end
    end
  end
end
