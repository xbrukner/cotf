defmodule PlannerTest do
  use ExUnit.Case

  test "Can be created from RoadMap and Oracle" do
    map = RoadMap.new("sample_map.txt")
    g = %Global{ map: map, tf_duration: 60 }
    oracle = Oracle.new(g)
    
    planner = Planner.new(map, oracle)
    assert %Planner{} = planner
  end

  test "Can be created from Global" do
    map = RoadMap.new("sample_map.txt")
    g = %Global{ map: map, tf_duration: 60 }
    global = %{ g | oracle: Oracle.new(g) }
    
    planner = Planner.new(global)
    assert %Planner{} = planner
  end

  test "Can find a route with one edge" do
    map = RoadMap.new("sample_map.txt")
    g = %Global{ map: map, tf_duration: 60 }
    oracle = Oracle.new(g)
    Oracle.calculate_default(oracle)

    planner = Planner.new(map, oracle)
    
    plan = Planner.route(planner, "A", "B", 10)
    assert plan.steps == [ {"B", 10, 266.90093903679565} ]
    assert plan.time == 256.90093903679565
  end
  
  test "Can find more complex route" do
    map = RoadMap.new("sample_map.txt")
    g = %Global{ map: map, tf_duration: 60 }
    oracle = Oracle.new(g)
    Oracle.calculate_default(oracle)

    planner = Planner.new(map, oracle)
    
    plan = Planner.route(planner, "A", "H", 0)
    assert plan.steps == [{"G", 0, 171.2672926911971},
            {"I", 171.2672926911971 + 7.627118644067797, 171.2672926911971 + 7.627118644067797 + 42.816823172799275},
            {"H", 171.2672926911971 + 7.627118644067797 * 2 + 42.816823172799275, 171.2672926911971 + 7.627118644067797 * 2 + 42.816823172799275 * 2}]
    assert plan.time == 272.15517632493123
  end
end
