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

  test "Plan can recalculate times" do
    m = RoadMap.new("sample_map.txt")
    g = %Global{ map: m, tf_duration: 60 }
    g = %Global{ g | oracle: Oracle.new(g) }
    Oracle.calculate_default(g.oracle)
  
    p = Plan.new("A", "H", 21)

    p = Plan.prependStep(p, "H", 1, 4)
    p = Plan.prependStep(p, "I", 2, 5)
    p = Plan.prependStep(p, "G", 3, 0)
    
    p2 = Plan.updateTimes(g, p)
    assert p2.steps == [{"G", 0, 171.2672926911971},
            {"I", 171.2672926911971 + 7.627118644067797, 171.2672926911971 + 7.627118644067797 + 42.816823172799275},
            {"H", 171.2672926911971 + 7.627118644067797 * 2 + 42.816823172799275, 171.2672926911971 + 7.627118644067797 * 2 + 42.816823172799275 * 2}]
    assert p2.time == 272.15517632493123
  end
end
