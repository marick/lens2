defmodule Lens2.Lenses.Combine do
  @moduledoc """
  Lenses that combine lenses to get new lenses.


  """
  use Lens2.Deflens
  alias Lens2.Lenses.Basic
  alias Lens2.Compatible.Operations

  @type lens :: Access.access_fun

  @doc ~S"""
  """
  @spec match((any -> lens)) :: lens
  deflens_raw match(matcher_fun) do
    fn data, fun ->
      Operations.get_and_map(matcher_fun.(data), data, fun)
    end
  end


  @spec multiple([lens]) :: lens
  deflens multiple(lenses), do: lenses |> Enum.reverse() |> Enum.reduce(Basic.empty(), &both/2)

  @doc ~s"""
  """
  @spec both(lens, lens) :: lens
  deflens_raw both(lens1, lens2) do
    fn data, fun ->
      {res1, changed1} = Operations.get_and_map(lens1, data, fun)
      {res2, changed2} = Operations.get_and_map(lens2, changed1, fun)
      {res1 ++ res2, changed2}
    end
  end


  @doc ~S"""
  """
  @spec seq(lens, lens) :: lens
  deflens_raw seq(lens1, lens2) do
    fn data, fun ->
      {res, changed} =
        Operations.get_and_map(lens1, data, fn item ->
          Operations.get_and_map(lens2, item, fun)
        end)

      {Enum.concat(res), changed}
    end
  end

  @doc ~S"""
  """
  @spec seq_both(lens, lens) :: lens
  deflens seq_both(lens1, lens2), do: both(seq(lens1, lens2), lens1)





  @doc ~S"""
  """
  @spec recur(lens) :: lens
  deflens_raw recur(lens), do: &do_recur(lens, &1, &2)

  @doc ~S"""
  """
  @spec recur_root(lens) :: lens
  deflens recur_root(lens), do: both(recur(lens), Basic.root())

  defp do_recur(lens, data, fun) do
    {res, changed} =
      Operations.get_and_map(lens, data, fn item ->
        {results, changed1} = do_recur(lens, item, fun)
        {res_parent, changed2} = fun.(changed1)
        {results ++ [res_parent], changed2}
      end)

    {Enum.concat(res), changed}
  end

  @doc """
  """
  @spec context(lens, lens) :: lens
  deflens_raw context(context_lens, item_lens) do
    fn data, fun ->
      {results, changed} =
        Operations.get_and_map(context_lens, data, fn context ->
          Operations.get_and_map(item_lens, context, fn item -> fun.({context, item}) end)
        end)

      {Enum.concat(results), changed}
    end
  end

  @doc ~S"""
  """
  @spec either(lens, lens) :: lens
  deflens_raw either(lens, other_lens) do
    fn data, fun ->
      case Operations.get_and_map(lens, data, fun) do
        {[], _updated} -> Operations.get_and_map(other_lens, data, fun)
        {res, updated} -> {res, updated}
      end
    end
  end
end
