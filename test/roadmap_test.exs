defmodule RoadMapTest do
  use ExUnit.Case, async: true

  test "Can load map from file" do
    {m, sev} = RoadMap.new("sample_map.txt")

    assert RoadMap.vertices(m) |>
      Enum.count == 9

    assert RoadMap.edges(m) |>
      Enum.count == 27

    assert RoadMap.edges(m, "I") |>
      Enum.count == 2

    assert RoadMap.edges(m, "D") |>
      Enum.count == 5

    assert RoadMap.length_type(m, "A", "B") == {6, 1}

    assert Dict.equal? sev,
        %{0 => "A", 1 => "B", 2 => "C", 3 => "D", 4 => "E", 5 => "F", 6 => "G", 7 => "H", 8 => "I"}
  end

  test "Can load JSON file small" do
    {_m, sev} = RoadMap.new("aalborg_small_output.json")
    assert Dict.size(sev) == 4120
  end

  test "Can load JSON file large" do
    {_m, sev} = RoadMap.new("aalborg_large_output.json")
    assert Dict.size(sev) == 7803
  end
end
