defmodule Trabajador do

  def loop do
    receive do
      {:trabajo, from, batch, {func, index},} when is_function(func) ->
        result = func.()
        send(from, {:done, self(), batch, index, result})
        loop()

      {:trabajo, from, _batch, _} ->
        send(from, {self(), {:error, :invalid_function}})
        loop()

      :stop -> :ok

      _ ->
        loop()  # Manejo de mensajes inesperados
    end
  end
end

defmodule Servidor do
  #defp start(0, list) do
    #spawn(fn -> loop(list, %{}, 0, 0) end)
  #end

  #defp start(n, list) do
   # start(n - 1, [spawn(fn -> Trabajador.loop() end)|list])
  #end

  def start(n) do
    spawn(fn -> startLoop(n, []) end)
  end

  defp startLoop(0, list) do
    loop(list, %{}, 0, 0)
  end

  defp startLoop(n, list) do
    startLoop(n - 1, [spawn(fn -> Trabajador.loop() end)|list])
  end



  defp loop(workers, jobs_queue, current_batch, next_id) do #Current batch representa el lote actual del que se tomarán trabajos para enviarlos a los trabajadores, next_id será el id del próximo lote que se reciba
    receive do
      {:trabajos, from, jobs} ->
        if Enum.all?(jobs, &is_function/1) do
          indexed_jobs = Enum.with_index(jobs)
          {workers_left, jobs_left} = assign_jobs(workers, indexed_jobs, next_id)
          if jobs_left == [] do #Si se asignaron todos los trabajos, se aumenta en 1 el lote actual
            loop(workers_left, Map.put(jobs_queue, next_id, {from, jobs_left, [], Enum.count(jobs)}), current_batch + 1, next_id + 1)
          else
            loop(workers_left, Map.put(jobs_queue, next_id, {from, jobs_left, [], Enum.count(jobs)}), current_batch, next_id + 1) #Se crea un nuevo batch para los trabajos con el id correspondiente y se mete en el mapa
          end
        else
          send(from, {:error, :invalid_function})
          loop(workers, jobs_queue, current_batch, next_id)
        end

      {:done, worker, batch_id, index, result} ->
        case Map.get(jobs_queue, batch_id) do   #Se busca el lote con el id correspondiente en el mapa
          {from, [], current_results, jobs_remaining} ->
            updated_results = [{index, result} | current_results]
            jobs_remaining = jobs_remaining - 1

            new_queue =
            if jobs_remaining == 0 do
              ordered_results = Enum.sort_by(updated_results, fn {i, _} -> i end) #Se ordenan los resultados de la misma forma que estaban las funciones
              final_results = Enum.map(ordered_results, fn {_, res} -> res end) #Se toman solo los resultados y no los índices
              send(from, {:resultados, final_results})

              Map.delete(jobs_queue, batch_id) #Valor asignado a new_queue

            else #No se tienen todos los resultados todavía
              Map.replace(jobs_queue, batch_id, {from, [], updated_results, jobs_remaining}) #Valor asignado a new_queue

            end
              if next_id == current_batch do #Esto implica que no quedan trabajos por hacer
                loop([worker | workers], new_queue, current_batch, next_id)

              else #Aún quedan trabajos en otros lotes
                {from2, [job|rest_jobs], results2, remaining_jobs2} = Map.get(new_queue, current_batch) #Se busca el siguiente lote de trabajos en la cola
                send(worker, {:trabajo, self(), current_batch, job})
                if rest_jobs == [] do
                  loop(workers, Map.replace(new_queue, current_batch, {from2, rest_jobs, results2, remaining_jobs2}), current_batch + 1, next_id)

                else
                  loop(workers, Map.replace(new_queue, current_batch, {from2, rest_jobs, results2, remaining_jobs2}), current_batch, next_id)
                end

              end


          {from, [next_job | rest_jobs], current_results, jobs_remaining} -> #Quedan trabajos en el lote actual -> se pueden ahorrar bastantes pasos
            # Asignar trabajo pendiente al trabajador disponible
            updated_results = [{index, result} | current_results]
            send(worker, {:trabajo, self(), batch_id, next_job})
            if rest_jobs == [] do
              loop(workers, Map.replace(jobs_queue, batch_id, {from, rest_jobs, updated_results, jobs_remaining - 1}), current_batch + 1, next_id)

            else
              loop(workers, Map.replace(jobs_queue, batch_id, {from, rest_jobs, updated_results, jobs_remaining - 1}), current_batch, next_id)

            end
        end

      {:stop, from} ->
        Enum.each(workers, fn worker -> send(worker, :stop) end)
        send(from, :ok)

      _ ->
        # Manejo de mensajes inesperados
        loop(workers, jobs_queue, current_batch, next_id)
    end
  end

  # Enviar trabajos simultáneamente a los trabajadores
  defp assign_jobs([worker | workers_left], [job | jobs_left], batch) do
    send(worker, {:trabajo, self(), batch, job})
    assign_jobs(workers_left, jobs_left, batch)
  end

  defp assign_jobs(workers, [], _batch), do: {workers, []} #Sin más trabajos disponibles, devuelve los trabajadores restantes

  defp assign_jobs([], jobs, _batch), do: {[], jobs} # Sin más trabajadores disponibles, devuelve los trabajos restantes


  # API pública
  def procesar_trabajos(servidor, trabajos) do
    send(servidor, {:trabajos, self(), trabajos})
    receive do
      {:resultados, resultados} -> resultados
      {:error, reason} -> {:error, reason}
    after
      60000 -> {:error, :timeout}
    end
  end

  def detener(servidor) do
    send(servidor, {:stop, self()})
    receive do
      :ok -> :ok
    after
      10000 -> {:error, :timeout}
    end
  end
end


 #Test de si puede procesar más trabajos que trabajadores (8 tareas, 5 trabajadores)
servidor = Servidor.start(5)

jobs = [
  fn -> :timer.sleep(1000); "Hola" end,
  fn -> :timer.sleep(200); 42 end,
  fn -> :timer.sleep(150); [1, 2, 3] end,
  fn -> :timer.sleep(2500); %{clave: "valor"} end,
  fn -> :timer.sleep(1000); "Hola" end,
  fn -> :timer.sleep(200); 42 end,
  fn -> :timer.sleep(150); [1, 2, 3] end,
  fn -> :timer.sleep(2500); %{clave: "valor"} end
]

resultados = Servidor.procesar_trabajos(servidor, jobs)
IO.inspect(resultados, label: "Resultados")



#Test de si puede procesar varias peticiones a la vez
jobs1 = [
  fn -> :timer.sleep(1000); "Batch 1 - Hola" end,
  fn -> :timer.sleep(200); 42 end,
  fn -> :timer.sleep(5000); [1, 2, 3] end, #Sleep muy grande para que esta tarea acabe de última
  fn -> :timer.sleep(2500); %{clave: 'valor'} end
]


jobs2 = [
  fn -> :timer.sleep(300); "Batch 2 - Hola" end,
  fn -> :timer.sleep(200); 42 end,
  fn -> :timer.sleep(100); [1, 2, 3] end,
  fn -> :timer.sleep(300); "Batch 2 - Hola" end,
  fn -> :timer.sleep(200); 42 end,
  fn -> :timer.sleep(100); [1, 2, 3] end
] #Sleeps cortos para que este lote dure poco

task1 = Task.async(fn -> Servidor.procesar_trabajos(servidor, jobs1) end)

task2 = Task.async(fn -> Servidor.procesar_trabajos(servidor, jobs2) end) #Se hacen las peticiones de forma asíncrona


result2 = Task.await(task2)
IO.inspect(result2, label: "Resultados del lote 2")

result1 = Task.await(task1) #Debería de seguir haciendo trabajo del lote 1 después de entregar el lote 2, no va a ser instantáneo
IO.inspect(result1, label: "Resultados del lote 1")

atom = Servidor.detener(servidor)
IO.inspect(atom)
