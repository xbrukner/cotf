defmodule PlanTest do
  use ExUnit.Case

  test "Can create empty plan" do
    p = Plan.new("A", "B", 3)

    assert p.from == "A"
    assert p.to == "B"
    assert p.time == 3
  end

  test "Plan can have a few steps" do
    p = Plan.new("A", "D", 21)

    p = Plan.prependStep(p, "D", 3, 6)
    p = Plan.prependStep(p, "C", 2, 5)
    p = Plan.prependStep(p, "B", 1, 4)

    assert p.steps == [ {"B", 4, 1}, {"C", 5, 2}, {"D", 6, 3} ]
  end

  test "Plan can calculate length" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{map: m}
    p = Plan.new("A", "F", 21)

    p = Plan.prependStep(p, "F", 3, 6)
    p = Plan.prependStep(p, "C", 2, 5)
    p = Plan.prependStep(p, "B", 1, 4)
    
    assert Plan.calculateLength(g, p) == 6 + 4 + 2
  end
end
