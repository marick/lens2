defmodule Cluster do
  use TypedStruct

  typedstruct enforce: true do
    field :name, atom
    field :downstream, %{atom => MapSet.t(atom)}, default: MapSet.new
  end
end

defmodule Network do
  use TypedStruct

  typedstruct do
    field :name_to_cluster, %{atom => Cluster.t}, default: %{}
  end
end


defmodule WhyLensesTest do
  use ExUnit.Case
  use FlowAssertions

  test "direct" do
    gate = %Cluster{name: :gate, downstream: MapSet.new([:big_edit, :has_fragments])}
    watcher = %Cluster{name: :watcher}
    network = %Network{name_to_cluster: %{gate: gate, watcher: watcher}}

    addition = :c

    result =
      for {name, cluster} <- network.name_to_cluster, into: %{} do
        {name, Map.update!(cluster, :downstream, & MapSet.put(&1, addition))}
      end
      |> then(& Map.put(network, :name_to_cluster, &1))

    assert result.name_to_cluster.gate.downstream ==
             MapSet.new([:big_edit, :has_fragments, :c])
    assert result.name_to_cluster.watcher.downstream == MapSet.new([:c])
  end

  test "access" do
    gate = %Cluster{name: :gate, downstream: MapSet.new([:big_edit, :has_fragments])}
    watcher = %Cluster{name: :watcher}
    network = %Network{name_to_cluster: %{gate: gate, watcher: watcher}}


    result =
      put_in(network, [:name_to_cluster, Access.all], 887)
    dbg result
  end
end
