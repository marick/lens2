defmodule Lens2.Helpers.Delegate do

  defmacro delegate_to(module, heads) when is_list(heads) do
    for head <- heads do
      quote do
        defdelegate unquote(head), to: unquote(module)
      end
    end
  end
end
