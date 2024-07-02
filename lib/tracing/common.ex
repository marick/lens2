alias Lens2.Tracing

defmodule Tracing.Common do

  def stringify(f) when is_function(f), do: "<fn>"

  def stringify(data),
      do: inspect(data, charlists: :as_lists, custom_options: [sort_maps: true])

end
