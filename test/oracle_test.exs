defmodule OracleTest do
  use ExUnit.Case

  test "Can give time for segment" do
    m = RoadMap.new("sample_map.txt")
    o = Oracle.new(m)

    assert Oracle.edge_time(o, "A", "B", 4) == 6
    assert Oracle.edge_time(o, "A", "B", 0) == 6
  end

  test "Can give time for junction" do
    m = RoadMap.new("sample_map.txt")
    o = Oracle.new(m)
    
    assert Oracle.vertex_time(o, "A", "B", "C", 4) == 1
    assert Oracle.vertex_time(o, "A", "B", "C", 5) == 1
  end

  test "Zero time for starting vertex" do
    m = RoadMap.new("sample_map.txt")
    o = Oracle.new(m)

    assert Oracle.vertex_time(o, nil, "A", "B", 3) == 0
   end 
end
