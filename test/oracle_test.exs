defmodule OracleTest do
  use ExUnit.Case

  test "Can calculate default data" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60}
    o = Oracle.new(g)
    Oracle.calculate_default(o)
  end

  test "Can give time for segment" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60}
    o = Oracle.new(g)
    Oracle.calculate_default(o)

    assert Oracle.edge_time(o, "A", "B", 4) == 257.49727688893444
    assert Oracle.edge_time(o, "A", "B", 0) == 257.49727688893444
  end

  test "Can give time for junction" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60}
    o = Oracle.new(g)
    Oracle.calculate_default(o)

    assert Oracle.vertex_time(o, "A", "B", 4) == 7.627118644067797
    assert Oracle.vertex_time(o, "A", "B", 5) == 7.627118644067797
  end

  test "Zero time for starting vertex" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60}
    o = Oracle.new(g)

    assert Oracle.vertex_time(o, nil, "A", 3) == 0
   end

  test "Can insert and delete current" do
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60}
    o = Oracle.new(g)
    Oracle.calculate_default(o)

    Oracle.current_delay_result(o, :segment, "A", "B", %{0 => 3, 3 => 5})
    Oracle.current_delay_result(o, :junction, "A", "B", %{2 => 4, 6 => 1})

    assert Oracle.edge_time(o, "A", "B", 0) == 3
    assert Oracle.edge_time(o, "A", "B", 180) == 5
    assert Oracle.vertex_time(o, "A", "B", 120) == 4
    assert Oracle.vertex_time(o, "A", "B", 360) == 1

    Oracle.reset_current(o)
    assert Oracle.edge_time(o, "A", "B", 0) == 257.49727688893444

  end
end
