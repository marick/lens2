defmodule Lens2.MostlyText.InformationHidingTest do
  use Lens2.Case, async: true
  import TypedStruct

  defmodule Cluster1 do
    typedstruct enforce: true do
      field :name, atom
      field :downstream, %{atom => MapSet.t(atom)}
    end

    def new(name, downstream \\ []),
        do: %__MODULE__{name: name, downstream: downstream}

    def_composed_maker downstream, do: Lens.key!(:downstream)
  end

  defmodule Network1 do
    typedstruct enforce: true do
      field :clusters_by_name, %{atom => Cluster1.t}
      field :other_fields, any, default: :just_for_show
    end

    def new(clusters) do
      map = for cluster <- clusters, into: %{}, do: {cluster.name, cluster}
      struct(__MODULE__, clusters_by_name: map)
    end

    def_composed_maker downstream_of(name),
      do: Lens.key!(:clusters_by_name) |> Lens.key!(name) |> Cluster1.downstream
  end


  test "cluster1 lens" do
    cluster = Cluster1.new(:root, [:branch1, :branch2])

    Deeply.get_only(cluster, Cluster1.downstream)
    |> Enum.sort
    |> assert_equal([:branch1, :branch2])

    Deeply.get_only(cluster, :downstream)
    |> Enum.sort
    |> assert_equal([:branch1, :branch2])
  end

  test "network1 lens" do
    branch1 = Cluster1.new(:branch1)
    branch2 = Cluster1.new(:branch2)
    root = Cluster1.new(:root, [:branch1, :branch2])
    network = Network1.new([branch1, branch2, root])

    Deeply.get_only(network, Network1.downstream_of(:root))
    |> Enum.sort
    |> assert_equal([:branch1, :branch2])
  end

end
