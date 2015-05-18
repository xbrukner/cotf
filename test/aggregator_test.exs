defmodule AggregatorTest do
  use ExUnit.Case

  test "Aggregator can start from global" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 10 }
    g = %{ g | planner: Planner.new(g), oracle: Oracle.new(g) }

    Aggregator.new(g)
#assert Process.alive?(a)
  end

  test "Aggregator can insert time" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 10}
    g = %{ g | planner: Planner.new(g), oracle: Oracle.new(g) }

    a = Aggregator.new(g)

    Aggregator.insert(a, {"A", "B", "C", 5, 10})
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B"}) == %{1 => 1}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 1}

    Aggregator.insert(a, {"A", "B", "C", 5, 10})
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B"}) == %{1 => 2}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 2}

    Aggregator.insert(a, {"A", "B", "C", 10, 3})
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B"}) == %{0 => 1, 1 => 2}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 2, 1 => 1}
  end

  test "Aggregator can submit to Oracle" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 60}
    g = %{ g | planner: Planner.new(g), oracle: Oracle.new(g) }

    a = Aggregator.new(g)

    Aggregator.insert(a, {"A", "B", "C", 0, 60})
    Aggregator.insert(a, {"A", "B", "C", 0, 60})
    Aggregator.insert(a, {"A", "B", "C", 0, 60})

    Aggregator.calculate_delay(a)
    assert Oracle.vertex_time(g.oracle, "A", "B", 60) == 7.894736842105264
    assert Oracle.edge_time(g.oracle, "A", "B", 0) == 259.6982679546131
  end

  test "Aggregator can insert, update and delete" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 10}
    g = %{ g | planner: Planner.new(g), oracle: Oracle.new(g) }

    a = Aggregator.new(g)

    Aggregator.insert(a, {"A", "B", "C", 5, 10})
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B"}) == %{1 => 1}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 1}

    Aggregator.insert(a, {"A", "B", "C", 5, 10})
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B"}) == %{1 => 2}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 2}

    Aggregator.insert(a, {"A", "B", "C", 10, 3})
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B"}) == %{0 => 1, 1 => 2}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 2, 1 => 1}

    Aggregator.delete(a, {"A", "B", "C", 5, 10})
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B"}) == %{0 => 1, 1 => 1}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 1, 1 => 1}

    Aggregator.update(a, {"A", "B", "C", 5, 10}, {"A", "B", "D", 10, 3})
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B"}) == %{0 => 2, 1 => 0}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 0, 1 => 2}
  end

  test "Aggregator can compare" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 10}
    g = %{ g | planner: Planner.new(g), oracle: Oracle.new(g) }

    a = Aggregator.new(g)

    Aggregator.insert(a, {"A", "B", "C", 5, 10})
    info = Aggregator.get_info(a)
    assert Aggregator.compare(a, info) == true

    Aggregator.insert(a, {"A", "B", "C", 5, 10})
    assert Aggregator.compare(a, info) == false
  end
end
