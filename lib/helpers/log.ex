alias Lens2.Helpers.Tracing

defmodule Tracing.Log do
  use Lens2

  deflens all_fields(key), do: Lens.map_values |> Lens.key!(key)



end
