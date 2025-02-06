# lib/kahoot_clone/app_supervisor.ex

defmodule KahootClone.AppSupervisor do
  @moduledoc """
    Este módulo define un supervisor de nivel superior para gestionar los procesos clave de la aplicación KahootClone.
    Utiliza supervisión estática para asegurar la robustez del sistema y el reinicio automático de procesos en caso de fallos.z
  """

  use Supervisor

  @doc """
    Inicia el supervisor principal de la aplicación.

    ## Retorno:
      - `{:ok, pid}`: Si el supervisor se inicia correctamente.
  """
  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
    Define los hijos supervisados (el RoomManager, el Registro y el supervisor dinámico) y la estrategia de supervisión.

    ## Parámetro:
      - `:ok`: Indicador de inicialización (no utilizado directamente).
  """
  def init(:ok) do
    children = [
      {Registry, keys: :unique, name: KahootClone.GameRegistry},
      KahootClone.RoomManager,
      KahootClone.RootSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one, auto_shutdown: :any_significant)
  end
end
