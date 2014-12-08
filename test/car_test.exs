defmodule CarTest do
  use ExUnit.Case

  test "Car has current location, starting time and finish" do
    c = Car.new("A", 20, "B", nil)

    assert %Car{from: "A", start_time: 20, to: "B"} == Car.get_info(c)

  end

  test "Car can calculate route from planner" do
    m = RoadMap.new("sample_map.txt")
    o = Oracle.new(m)
    p = Planner.new(m, o)

    c = Car.new("A", 20, "B", p)

    :ok = Car.calculate_plan(c)
    info = Car.get_info(c)
    
    assert info.plan == %Plan{from: "A", steps: [{"B", 0, 6}], time: 6, to: "B"}
  end
end
