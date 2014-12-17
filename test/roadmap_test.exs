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

    assert RoadMap.length_type(m, "A", "B") == {6, 1}

    assert Dict.equal? RoadMap.get_start_end_vertices(m),
        %{0 => "A", 1 => "B", 2 => "C", 3 => "D", 4 => "E", 5 => "F", 6 => "G", 7 => "H", 8 => "I"}
  end
end

