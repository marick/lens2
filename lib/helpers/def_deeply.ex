defmodule Lens2.Helpers.DefDeeply do
  @moduledoc false
  #  `defdeeply` expands into two functions.
  #
  #  The first is what `def` would give you.
  #
  #  The second thing `defdeeply` does is create a same-named function
  #  that uses the *name* of the lens function, instead of the function
  #  itself. Like this:
  #
  #        struct = %MyStruct{...}
  #        put(struct, :lens, value)
  #
  #  That is equivalent to this call:
  #
  #        put(struct, MyStruct.lens(), value)

  defmacro defdeeply(head, do: body) do
    case length(elem(head, 2)) do
      2 ->
        lens_is_last_argument(head, body)
      3 ->
        argument_after_lens_arg(head, body)
    end
  end

  defp argument_after_lens_arg(head, body) do
    {name, _meta, [struct_name, lens, arg3]} = head
    lookup = code_to_lookup_lens(struct_name, lens)
    quote do
      def unquote(head) when is_atom(unquote(lens)) do
        unquote(name)(unquote(struct_name),
                      unquote(lookup),
                      unquote(arg3))
      end
      def unquote(head), do: unquote(body)
    end
  end

  defp lens_is_last_argument(head, body) do
    {name, _meta, [struct_name, lens]} = head
    lookup = code_to_lookup_lens(struct_name, lens)

    quote do
      def unquote(head) when is_atom(unquote(lens)) do
        unquote(name)(unquote(struct_name),
                      unquote(lookup))
      end
      def unquote(head), do: unquote(body)
    end
  end

  defp code_to_lookup_lens(struct_name, lens) do
    quote do
      unquote(__MODULE__).lookup_lens(unquote(struct_name),
                                      unquote(lens))
    end
  end

  def lookup_lens(s_struct, lens_name), do: apply(s_struct.__struct__, lens_name, [])
end
