alias Lens2.Helpers.Tracing

defmodule Tracing.Pretty do
  use Lens2
  use Private
  alias Tracing.Log

  def prettify(log) do
    prettify_calls(log)
  end

  private do   # main utilities
    def prettify_calls(log) do
      log
      |> indent_calls(:call)
      |> pad_right(:call)
    end

    def indent_calls(log, key) do
      Log.in_order_reduce(log, key, 0, fn left_margin, current ->
        {left_margin + length_of_name(current), padding(left_margin) <> current}
      end)
    end

  end

  private do  # utilities
    def max_length(log, key) do
      Deeply.to_list(log, Log.all_fields(key))
      |> Enum.map(&String.length/1)
      |> Enum.max
    end

    def pad_right(log, key) do
      length = max_length(log, key)

      Deeply.update(log, Log.all_fields(key), fn current ->
        current <> padding(length - String.length(current))
      end)
    end

    def length_of_name(call) do
      [name, _rest] = String.split(call, "(")
      String.length(name)
    end

    def padding(n), do: String.duplicate(" ", n)

  end
end
