## Demo

### Inicialización de los servicios servidor(pool de trabajadores) y cliente(conexión al nodo de la pool)
- **En el nodo líder**:
  1. En una terminal (que sera el servidor aplicación) debes ejecutar `iex --name server@127.0.0.1 --cookie mycookie -S mix`.
  2. Y luego ejecutar KahootClone.AppSupervisor.start_link para iniciar la pool.

- **Uso**
  1. Por cada jugador o administrador se crea una nueva terminal que debe conectarse al servidor de aplicación ejecutando el comando `iex --name client1@127.0.0.1 --cookie mycookie-S mix` (cambiando "client1" al nombre de cada nodo).
  2. Para conectarse al nodo servidor, hacer `Node.connect(:"server@127.0.0.1")`.
  3. Para ejecutar la función principal pondremos el siguiente comando: `KahootClone.CLI.main` en la terminal del nodo que queramos ejecutar

### Funcionalidades que permiten listar elementos 

Para ir mirando como se va manejando la pool de salas implementamos una función que devuelve en un lista los códigos de las salas creadas en la pool. Si se quiere mirar se hace un `KahootClone.RoomManager.get_pool` que debeia devolver algo así:
```elixir
["0688", "1447", "34fa", "68eb", "717b"]
```

### Probar funcionalidades 

Se incluyen 3 funcionalidades: `Crear juego`, `Unirse a juego` y `Salir`.

- **Desarrollo de partida**

    Se interactúa con distintos servicios para demostrar que el servidor con la pool está redirigiendo las peticiones correspondientes a los clientes, que puedan procesar correctamente y se atribuyen las respuestas correctamente.

  1. El nodo que actuará de administrador de la partida ira a la opción 1 (Crear juego):
  ```console
    iex(client1@127.0.0.1)2> KahootClone.CLI.main
    Bienvenido a KahootClone!
    1. Crear juego
    2. Unirse a juego
    3. Salir
    Seleccione una opción: 1
  ```
  2. Introduce su nombre y luego las preguntas que quiere hacer con la respuesta que es correcta, cuando no tenga más preguntas ponga un ENTER en Pregunta para acabar:
  ```console
    Ingrese su nombre: admin
    Ingrese las preguntas (deje en blanco para terminar):
    Pregunta: Cuánto es 2 + 2?
    Respuesta 1: 4
    Respuesta 2: 3
    Respuesta 3: 2
    Respuesta 4: 1
    Número de respuesta correcta (1-4): 1
    Pregunta: Cuál es la capital de Cambodia?
    Respuesta 1: Saigón
    Respuesta 2: Hanói
    Respuesta 3: Nom Pen
    Respuesta 4: Bangkok
    Número de respuesta correcta (1-4): 3
    Pregunta: (ENTER) 
    Juego creado con código: 2fa0

    Presiona Enter para comenzar el juego o 'q' para salir...
  ```
  3. Los nodos que van a jugar la partida seleccionan la opción 2 (Unirse al juego) y meten el nombre y código para jugar:
  ```console
    iex(client2@127.0.0.1)2> KahootClone.CLI.main
    Bienvenido a KahootClone!
    1. Crear juego
    2. Unirse a juego
    3. Salir
    Seleccione una opción: 2
    Ingrese el código del juego: 2fa0
    Ingrese su nombre: jugador1
    Te has unido al juego. Esperando que comience...
  ```
  4. Luego el nodo admin le da al ENTER y empieza la partida para los nodos jugadores, se responden las preguntas y se acaba la partida poniendo las puntuaciones:
  ```console
    Pregunta: Cuánto es 2 + 2?
    1. 4
    2. 3
    3. 2
    4. 1
    Tu respuesta (1-4): 1

    Pregunta: Cuál es la capital de Cambodia?
    1. Saigón
    2. Hanói
    3. Nom Pen
    4. Bangkok
    Tu respuesta (1-4): 3

    ¡Juego terminado!
    Puntuaciones finales:
    jugador1: 200
  ```

  ### Mostrar las capacidades de disponibilidad y rendimeinto mediante la autoescala del servicio

  En el room_manager.ex se incluyen unos límites para el número de salas libres, que permite escalar la disponibilidad del servicio:
  ```elixir
  @pool_size 5  # Número inicial de salas en el pool
  @min_free 3  # Número mínimo de salas libres
  @max_free 10  # Número máximo de salas libres
  ```

  Cuando se van creando salas por parte de los clientes las salas con sus códigos se van quitando de la pool:

  ```elixir
  # En un inicio habra algo asi
  KahootClone.RoomManager.get_pool
  ["0688", "1447", "34fa", "68eb", "717b"]
  # Y llegará un momento en el que no queden salas
  KahootClone.RoomManager.get_pool
  []
  ```

  Cuando se hayan ocupado todas las salas de la pool, si un cliente solicita una sala, la pool generará una sala con un código nuevo y se lo asignará al cliente que realizó la petición de crear una nueva partida. Esta al ser liberada de nuevo se devolverá a la pool junto con las demás.

   ```elixir
  KahootClone.RoomManager.get_pool
  ["0688", "1447", "34fa", "68eb", "717b", "70eb"]
  ```   