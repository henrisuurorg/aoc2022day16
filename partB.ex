defmodule PartB do
  use Bitwise

  def parse_input() do
    {:ok, raw} = File.read("advent16.txt")
    rows = String.split(raw, "\n", trim: true)

    # return format [{:AA, 0, [:DD, :II, :BB]}]
    list =
      Enum.map(rows, fn row ->
        [snipt1, rate, snipt2] = String.split(row, ["=", ";"], trim: true)
        [_valve, name | _rest] = String.split(snipt1, " ", trim: true)
        [_tunnels, _lead, _to, _valves | tunnels] = String.split(snipt2, " ", trim: true)
        tunnels = Enum.map(tunnels, fn x -> String.to_atom(String.replace(x, ",", "")) end)
        {String.to_atom(name), String.to_integer(rate), tunnels}
      end)

    # mapping of %{AA: 0, BB: 1}
    {ids, _} =
      Enum.reduce(list, {%{}, 1}, fn {name, _, _}, acc ->
        {map, id} = acc
        {Map.put(map, name, id), id + 1}
      end)

    # [{:AA, 0, [:DD, :II, :BB]}] -> [{0, 0, [3, 8, 1]}]
    list =
      Enum.map(list, fn {name, rate, tunnels} ->
        {Map.get(ids, name), rate, Enum.map(tunnels, fn x -> Map.get(ids, x) end)}
      end)

    {ids, list}
  end

  def shortest_paths(list, n) do
    big = 10000
    # {0, 1} => 1 mapping, distance is 0 between if i==j otherwise ~infinity
    dist = for i <- 1..n, j <- 1..n, into: %{}, do: {{i, j}, if(i == j, do: 0, else: big)}

    # add distance one between nodes that have tunnels
    dist =
      Enum.reduce(list, dist, fn {from, _, tunnels}, acc ->
        Enum.reduce(tunnels, acc, fn tunnel, acc ->
          Map.put(acc, {from, tunnel}, 1)
        end)
      end)

    # calculate shortest distance between all valves using
    dist =
      for(k <- 1..n, i <- 1..n, j <- 1..n, do: {k, i, j})
      |> Enum.reduce(dist, fn {k, i, j}, dst ->
        if dst[{i, j}] > dst[{i, k}] + dst[{k, j}] do
          Map.put(dst, {i, j}, dst[{i, k}] + dst[{k, j}])
        else
          dst
        end
      end)

    dist
  end

  def flow_rate(list) do
    Enum.reduce(list, %{}, fn {valve, rate, _}, acc ->
      Map.put(acc, valve, rate)
    end)
  end

  def max_pressure(time, position, closed, rate, dist, memory) do
    Enum.reduce(closed, memory, fn next, memory ->
      next_time = time + dist[{position, next}] + 1

      if next_time >= 26 do
        Map.put(
          memory,
          {26, closed},
          max(Map.get(memory, {26, closed}, 0), memory[{time, closed}])
        )
      else
        valve_pressure = (26 - next_time) * rate[next]
        next_closed = List.delete(closed, next)
        next_pressure = valve_pressure + memory[{time, closed}]

        next_res = max(Map.get(memory, {next_time, next_closed}, 0), next_pressure)
        memory = Map.put(memory, {next_time, next_closed}, next_res)

        if length(closed) == 0 do
          Map.put(memory, {26, closed}, memory[{next_time, next_closed}])
        else
          max_pressure(next_time, next, next_closed, rate, dist, memory)
        end
      end
    end)
  end

  def compute_max(memory, n, rate) do
    memory =
      Enum.filter(memory, fn {{time, _}, _} -> time == 26 end)
      |> Enum.uniq()
      |> Enum.map(fn {{_, closed}, pressure} ->
        opened =
          Enum.reduce(Enum.to_list(1..n), "", fn valve, acc ->
            case rate[valve] == 0 or valve in closed do
              false ->
                acc <> "1"

              true ->
                acc <> "0"
            end
          end)

        {String.to_integer(opened, 2), pressure}
      end)
      |> List.keysort(1, :desc)

    Enum.reduce(memory, 0, fn {opened1, pressure1}, acc1 ->
      Enum.reduce(memory, 0, fn {opened2, pressure2}, acc2 ->
        cond do
          pressure1 + pressure2 < acc1 -> acc1
          pressure1 + pressure2 < acc2 -> acc2
          (opened1 &&& opened2) != 0 -> acc2
          true -> pressure1 + pressure2
        end
      end)
    end)
  end

  def main() do
    {id, list} = parse_input()
    n = map_size(id)
    dist = shortest_paths(list, n)
    rate = flow_rate(list)

    closed = Enum.map(Enum.filter(rate, fn {_, r} -> r > 0 end), fn {valve, _} -> valve end)
    closed = Enum.sort(closed)

    {treeadd, _} =
      :timer.tc(fn ->
        max_pressure(
          0,
          Map.get(id, :AA),
          closed,
          rate,
          dist,
          Map.put(Map.new(), {0, closed}, 0)
        )
        |> compute_max(n, rate)
      end)
  end
end
