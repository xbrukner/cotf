defmodule CarTest do
  use ExUnit.Case

  test "Car has current location, starting time and finish" do
    c = Car.new("A", 20, "B", nil)

    assert Kernel.match? %Car{from: "A", start_time: 20, to: "B"}, Car.get_info(c)

  end

  test "Car can calculate route from global" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 60}
    g = %Global{ g | oracle: Oracle.new(g) }
    g = %{ g | planner: Planner.new(g)}
    Oracle.calculate_default(g.oracle)
    r = Planner.Resource.new()

    c = Car.new("A", 20, "B", g)

    :ok = Car.calculate_plan(c, r)
    info = Car.get_info(c)

    assert info.plan == %Plan{from: "A", steps: [{"B", 20, 277.49727688893444}],
            time: 257.49727688893444, to: "B"}
    Planner.Resource.delete(r)
  end

  test "Car can submit the road to Aggregator" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 1}
    g = %Global{ g | oracle: Oracle.new(g) }
    g = %{ g | planner: Planner.new(g), aggregator: Aggregator.new(g)}
    Oracle.calculate_default(g.oracle)
    r = Planner.Resource.new()

    c = Car.new("A", 0, "H", g)

    :ok = Car.calculate_and_send(c, r)

    info = Aggregator.get_info(g.aggregator)
    assert Dict.get(info.junctions, {"A", "G"}) == %{1911 => 1}
    assert Dict.get(info.junctions, {"G", "I"}) == %{2471 => 1}
    assert Dict.get(info.segments, {"I", "H"}) == %{2552 => 1}
    assert Dict.get(info.segments, {"G", "I"}) == %{1992 => 1}
    assert Dict.get(info.segments, {"A", "G"}) == %{0 => 1}
    Planner.Resource.delete(r)
  end

  test "Car can calculate time twice" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 60}
    g = %Global{ g | oracle: Oracle.new(g), aggregator: Aggregator.new(g) }
    g = %{ g | planner: Planner.new(g)}
    Oracle.calculate_default(g.oracle)
    r = Planner.Resource.new()

    c = Car.new("A", 20, "B", g)

    :ok = Car.calculate_plan(c, r)
    ci1 = Car.get_info(c)
    ai1 = Aggregator.get_info(g.aggregator)

    Planner.Resource.clear(r)
    :ok = Car.calculate_plan(c, r)
    ci2 = Car.get_info(c)
    ai2 = Aggregator.get_info(g.aggregator)

    assert ci1.plan == ci2.orig_plan #Recalculation of times would happen here
    assert ai1.junctions == ai2.junctions
    assert ai2.segments == ai2.segments
    Planner.Resource.delete(r)
  end

  test "Car can return result string" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 60}
    g = %Global{ g | oracle: Oracle.new(g), aggregator: Aggregator.new(g) }
    g = %{ g | planner: Planner.new(g)}
    Oracle.calculate_default(g.oracle)
    r = Planner.Resource.new()

    c = Car.new("A", 20, "B", g)

    :ok = Car.calculate_plan(c, r)
    Planner.Resource.clear(r)
    :ok = Car.calculate_plan(c, r)
    assert Car.result(c) == "\"A\",\"B\",20,257.49727688893444,6.0,257.49727688893444,6.0"
    Planner.Resource.delete(r)
 end
end
