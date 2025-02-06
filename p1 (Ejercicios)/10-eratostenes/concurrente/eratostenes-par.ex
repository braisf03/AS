defmodule Eratostenes do

    defp range(n) when n >= 2 do
        range(2, n)
    end

    defp range(current, max) when current <= max do
        [current | range(current + 1, max)]
    end

    defp range(_current, _max) do
        []
    end

    defp loop(:filtro, n, next) do
        receive do
            {:return, pid} -> send(next, {:return, pid})
            num when rem(num, n) != 0 -> send(next, num)
                                         loop(:filtro, n, next)
            _num -> loop(:filtro, n, next)
        end
    end

    defp loop(:cola, list) do
        receive do
            {:return, pid} -> send(pid, list)
            num -> loop(:filtro, num, spawn(fn -> loop(:cola, [num|list]) end))
        end

    end

    defp criba([], next) do
      send(next, {:return, self()})
      receive do
        list -> list
      end

    end

    defp criba([h|t], next) do
        send(next, h)
        criba(t, next)
    end

    def primos(n) do
        Enum.reverse(criba(range(n), spawn(fn -> loop(:cola, []) end)))
    end

end
