defmodule LocationTest do
  use ExUnit.Case

  test "Location can be an intersection" do
    l = Location.new(:in_vertex, "A")

    assert l.type == :in_vertex
    assert l.vertex == "A"
  end

  test "Location can be on the edge" do
    l = Location.new(:on_edge, "A", "B", 10)

    assert l.type == :on_edge
    assert l.from == "A"
    assert l.to == "B"
    assert l.distance == 10
  end
end
