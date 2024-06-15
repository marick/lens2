alias Lens2.Helpers.Tracing

defmodule Tracing.Log do
  use Lens2

  deflens all_fields(key), do: Lens.map_values |> Lens.key!(key)
  deflens one_field(level, key), do: Lens.key!(level) |> Lens.key!(key)

end
