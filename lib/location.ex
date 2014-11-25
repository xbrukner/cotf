defmodule Location do
  defstruct type: nil, vertex: nil, from: nil, to: nil, distance: nil

  def new(:in_vertex, where) do
    %Location{type: :in_vertex, vertex: where}
  end
  
  def new(:on_edge, from, to, distance) do
    %Location{type: :on_edge, from: from, to: to, distance: distance}
  end

end

