# lib/kahoot_clone/game_supervisor.ex

defmodule KahootClone.GameSupervisor do
  @moduledoc """
    Supervisor estático que se encarga de gestionar las acciones específicas de una partida.

    ## Funcionalidad:
    - Supervisa el proceso del módulo `KahootClone.Game`, que representa la lógica y estado de una partida individual.
    - Cada instancia de este supervisor maneja una partida única, identificada por un `game_code`.

    ## Atributos:
      `:game_code`:
        Código único que identifica la partida supervisada. Es usado para registrar el supervisor en el registro global
        mediante `via_tuple/1` y para asociarlo con el estado y procesos de la partida.

    ## Estrategia:
    - Utiliza la estrategia `:one_for_one`, lo que significa que si el proceso supervisado falla, solo se reinicia ese proceso,
      sin afectar al resto de procesos ni al propio supervisor.
  """

  use Supervisor

  @doc """
    Inicia un supervisor estático para una partida específica.

    ## Parámetros:
      - `game_code`: Código único que identifica la partida supervisada.

    ## Retorno:
      - `{:ok, pid}`: Si el supervisor se inicia correctamente.
      - `{:error, reason}`: Si hay algún problema al iniciar el supervisor.
  """
  def start_link(game_code) do
    Supervisor.start_link(__MODULE__, game_code, name: via_tuple(game_code))
  end

  @doc """
    Define la estrategia de supervisión y los procesos hijos supervisados.

    ## Parámetros:
      - `game_code`: Código único que identifica la sala supervisada.

  """
  def init(game_code) do
    children = [
      %{
        id: KahootClone.Game,
        start: {KahootClone.Game, :start_link, [game_code]},
        restart: :transient,
        type: :worker,
        significance: :significant
      }
    ]

    Supervisor.init(children, strategy: :one_for_one, auto_shutdown: :any_significant)
  end

  @doc """
    Crea una tupla para registrar el supervisor en el registro global.

    ## Parámetros:
      - `game_code`: Código único que identifica la partida supervisada.

    ## Retorno:
      - Una tupla en el formato `{:via, Registry, {registry_name, key}}`.
  """
  def via_tuple(game_code) do
    {:via, Registry, {KahootClone.GameRegistry, {__MODULE__, game_code}}}
  end

  @doc """
    Función que devuelve el pid del juego supervisado.

    ## Parámetros:
      - `pid`: PID del supervisor que supervisa el juego

    ## Retorno:
      - `game_pid`: PID de la sala supervisada
  """

  def get_game_pid(pid) do
    [{game_pid, _}] = Supervisor.which_children(pid)
    game_pid
  end
end
