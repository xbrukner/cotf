defmodule RoadMapTest do
  use ExUnit.Case

  test "Can load map from file" do
    m = RoadMap.new("sample_map.txt")

    assert RoadMap.vertices(m) |>
      Enum.count == 9

    assert RoadMap.edges(m) |>
      Enum.count == 27

    assert RoadMap.edges(m, "I") |>
      Enum.count == 2

    assert RoadMap.edges(m, "D") |>
      Enum.count == 5
  end
end

