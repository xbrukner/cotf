defmodule Delay do
  def junction(global, from, via, cars) do
    delayfn = &(SingleDelay.junction(global, &1, from, via))
    durations = Enum.map(cars, fn({tf, cars}) -> {tf, delayfn.(cars)} end)

    reducefn = &(junction(global.tf_duration, &1, &2))
    Enum.reduce(durations, { {-1, 0}, %{} }, reducefn)
      |> elem(1)
  end

  defp junction(tf_duration, {tf, duration}, { {last_tf, last_delay}, res}) do
    overflow = last_delay - (tf - last_tf) * tf_duration
    altered_duration = duration + if overflow > 0 do overflow else 0 end
    
    { {tf, altered_duration}, Dict.put_new(res, tf, altered_duration) }
  end
end

