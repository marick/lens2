defmodule Lens2.TypedStructLens do

  @moduledoc """

  This is a copy of the
  [TypedStructLens](https://hexdocs.pm/typed_struct_lens/readme.html)
  package, tweaked to work with Lens2. Instead of a reference to a
  top-level module, you have to use an alias, but that's all.

  TypedStructLens is a plugin for the
  [TypedStruct](https://hexdocs.pm/typedstruct/readme.html)
  package. Briefly, if you define a struct like this:

        defmodule Example do
          alias Lens2.TypedStructLens

          typedstruct do
            plugin TypedStructLens

            field :int, integer, default: 1000
            field :list, [atom], default: [:a]
          end
        end

  ... you get predefined lens makers that point to struct fields:`Example.int/0` and
  `Example.list/0`. (There are ways to add prefixes or suffixes to the
  names to make functions like `Example.lens_int/0`.)

  The `alias` on line 2 wasn't needed with the original `TypedStructLens` package.

  It's typical to compose those auto-defined lenses to make module-specific makers:

        defmodule Example do
          ...

          use Lens2
          defmaker at(n), do: list() |> Lens.at(n)
        end

  Nothing about that needs to be changed, unless you – like me –
  prefer `Lens2.Makers.defmaker/2` to the backwards-compatible
  `Lens2.Makers.deflens/2`.

  """

  use TypedStruct.Plugin

  @impl true
  @spec field(atom(), any(), keyword(), Macro.Env.t()) :: Macro.t()
  def field(name, _type, opts, _env) do
    prefix = opts[:prefix]
    postfix = opts[:postfix]
    function_name = :"#{prefix}#{name}#{postfix}"

    quote do
      if unquote(opts[:lens] == :private) do
        deflensp unquote({function_name, [], []}), do: Lens2.Lenses.Keyed.key(unquote(name))
      else
        deflens unquote({function_name, [], []}), do: Lens2.Lenses.Keyed.key(unquote(name))
      end
    end
  end
end
