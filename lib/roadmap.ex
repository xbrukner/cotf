defmodule RoadMap do
  defstruct map: nil

  def new(filename) do
    if String.ends_with?(filename, ".txt") do
      File.read!(filename)
        |> parser
    else
      File.read!(filename)
        |> parse_json()
    end
  end

  defp parser(data) do
    parser(String.split(data, "\n"), %RoadMap{map: :digraph.new}, HashDict.new, :vertices)
  end

  defp parser(["" | rest], state, sev, :vertices) do
    parser(rest, state, sev, :edges)
  end

  defp parser([v | rest], state, sev, :vertices) do
    #TODO - coordinates in the future
    label = 1 #Type
    :digraph.add_vertex(state.map, v, label)
    parser(rest, state, Dict.put_new(sev, Dict.size(sev), v), :vertices)
  end

#From vertices to edges
  defp parser(["" | _rest], state, sev, :edges) do
    {state, sev}
  end

  defp parser([e | rest], state, sev, :edges) do
    data = String.split(e, " ")
    [from, to, length] = Enum.take(data, 3)
    label = {length, 1} #1 = Type
    :digraph.add_edge(state.map, from, to, label)
    if Enum.count(data) == 3 do #Two way
      :digraph.add_edge(state.map, to, from, label)
    end
    parser(rest, state, sev, :edges)
  end

  defp parser(_, state, sev, _) do
    {state, sev}
  end

  def vertices(%RoadMap{} = map) do
    :digraph.vertices(map.map)
  end

  def edges(%RoadMap{} = map) do
    :digraph.edges(map.map)
      |> Enum.map(&correct_edges(map, &1))
  end

  def edges(%RoadMap{} = map, from) do
    :digraph.out_edges(map.map, from)
      |> Enum.map(&correct_edges(map, &1))
  end

  defp correct_edges(map, e) do
    {_edge, from, to, {length, type}} = :digraph.edge(map.map, e)
    {from, to, length, type}
  end

  def length_type(%RoadMap{} = map, from, to) do
    {_from, _to, length, type} = RoadMap.edges(map, from) #Outgoing
      |> Enum.find(fn ({_f, t, _l, _t}) -> t == to end) #Find this one
    length = if is_float(length) do
      length
    else
      Float.parse(length) #Parse to {float, rest}
        |> elem(0) #Choose float
    end
    {length, type}
  end

  def vertex_type(%RoadMap{} = map, vertex) do
    :digraph.vertex(map.map, vertex)
      |> elem(1)
  end

#JSON parser
  defp parse_json(json_text) do
    {:ok, json} = JSON.decode(json_text)
    features = json["features"]

#{types_of_highway, max_speeds, geometry_types} = extract_3_info(features, %{}, %{}, %{})
#    IO.inspect {"types:", types_of_highway}
#    IO.inspect {"speeds:", max_speeds}
#    IO.inspect {"geometry:", geometry_types}

#Phase 1: extract points
    points = extract_points(features, HashDict.new())

#Phase 2: create map
    {map, residential} = extract_roads(features, points, :digraph.new(), HashDict.new())

#Phase 3: find largest strongly connected component
    scc = :digraph_utils.strong_components(map)

#Phase 4: filter by largest
    largest = Enum.max_by(scc, &Enum.count/1)
    {map2, residential2} = scc_map(map, largest, residential)
    :digraph.delete(map)
    {%RoadMap{map: map2}, residential2}
  end

  defp scc_map(map, largest, residential) do
    map2 = :digraph.new()

#Copy vertices and residential
    residential2 = Enum.reduce(largest, HashDict.new(), fn (v, acc) ->
        :digraph.add_vertex(map2, v, elem(:digraph.vertex(map, v), 1))
        if Dict.has_key?(residential, v) do
          Dict.put_new(acc, Dict.size(acc), v)
        else
          acc
        end
    end)
#Copy edges
    for v <- largest do
      for e <- :digraph.out_edges(map, v) do
        {_, ^v, v2, label} = :digraph.edge(map, e)
        if :digraph.vertex(map2, v2) != false do
          :digraph.add_edge(map2, v, v2, label)
        end
      end
    end
    {map2, residential2}
  end

  defp extract_roads([], _points, map, residential) do
    {map, residential}
  end

  defp extract_roads([feature | features], points, map, residential) do
    if String.starts_with?(feature["id"], "way/") do
      geometry = feature["geometry"]
      if Dict.has_key?(geometry, "coordinates") and Dict.has_key?(feature, "properties") do
        p = if geometry["type"] == "Polygon" do
          hd(geometry["coordinates"])
        else
          geometry["coordinates"]
        end

        start_p = point_to_tuple Kernel.hd(p)
        end_p = point_to_tuple List.last(p)
        {vt, et} = types_for_highway_and_speed(feature["properties"])
        #Create start and end point
        if :digraph.vertex(map, start_p) == false do
          :digraph.add_vertex(map, start_p, vt)
        end
        if :digraph.vertex(map, end_p) == false do
          :digraph.add_vertex(map, end_p, vt)
        end

        oneway = Dict.get(feature["properties"], "oneway") == "yes"

        vertices = create_edges(start_p, start_p, Kernel.tl(p), vt, et, points, map, oneway, [], 0)
        residential2 = if Dict.get(feature["properties"], "highway") == "residential" do
          Enum.reduce(vertices, residential, fn (v, res) -> Dict.put_new(res, v, 0) end)
          |> Dict.put_new(start_p, 0)
          |> Dict.put_new(end_p, 0)
        else
          residential
        end
        extract_roads(features, points, map, residential2)
      else
        extract_roads(features, points, map, residential)
      end
    else
      extract_roads(features, points, map, residential)
    end
  end

  defp point_to_tuple([long, lat]) do
    {long, lat}
  end

  defp pt_distance({long1, lat1}, {long2, lat2}) do
    :haversine.distance(long1, lat1, long2, lat2)
  end

  defp create_edges(from, prev_pt, [end_point], _vt, et, _points, map, oneway, vertices, distance) do
    pt = point_to_tuple(end_point)
    :digraph.add_edge(map, from, pt, {distance + pt_distance(prev_pt, pt), et})
    if not oneway do
      :digraph.add_edge(map, pt, from, {distance + pt_distance(prev_pt, pt), et})
    end
    vertices
  end

  defp create_edges(from, prev_pt, [next_point | rest], vt, et, points, map, oneway, vertices, distance) do
    pt = point_to_tuple(next_point)
    if Dict.fetch!(points, pt) == 1 do
      #Point is there multiple times
      if :digraph.vertex(map, pt) == false do
        :digraph.add_vertex(map, pt, vt)
      end
      :digraph.add_edge(map, from, pt, {distance + pt_distance(prev_pt, pt), et})
      if not oneway do
        :digraph.add_edge(map, pt, from, {distance + pt_distance(prev_pt, pt), et})
      end
      create_edges(pt, pt, rest, vt, et, points, map, oneway, [pt] ++ vertices, 0)
    else
      #Point is not there; add distance
      create_edges(from, pt, rest, vt, et, points, map, oneway, vertices, distance + pt_distance(prev_pt, pt))
    end
  end

  defp extract_points([], points) do
    points
  end

  defp extract_points([feature | features], points) do
    if String.starts_with?(feature["id"], "way/") do
      geometry = feature["geometry"]
      if Dict.has_key?(geometry, "coordinates") do
        p = if geometry["type"] == "Polygon" do
          hd(geometry["coordinates"])
        else
          geometry["coordinates"]
        end
        points2 = Enum.reduce(p, points, fn ([long, lat], acc) when is_float(long) and is_float(lat) ->
            Dict.update(acc, {long, lat}, 0, fn _ -> 1 end)
          end)
        extract_points(features, points2)
      else
        extract_points(features, points)
      end
    else
      extract_points(features, points)
    end
  end

if false do #No longer needed, for debug only (see parse_json)
  defp extract_3_info([], tof, ms, gt) do
    {tof, ms, gt}
  end
  defp extract_3_info([feature | features], tof, ms, gt) do
    if String.starts_with?(feature["id"], "way/") do
      properties = feature["properties"]
      geometry = feature["geometry"]

      tof2 = if Dict.has_key?(properties, "highway") do
        Dict.put_new(tof, properties["highway"] , 1)
      else
        tof
      end

      ms2 = if Dict.has_key?(properties, "maxspeed") do
        Dict.put_new(ms, properties["maxspeed"] , 1)
      else
        ms
      end


      gt2 = if Dict.has_key?(geometry, "type") do
        Dict.put_new(gt, geometry["type"] , 1)
      else
        gt
      end

      {vt, et} = types_for_highway_and_speed(properties)
      true = vt == 1 or vt == 2
      true = et >= 1 and et <= 4
      extract_3_info(features, tof2, ms2, gt2)
    else
      extract_3_info(features, tof, ms, gt)
    end
  end
end


  defp types_for_highway_and_speed(properties) do
    types_for_highway_and_speed(Dict.get(properties, "highway"), Dict.get(properties, "maxspeed"))
  end

#Default
  defp types_for_highway_and_speed(nil, nil) do
    {2, 4}
  end

#From type
  defp types_for_highway_and_speed(highway, nil) do
    types = %{
        "bridleway" => {2, 4}, "living_street" =>{2, 4}, "motorway" => {1, 1},
   "motorway_link" => {1, 1}, "primary" => {1, 1}, "proposed" => {2, 4}, "residential" =>{2, 4},
   "rest_area" => {2, 4}, "road" => {2, 4}, "secondary" =>{2, 2}, "secondary_link" => {2, 2},
   "steps" => {2, 4}, "tertiary" =>{2, 3}, "trunk" =>{1, 1}, "trunk_link" =>{1, 1}
    }
    Dict.fetch!(types, highway)
  end

#From speed
  defp types_for_highway_and_speed(_, speed) do
    speed = Integer.parse(speed)
      |> elem(0)
    cond do
      speed <= 45 -> {2, 4}
      speed <= 55 -> {2, 3}
      speed <= 65 -> {2, 2}
      true        -> {1, 1}
    end
  end
end
