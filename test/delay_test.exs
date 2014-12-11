defmodule DelayTest do
  use ExUnit.Case

  test "Junction delay" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60}
    cars = %{0 => 30, 1 => 4, 3 => 20}

#Checked manually, it calls static function now
    assert Delay.junction(g, "A", "B", cars) == %{0 => 61, 1 => 62, 3 => 61}
  end
end
