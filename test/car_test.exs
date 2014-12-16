defmodule CarTest do
  use ExUnit.Case

  test "Car has current location, starting time and finish" do
    c = Car.new("A", 20, "B", nil)

    assert Kernel.match? %Car{from: "A", start_time: 20, to: "B"}, Car.get_info(c)

  end

  test "Car can calculate route from global" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 60}
    g = %Global{ g | oracle: Oracle.new(g) }
    g = %{ g | planner: Planner.new(g)}
    Oracle.calculate_default(g.oracle)

    c = Car.new("A", 20, "B", g)

    :ok = Car.calculate_plan(c)
    info = Car.get_info(c)
    
    assert info.plan == %Plan{from: "A", steps: [{"B", 20, 276.90093903679565}], time: 256.90093903679565, to: "B"}
  end

  test "Car can submit the road to Aggregator" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 1}
    g = %Global{ g | oracle: Oracle.new(g) }
    g = %{ g | planner: Planner.new(g), aggregator: Aggregator.new(g)}
    Oracle.calculate_default(g.oracle)

    c = Car.new("A", 0, "H", g)

    :ok = Car.calculate_plan(c)
    :ok = Car.send_plan(c)
    
    info = Aggregator.get_info(g.aggregator)
    assert Dict.get(info.junctions, {"A", "G"}) == %{1909 => 1}
    assert Dict.get(info.junctions, {"G", "I"}) == %{2468 => 1}
    assert Dict.get(info.segments, {"I", "H"}) == %{2549 => 1}
    assert Dict.get(info.segments, {"G", "I"}) == %{1990 => 1}
    assert Dict.get(info.segments, {"A", "G"}) == %{0 => 1}
  end

  test "Car can calculate time twice" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 60}
    g = %Global{ g | oracle: Oracle.new(g), aggregator: Aggregator.new(g) }
    g = %{ g | planner: Planner.new(g)}
    Oracle.calculate_default(g.oracle)

    c = Car.new("A", 20, "B", g)

    :ok = Car.calculate_plan(c)
    ci1 = Car.get_info(c)
    ai1 = Aggregator.get_info(g.aggregator)
    :ok = Car.calculate_plan(c)
    ci2 = Car.get_info(c)
    ai2 = Aggregator.get_info(g.aggregator)

    assert ci1.plan == ci2.orig_plan #Recalculation of times would happen here
    assert ai1.junctions == ai2.junctions
    assert ai2.segments == ai2.segments
  end
end
