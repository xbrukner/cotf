defmodule SingleDelayTest do
  use ExUnit.Case

  test "Can calculate single delay for segment" do
    #Sample test
    m = RoadMap.new("sample_map.txt")
    g = %Global{map: m}

    assert SingleDelay.segment(g, 30, "B", "C") == 180
  end

  test "Can calculate single delay for junction" do
    #Sample test
    m = RoadMap.new("sample_map.txt")
    g = %Global{map: m}

    assert SingleDelay.junction(g, 30, "A", "B", "C") == 0
  end
end
