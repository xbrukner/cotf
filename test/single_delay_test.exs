defmodule SingleDelayTest do
  use ExUnit.Case

  test "Can calculate single delay for segment" do
    #Sample test
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 3600}

    assert {84.22566746561448, 170.96925952980862} = SingleDelay.segment_calculation(3600, 1, 4, 1)
    assert {67.8427013410161, 212.25569907096403} = SingleDelay.segment_calculation(3600, 1, 4, 2)
    assert {57.081941047921525, 252.2689266630034} = SingleDelay.segment_calculation(3600, 1, 4, 3)
    assert {46.426378180726644, 310.1684982607148} = SingleDelay.segment_calculation(3600, 1, 4, 4)

    assert SingleDelay.segment(g, 1, "B", "C") == 170.96925952980862

    #From segments.pdf
    assert SingleDelay.segment_calculation(60, 20, 1, 1) == {76.79271510064996, 46.87944677150151}

  end

  test "Can calculate single delay for junction" do
    #Sample test
    {m, _sev} = RoadMap.new("sample_map.txt")
    g = %Global{map: m, tf_duration: 60}

    assert_in_delta SingleDelay.junction(g, 1, "A", "B"), 7.627118644, 0.0001
    assert_in_delta SingleDelay.junction(g, 10, "A", "B"), 9, 0.0001
    assert_in_delta SingleDelay.junction(g, 15, "A", "B"), 10, 0.0001
    assert_in_delta SingleDelay.junction(g, 20, "A", "B"), 11.25, 0.0001
    assert_in_delta SingleDelay.junction(g, 25, "A", "B"), 21.59324539, 0.0001
    assert_in_delta SingleDelay.junction(g, 30, "A", "B"), 41.83281573, 0.0001
    assert_in_delta SingleDelay.junction(g, 40, "A", "B"), 64.10215414, 0.0001
    assert_in_delta SingleDelay.junction(g, 60, "A", "B"), 97.41661517, 0.0001

  end
end
