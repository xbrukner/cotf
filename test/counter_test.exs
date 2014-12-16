defmodule CounterTest do
  use ExUnit.Case

  test "Counter can be started with callback" do
    {:ok, a} = Agent.start_link(fn -> false end)
    Counter.new(fn(_) -> Agent.update(a, fn(_) -> true end) end)

    assert Agent.get(a, &(&1)) == false

    Agent.stop(a)
  end

  test "Counter does not stop until all started" do
    me = self()
    c = Counter.new(fn(count) -> send me, {:count, count} end)
    Counter.started(c)
    Counter.finished(c)

    refute_received {:count, _}
    Counter.all_started(c)
    assert_receive {:count, 1}
  end

  test "Counter does not stop until all received" do
    me = self()
    c = Counter.new(fn(count) -> send me, {:count, count} end)
    Counter.started(c)
    Counter.started(c)
    Counter.started(c)
    Counter.started(c)
    Counter.finished(c)

    refute_received {:count, _}
    Counter.all_started(c)
    refute_received {:count, _}

    Counter.finished(c)
    Counter.finished(c)
    Counter.finished(c)
    assert_receive {:count, 4}
  end

  test "Counter can spawn" do
    me = self()
    
    c = Counter.new(fn(count) -> send me, {:count, count} end)
    Counter.spawn(c, fn -> send me, :called end)
    
    assert_receive :called

    Counter.spawn(c, fn -> :result end, fn (v) -> send me, v end)
    assert_receive :result

    Counter.all_started(c)
    assert_receive {:count, 2}
  end
end
