defmodule Lens2 do
  use Lens2.Macros
  alias Lens2.{Basic, Listlike, Combine, Maplike}
  import Lens2.Helpers.Delegate


  delegate_to(Basic, [
    const(value),
    all(),
    empty(),
    root(),
    into(lens, collectable),
    filter(lens, predicate),
  ])

  # This arity is specially defined - not via deflens - so can't be part of `delegate_to`.
  defdelegate filter(predicate), to: Basic


  delegate_to(Listlike, [
    at(index),
    back(),
    before(index),
    behind(index),
    front(),
    index(index),
    indices(indices),
  ])

  delegate_to(Combine, [
    match(matcher_fun),
    multiple(lenses),
    both(lens1, lens2),
    seq(lens1, lens2),
    seq_both(lens1, lens2),
    recur(lens),
    recur_root(lens),
    context(context_lens, item_lens),
    either(lens1, fallback),
  ])

  delegate_to(Maplike, [
    key(key),
    key!(key),
    key?(key),
    keys(keys),
    keys!(keys),
    keys?(keys),
    map_values(),
    map_keys(),
  ])
end
