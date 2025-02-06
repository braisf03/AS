# lib/kahoot_clone/cli.ex

defmodule KahootClone.CLI do
  @moduledoc """
    Componente encargado de gestionar la interacción con el usuario a través de la línea de comandos.

    Proporciona un menú principal para crear un juego, unirse a uno ya existente o salir de la aplicación.

    ## Funciones
    - `main/0`: Muestra el menú principal y maneja la selección de opciones.
    - `create_game/0`: Permite al usuario crear un juego ingresando su nombre y las preguntas.
    - `join_game/0`: Permite al usuario unirse a un juego existente ingresando el código y su nombre.
    - `host_game_loop/1`: Controla el ciclo del juego cuando el usuario es el anfitrión.
    - `player_game_loop/2`: Controla el ciclo del juego cuando el usuario es un jugador.
  """

  @doc """
    Muestra el menú principal de la aplicación y gestiona la selección de opciones.
  """

  def main do
    IO.puts("Bienvenido a KahootClone!")
    IO.puts("1. Crear juego")
    IO.puts("2. Unirse a juego")
    IO.puts("3. Salir")

    case IO.gets("Seleccione una opción: ") |> String.trim() do
      "1" -> create_game()
      "2" -> join_game()
      "3" -> IO.puts("Gracias por jugar!")
      _ -> IO.puts("Opción no válida") && main()
    end
  end

  @doc false

  defp create_game do
    creator = IO.gets("Ingrese su nombre: ") |> String.trim()
    questions = create_questions()

    case KahootClone.RoomManager.create_room(creator, questions) do
      {:ok, code, pid} ->
        IO.puts("Juego creado con código: #{code}")
        host_game_loop(pid)

      _ ->
        IO.puts("Error al crear el juego")
        main()
    end
  end

  @doc false

  defp create_questions do
    IO.puts("Ingrese las preguntas (deje en blanco para terminar):")
    create_questions_loop([])
  end

  @doc false

  defp create_questions_loop(acc) do
    question = IO.gets("Pregunta: ") |> String.trim()

    if question == "" do
      Enum.reverse(acc)
    else
      answers =
        Enum.map(1..4, fn i ->
          IO.gets("Respuesta #{i}: ") |> String.trim()
        end)

      correct = get_correct_answer("Número de respuesta correcta (1-4): ")

      new_question = %{
        question: question,
        answers: answers,
        correct_answer: Enum.at(answers, correct - 1)
      }

      create_questions_loop([new_question | acc])
    end
  end

  @doc false

  defp get_correct_answer(msg) do
    case IO.gets(msg) |> String.trim() |> Integer.parse() do
      {number, ""} when number in 1..4 ->
        number

      _ ->
        IO.puts("Por favor, ingrese un número válido entre 1 y 4.")
        get_correct_answer(msg)
    end
  end

  @doc false

  defp join_game do
    code = IO.gets("Ingrese el código del juego: ") |> String.trim()
    player_name = IO.gets("Ingrese su nombre: ") |> String.trim()

    case KahootClone.RoomManager.join_room(code, player_name, self()) do
      {:ok, game_pid} ->
        IO.puts("Te has unido al juego. Esperando que comience...")
        player_game_loop(game_pid, player_name)

      {:error, :name_taken} ->
        IO.puts("Ese nombre ya está en uso. Intente con otro.")
        join_game()

      {:error, :room_not_found} ->
        IO.puts("Partida no encontrada")
        main()

      _ ->
        IO.puts("Error al unirse al juego")
        main()
    end
  end

  @doc false

  defp host_game_loop(pid) do
    state = KahootClone.Game.get_game_state(pid)

    case state.state do
      :waiting ->
        IO.puts("\nPresiona Enter para comenzar el juego o 'q' para salir...")
        input = IO.gets("") |> String.trim()

        if input == "q" do
          end_game(pid)
        else
          state = KahootClone.Game.get_game_state(pid)
          IO.puts("\nJugadores actuales (Numero total de jugadores: #{map_size(state.players)}):")

          Enum.each(state.players, fn {player_name, _} ->
            IO.puts("- #{player_name}")
          end)

          KahootClone.Game.start_game(pid)
          host_game_loop(pid)
        end

      :playing ->
        current_question = Enum.at(state.questions, state.current_question)
        IO.puts("\nPregunta actual: #{current_question.question}")
        IO.puts("Esperando respuestas de los jugadores...")
        :timer.sleep(5000)
        host_game_loop(pid)

      :finished ->
        IO.puts("\n¡Juego terminado!")
        IO.puts("Puntuaciones finales:")

        Enum.each(state.scores, fn {player, score} ->
          IO.puts("#{player}: #{score}")
        end)

        wait_and_exit(pid)

      _ ->
        IO.puts("Estado desconocido del juego.")
        :timer.sleep(1000)
        host_game_loop(pid)
    end
  end

  @doc false

  defp wait_and_exit(pid) do
    timeout = 300_000

    task =
      Task.async(fn ->
        IO.gets(
          "Pulsa cualquier tecla para acabar la partida (si no, acabará automáticamente en 5 minutos) "
        )
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, _} ->
        end_game(pid)
        :ok

      nil ->
        IO.puts("No se ha pulsado ninguna tecla, la partida acabará automáticamente")
        KahootClone.Game.end_game(pid)
        :ok
    end
  end

  defp end_game(pid) do
    IO.puts("Gracias por jugar!")
    KahootClone.Game.end_game(pid)
  end

  @doc false

  defp player_game_loop(code, player_name) do
    receive do
      {:new_question, question} ->
        IO.puts("\nPregunta: #{question.question}")

        Enum.with_index(question.answers, 1)
        |> Enum.each(fn {answer, index} ->
          IO.puts("#{index}. #{answer}")
        end)

        answer = IO.gets("Tu respuesta (1-4): ") |> String.trim()

        KahootClone.Game.answer_question(
          code,
          player_name,
          Enum.at(question.answers, String.to_integer(answer) - 1)
        )

        player_game_loop(code, player_name)

      {:game_finished, scores} ->
        IO.puts("\n¡Juego terminado!")
        IO.puts("Puntuaciones finales:")

        Enum.each(scores, fn {player, score} ->
          IO.puts("#{player}: #{score}")
        end)

      _ ->
        IO.puts("Esperando que comience el juego...")
        player_game_loop(code, player_name)
    end
  end
end
