# lib/kahoot_clone/application.ex

defmodule KahootClone.RootSupervisor do
  @moduledoc """
    Supervisor dinámico encargado de gestionar múltiples partidas de forma concurrente.

    ## Funcionalidad:
    - Supervisa instancias del módulo `KahootClone.GameSupervisor`, donde cada instancia representa una partida individual.
    - Permite la creación y eliminación dinámica de partidas utilizando `start_child/1`.

    ## Estrategia:
    - Utiliza la estrategia `:one_for_one`, lo que significa que si un supervisor de partida falla, solo se reinicia ese supervisor específico,
      sin afectar al resto de partidas ni al propio RootSupervisor.
  """

  use DynamicSupervisor

  @doc """
    Inicia el supervisor dinámico principal que gestiona todas las partidas.

    ## Parámetros:
      - `_arg`: Parámetro no utilizado, requerido por la interfaz de supervisor.

    ## Retorno:
      - `{:ok, pid}`: Si el supervisor dinámico se inicia correctamente.
      - `{:error, reason}`: Si hay un problema al iniciar el supervisor.
  """
  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
    Inicializa el supervisor dinámico con la estrategia `:one_for_one`.

    ## Parámetros:
      - `:ok`: Parámetro requerido para inicializar la configuración del supervisor.

  """
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
    Crea un nuevo supervisor de partida asociado a un código de juego único.

    ## Parámetros:
      - `code`: Código único que identifica la partida.

    ## Retorno:
      - `{:ok, pid}`: Si el supervisor de partida se inicia correctamente.
      - `{:error, reason}`: Si no se puede crear el supervisor de partida.
  """
  def start_child(code) do
    child_spec = %{
      id: KahootClone.GameSupervisor,
      start: {KahootClone.GameSupervisor, :start_link, [code]},
      type: :supervisor,
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
