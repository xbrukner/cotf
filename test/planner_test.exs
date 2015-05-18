defmodule PlannerTest do
  use ExUnit.Case

  test "Can be created from RoadMap and Oracle" do
    {map, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: map, tf_duration: 60 }
    oracle = Oracle.new(g)

    planner = Planner.new(map, oracle)
    assert %Planner{} = planner
  end

  test "Can be created from Global" do
    {map, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: map, tf_duration: 60 }
    global = %{ g | oracle: Oracle.new(g) }

    planner = Planner.new(global)
    assert %Planner{} = planner
  end

  test "Can find a route with one edge" do
    {map, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: map, tf_duration: 60 }
    oracle = Oracle.new(g)
    Oracle.calculate_default(oracle)

    planner = Planner.new(map, oracle)

    resource = Planner.Resource.new()
    plan = Planner.route(planner, resource, "A", "B", 10)
    Planner.Resource.delete(resource)
    assert plan.steps == [ {"B", 10, 267.49727688893444} ]
    assert plan.time == 257.49727688893444
  end

  test "Can find more complex route" do
    {map, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: map, tf_duration: 60 }
    oracle = Oracle.new(g)
    Oracle.calculate_default(oracle)

    planner = Planner.new(map, oracle)

    resource = Planner.Resource.new()
    plan = Planner.route(planner, resource, "A", "H", 0)
    Planner.Resource.delete(resource)
    assert plan.steps ==
#Almost - float imprecision [{"G", 0, 171.8636305433359},
#            {"I", 171.8636305433359 + 7.627118644067797, 171.8636305433359 + 7.627118644067797 + 43.41316102493807},
#            {"H", 171.8636305433359 + 7.627118644067797 * 2 + 43.41316102493807, 171.8636305433359 + 7.627118644067797 * 2 + 43.41316102493807 * 2}]
    [{"G", 0, 171.8636305433359},
            {"I", 179.49074918740368, 222.90391021234174},
            {"H", 230.53102885640956, 273.94418988134765}]
    assert plan.time == 273.94418988134765
  end

  test "Planner can reuse resource" do
    {map, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{ map: map, tf_duration: 60 }
    oracle = Oracle.new(g)
    Oracle.calculate_default(oracle)

    planner = Planner.new(map, oracle)
    resource = Planner.Resource.new()
    plan = Planner.route(planner, resource, "A", "H", 0)
    assert plan.steps ==
#Almost - float imprecision [{"G", 0, 171.8636305433359},
#            {"I", 171.8636305433359 + 7.627118644067797, 171.8636305433359 + 7.627118644067797 + 43.41316102493807},
#            {"H", 171.8636305433359 + 7.627118644067797 * 2 + 43.41316102493807, 171.8636305433359 + 7.627118644067797 * 2 + 43.41316102493807 * 2}]
    [{"G", 0, 171.8636305433359},
            {"I", 179.49074918740368, 222.90391021234174},
            {"H", 230.53102885640956, 273.94418988134765}]
    assert plan.time == 273.94418988134765

    Planner.Resource.clear(resource)

    plan = Planner.route(planner, resource, "A", "B", 10)
    Planner.Resource.delete(resource)
    assert plan.steps == [ {"B", 10, 267.49727688893444} ]
    assert plan.time == 257.49727688893444
  end
end
