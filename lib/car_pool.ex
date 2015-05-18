defmodule CarPool do
  @car_pool_size 40

  def calculation(objects, fun) do
    {:ok, agent} = Agent.start_link(fn -> objects end)

    Enum.map(1..@car_pool_size, fn _ -> Task.async(fn -> car_calculation(agent, fun) end) end)
    |> Enum.map(&Task.await(&1, :infinity))

    Agent.stop(agent)
  end

  defp car_calculation(agent, fun) do
    case Agent.get_and_update(agent, &agent_fn/1) do
      nil -> :ok
      car ->
        fun.(car)
        car_calculation(agent, fun)
    end
  end

  defp agent_fn(s) do
    case s do
      [car | rest] -> {car, rest}
      []           -> {nil, []}
    end
  end
end
