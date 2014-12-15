defmodule OracleTest do
  use ExUnit.Case

  test "Can calculate default data" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60} 
    o = Oracle.new(g)
    Oracle.calculate_default(o)
  end

  test "Can give time for segment" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60} 
    o = Oracle.new(g)
    Oracle.calculate_default(o)

    assert Oracle.edge_time(o, "A", "B", 4) == 256.90093903679565
    assert Oracle.edge_time(o, "A", "B", 0) == 256.90093903679565
  end

  test "Can give time for junction" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60} 
    o = Oracle.new(g)
    Oracle.calculate_default(o)
    
    assert Oracle.vertex_time(o, "A", "B", "C", 4) == 7.627118644067797
    assert Oracle.vertex_time(o, "A", "B", "C", 5) == 7.627118644067797
  end

  test "Zero time for starting vertex" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60} 
    o = Oracle.new(g)

    assert Oracle.vertex_time(o, nil, "A", "B", 3) == 0
   end 
end
