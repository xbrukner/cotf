defmodule Global do
  defstruct oracle: nil, map: nil, planner: nil, aggregator: nil, tf_duration: 0

  def timeframe_fn(global) do
    fn (time) when is_float(time) ->
      time = Float.floor(time)
        |> round
      div time, global.tf_duration
      (time) when is_integer(time) ->
      div time, global.tf_duration
    end
  end
end
