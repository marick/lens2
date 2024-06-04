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
  use Lens2

  def network() do
    gate = %Cluster{name: :gate, downstream: MapSet.new([:big_edit, :has_fragments])}
    watcher = %Cluster{name: :watcher}
    %Network{name_to_cluster: %{gate: gate, watcher: watcher}}
  end

  test "single update with bookkeeping code" do
    network = network()

    new_cluster =
      network.name_to_cluster[:gate]
      |> Map.update!(:downstream, & MapSet.put(&1, :some_name))

    new_map =
      network.name_to_cluster
      |> Map.put(:gate, new_cluster)

    network = %{network | name_to_cluster: new_map}

    network.name_to_cluster[:gate].downstream

    assert network.name_to_cluster[:gate].downstream ==
             MapSet.new([:big_edit, :has_fragments, :some_name])
  end

  test "single update_in" do
    network = network()

    network2 = update_in(network.name_to_cluster[:gate].downstream,
                        & MapSet.put(&1, :some_name))

    assert network2.name_to_cluster[:gate].downstream ==
             MapSet.new([:big_edit, :has_fragments, :some_name])

    path = [Access.key(:name_to_cluster), :gate, Access.key(:downstream)]
    network3 = update_in(network, path,
                         & MapSet.put(&1, :some_name))

    assert network3.name_to_cluster[:gate].downstream ==
             MapSet.new([:big_edit, :has_fragments, :some_name])


    assert_raise(RuntimeError, fn ->
      path = [Access.key(:name_to_cluster), Access.all(), Access.key(:downstream)]
      update_in(network, path, & MapSet.put(&1, :some_name))
    end)
  end

  @tag :skip
  test "use Deeply.update" do
  end


  test "use update_in" do
    network = network()

    path = [Access.key(:name_to_cluster),  # Note Access
            Lens.keys([:gate, :watcher]),  # Note Lens
            Access.key(:downstream)]
    update_in(network, path, & MapSet.put(&1, :some_name)) |> dbg
  end


###### OLD

  test "handling all with a loop" do
    network = network()

    new_map =
      for {name, cluster} <- network.name_to_cluster, into: %{} do
        new_cluster = update_in(cluster.downstream, & MapSet.put(&1, :some_name))
        {name, new_cluster}
      end
    network2 = %{network | name_to_cluster: new_map}

    assert network2.name_to_cluster[:gate].downstream ==
             MapSet.new([:big_edit, :has_fragments, :some_name])

    assert network2.name_to_cluster[:watcher].downstream ==
             MapSet.new([:some_name])
  end


  ####

  test "direct_old" do
    network = network()
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


    clusters_to_update = [:gate, :watcher]
    Enum.reduce(clusters_to_update, network, fn elt, acc ->
      # path = [Access.key(:name_to_cluster), elt, Access.key(:downstream)]
      # update_in(acc, path, &MapSet.put(&1, :cluster_name))
      # or...
      update_in(acc.name_to_cluster[elt].downstream, &MapSet.put(&1, :cluster_name))
    end)
  end
end
