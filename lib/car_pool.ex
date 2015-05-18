defmodule CarPool do
  @car_pool_size 40

  def calculation(objects, fun, resource) do
    {:ok, agent} = Agent.start_link(fn -> objects end)

    fun = if resource do
      fn _ -> Task.async(fn -> car_calculation_resource(agent, fun) end) end
    else
      fn _ -> Task.async(fn -> car_calculation(agent, fun) end) end
    end

    Enum.map(1..@car_pool_size, fun)
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

  defp car_calculation_resource(agent, fun) do
    car_calculation_resource(agent, fun, Planner.Resource.new())
  end

  defp car_calculation_resource(agent, fun, resource) do
    case Agent.get_and_update(agent, &agent_fn/1) do
      nil ->
        Planner.Resource.delete(resource)
        :ok
      car ->
        fun.(car, resource)
        Planner.Resource.clear(resource)
        car_calculation_resource(agent, fun, resource)
    end
  end

  defp agent_fn(s) do
    case s do
      [car | rest] -> {car, rest}
      []           -> {nil, []}
    end
  end
end
