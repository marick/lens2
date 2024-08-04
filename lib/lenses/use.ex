defmodule Lens2.Lenses.Use do
  @moduledoc false
  defmacro __using__(_) do
    quote do

      alias Lens2.Lenses
      alias Lenses.{Enum, Indexed, Combine, Keyed, Filter}
      import Lens2.Helpers.Delegate

      delegate_to(Enum, [
        all(),
        into(lens, collectable),
        update_into(collectable, lens)
      ])


      delegate_to(Filter, [
        filter(lens, predicate),
      ])
      # This arity is specially defined - not via deflens - so can't be part of `delegate_to`.
      defdelegate filter(predicate), to: Filter
      defdelegate reject(lens, predicate), to: Filter

      # x = quote do
      #       defdelegate reject(lens, predicate), to: Basic
      # end

      # Macro.expand_once(x, __ENV__) |> Macro.to_string |> IO.puts



      delegate_to(Indexed, [
        at(index),
        back(),
        before(index),
        behind(index),
        front(),
        index(index),
        indices(indices),
      ])

      delegate_to(Combine, [
        const(value),
        empty(),
        root(),
        match(matcher_fun),
        multiple(lenses),
        both(lens1, lens2),
        seq(lens1, lens2),
        seq_both(lens1, lens2),
        recur(lens),
        recur_root(lens),
        context(context_lens, item_lens),
        either(lens1, fallback),
        repeatedly(descender),
        and_repeatedly(descender),
      ])

      delegate_to(Keyed, [
        key(key),
        key!(key),
        key?(key),
        keys(keys),
        keys!(keys),
        keys?(keys),
        key_path!(path),
        map_values(),
        map_keys(),
      ])
    end
  end
end
