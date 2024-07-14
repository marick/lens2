alias Lens2.Tracing
alias Tracing.{StringShifting}
alias Tracing.Adjust.Preparation

defmodule StringShifting.LogLines do

  def condense(log, pick_result: result_type) do
    Preparation.prepare_aggregates(log, pick_result: result_type)
  end

  def convert_to_shift_data(log, pick_result: result_type) do
    Preparation.prepare_lines(log, pick_result: result_type)
  end
end
