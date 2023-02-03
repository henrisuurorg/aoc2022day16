defmodule PartA do
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
    big = 100_000
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

  def max_pressure(_, _, closed, _, _, memory) when length(closed) == 0 do
    {0, memory}
  end

  def max_pressure(time, position, closed, rate, dist, memory) do
    case Map.get(memory, {time, closed}) do
      nil ->
        Enum.reduce(closed, {memory, 0}, fn next, {memory, acc} ->
          next_time = time + dist[{position, next}] + 1

          if next_time >= 26 do
            {memory, acc}
          else
            next_pressure = (26 - next_time) * rate[next]
            next_closed = List.delete(closed, next)

            {memory, next_res} = max_pressure(next_time, next, next_closed, rate, dist, memory)

            res = max(acc, next_res + next_pressure)
            {Map.put(memory, {time, closed}, res), res}
          end
        end)

      val ->
        {memory, val}
    end
  end

  def main() do
    {id, list} = parse_input()
    n = map_size(id)
    dist = shortest_paths(list, n)
    rate = flow_rate(list)

    closed = Enum.map(Enum.filter(rate, fn {_, r} -> r > 0 end), fn {valve, _} -> valve end)

    {_, max} = max_pressure(0, Map.get(id, :AA), closed, rate, dist, Map.new())
    max
  end
end
