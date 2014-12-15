defmodule DelayTest do
  use ExUnit.Case

  test "Junction delay" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60}
    cars = %{0 => 30, 1 => 4, 3 => 20}

#Check if needed
    assert Delay.junction(g, "A", "B", cars) == %{0 => 41.83281572999747, 1 => 8.035714285714285,
             3 => 11.249999999999998}
  end

  test "Segment delay" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60}
    cars = %{0 => 10, 1 => 20, 2 => 30, 3 => 10, 4 => 10}

#Modified to reflect float arithmetics of elixir
    assert Delay.segment(g, "A", "B", cars) == 
      #1 => 91->904, 3 => 264->26
      %{0 => 262.9604253728268, 1 => 281.2766806290091, 2 => 422.65292781515166, 3 => 402.1626186909926, 4 => 334.8422065254472} 
  end
end
