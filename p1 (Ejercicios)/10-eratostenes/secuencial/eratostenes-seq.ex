defmodule Eratostenes do

    def range(n) when n >= 2 do 
        range(2, n);
    end

    defp range(n, n) do
        [n]
    end

    defp range(n, m) do
        [n | range(n+1, m)]
    end

    def filtrar_multiplos(n, [h|t]) when rem(h, n) == 0 do
        filtrar_multiplos(n, t);
    end

    def filtrar_multiplos(n, [h|t]) do
        [h |filtrar_multiplos(n, t)];
    end

    def filtrar_multiplos(_n, []) do
        []
    end

    def criba([h|t]) do
        [h|criba(filtrar_multiplos(h, t))]
    end

    def criba([]) do
        []
    end

    def primos(n) do
        criba(range(n))
    end
end