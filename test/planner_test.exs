defmodule PlannerTest do
  use ExUnit.Case

  test "Can be created from RoadMap and Oracle" do
    map = RoadMap.new("sample_map.txt")
    oracle = Oracle.new(map)
    
    planner = Planner.new(map, oracle)
    assert %Planner{} = planner
  end

  test "Can find a route with one edge" do
    map = RoadMap.new("sample_map.txt")
    oracle = Oracle.new(map)

    planner = Planner.new(map, oracle)
    
    plan = Planner.route(planner, "A", "B")
    assert plan.steps == [ {"B", 0, 6} ]
    assert plan.time == 6
  end
  
  test "Can find more complex route" do
    map = RoadMap.new("sample_map.txt")
    oracle = Oracle.new(map)

    planner = Planner.new(map, oracle)
    
    plan = Planner.route(planner, "A", "H")
    assert plan.steps == [ {"G", 0, 4}, {"I", 1, 1}, {"H", 1, 1} ]
    assert plan.time == 8
  end
end
