defmodule AggregatorTest do
  use ExUnit.Case

  test "Aggregator can start from global" do
    m = RoadMap.new("sample_map.txt")
    o = Oracle.new(m)
    g = %Global{ map: m, oracle: o, timeframe: &(div(&1, 10)) }
    g = %{ g | planner: Planner.new(g) }

    a = Aggregator.new(g)
    assert Process.alive?(a)
  end

  test "Aggregator can insert time" do
    m = RoadMap.new("sample_map.txt")
    o = Oracle.new(m)
    g = %Global{ map: m, oracle: o, timeframe: &(div(&1, 10))}
    g = %{ g | planner: Planner.new(g) }

    a = Aggregator.new(g)
  
    Aggregator.insert(a, "A", "B", "C", 5, 10)
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B", "C"}) == %{1 => 1}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 1}

    Aggregator.insert(a, "A", "B", "C", 5, 10)
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B", "C"}) == %{1 => 2}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 2}

    Aggregator.insert(a, "A", "B", "C", 10, 3)
    info = Aggregator.get_info(a)
    assert Dict.get(info.junctions, {"A", "B", "C"}) == %{0 => 1, 1 => 2}
    assert Dict.get(info.segments, {"A", "B"}) == %{0 => 2, 1 => 1}
  end
end