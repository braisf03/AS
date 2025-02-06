# Documentación de la Aplicación

## Aplicación

### Breve Descripción
Nuestra aplicación es una copia de las funcionalidades basicas de Kahoot, desarrollada en Elixir utilizando una arquitectura líder-trabajador. 

En esta arquitectura, el proceso líder se encarga de gestionar las partidas: crea, elimina y escoge de la pool de partidas según sea necesario, redirigiendo a los usuarios al proceso de partida seleccionado. Por otro lado, los procesos trabajadores manejan las interacciones individuales de los usuarios con una partida, como responder a una pregunta. La aplicación permite a los usuarios participar en cuestionarios interactivos, ya sea como organizadores (hosts) o jugadores, ofreciendo funcionalidades como la creación de preguntas, respuesta en tiempo real y visualización de resultados.

### Requisitos Funcionales
- Crear y configurar cuestionarios con preguntas de opción múltiple.
- Unirse a un cuestionario como jugador mediante un código único y dando tu nombre.
- Responder preguntas en tiempo real.
- Visualizar resultados al acabar la partida.

### Requisitos No Funcionales
- **Rendimiento**:
  - Soportar múltiples cuestionarios concurrentes y usuarios concurrentes por cada cuestionario sin degradación en el tiempo de respuesta.
- **Disponibilidad**:
  - Si durante una partida se cae un jugador, se garantiza que la partida pueda continuar con normalidad.
  - Si durante una partida se cae el administrador, los usuarios pueden seguir teniendo acceso a la partida.
  - Si el servidor de una partida se cae, se intenta volver a levantarlo manteniendo su estado anterior lo antes posible.
- **Seguridad**:
  - Se evita que ningún proceso malicioso pueda hacerse pasar por sala de juego, gracias al control de creación de procesos con el modulo Registry.
- **Escalabilidad**:
  - Capacidad de aumentar el número de trabajadores libres en la pool para comportarse mejor ante grandes picos de demanda.
- **Mantenimiento**:
  - Código modular y fácil de extender con nuevas funcionalidades.



## Diseño

### Documentación del Diseño (C4)

1. **Contexto**:  
   Describe a grandes rasgos cómo interactúan el cliente con nuestro sistema.
   
   ![Diagrama de contexto](./practica/Docs/diagrama_c4_contexto.png)

   Ver el código del diagrama en [`diagrama_c4_contexto.pu`](./practica/Docs/diagrama_c4_contexto.pu)

2. **Contenedor**:  
   Explica los componentes principales (cliente web, líder y trabajadores) y sus interacciones.
   
   ![Diagrama de contenedor](./practica/Docs/diagrama_c4_contenedor.png)
   
   Ver el código del diagrama en [`diagrama_c4_contenedor.pu`](./practica/Docs/diagrama_c4_contenedor.pu)

3. **Componentes**:  
   Detalla los módulos del servidor (tanto el RoomManager como las salas de partida) y muestra la estructura de supervisores,
   
   ![Diagrama de componente](./practica/Docs/diagrama_c4_componente.png)
   
   Ver el código del diagrama en [`diagrama_c4_componente.pu`](./practica/Docs/diagrama_c4_componente.pu)

4. **Código**:  
   Muestra cómo se estructuran los módulos y procesos en Elixir.

   ![Diagrama de clase](./practica/Docs/diagrama_c4_clase.png)



### Decisiones de Diseño

1. **Elección de Arquitectura:**
Para esto, nos planteamos tres arquitecturas diferentes:

  - **Peer to peer con superpeer**: Es una solución bastante natural para un problema así, ya que el superpeer podría registrar con un código al creador de una sala y redirigir a la gente que introduzca ese código a esa sala. Además, permitiría que nuestro sistema fuese más escalable, ya que no necesitaríamos tener nosotros un proceso dedicado para cada sala. El problema de esto es que, a diferencia de muchos otros sistemas similares, si el host de una sala se cae, no tendría sentido hacer que otro de los jugadores pase a ser el host, ya que el host es el que creó las preguntas. Esto complica el hacer que las salas sean resistentes a fallos.
  - **Cliente-servidor**: De esta forma, se podría tener un mayor control sobre los procesos de sala para implementar más tácticas en caso de que haya un fallo. En este caso, habría un servidor central que ofrecería servicios de creación y de unión a una sala, y cada una de las salas sería un pseudo-servidor con el que se comunican los usuarios que hayan introducido su código. No obstante, no estaríamos aprovechando del todo las ventajas de cliente servidor (que los fallos en un servicio no afecten al resto), ya que el crear y el unirse a salas no es lo importante de nuestro sistema.
  - **Líder-trabajador**: Esto sería similar a la arquitectura cliente-servidor, pero ofrece varias ventajas con respecto a esta. En este caso, habría un líder que se encargaría de crear salas y redirigir a los jugadores a ellas. Cada una de las salas sería un trabajador independiente, lo cual haría que el sistema tuviese más sencillo el gestionarlas. Además, en caso de que haya grandes picos de usuarios, esto nos permitiría tener salas preparadas para ello sin hacer que tengamos demasiadas salas libres cuando haya pocas peticiiones. Otra ventaja es que, en caso de querer hacer que las salas y el líder estén en diferentes nodos, sería relativamente simple implementarlo modificando cómo se representa el estado del líder y cómo se comunica con los trabajadores. No obstante, debido a los problemas con la elección de la arquitectura, no tuvimos tiempo a plantear una versión completamente funcional de esto último.


Debido a las ventajas planteadas, decidimos utilizar la arquitectura líder-trabajador, ya que las otras dos opciones tenían algún inconveniente que hacía que no encajasen del todo con nuestra visión del sistema.


2. **Gestión de salas libres**
Nuestro líder mantiene un conjunto de códigos que se corresponden con las salas que tiene creadas. Para acceder a ellas, utiliza un registro (Registry) que asocia cada código con el pid de la sala correspondiente. Esto permite que los usuarios solo se necesiten comunicar con el líder para que les redirija a una de sus salas. Además, cuando una sala acaba, el líder puede consultar su código para comprobar que no es ningún proceso malicioso antes de volver a añadirla a su pool de salas.

3. **Comunicación directa de las salas con los clientes**
Cuando el RoomManager redirige a un cliente hacia una sala, el cliente se comunica directamente con ella. Esto puede considerarse una pequeña ruptura de la arquitectura, pero, como una partida implica interactividad con el estado del servidor, .

4. **Tácticas de Manejo de Fallos**
Cada sala está supervisada por un supervisor estático que se crea junto con ella. Todos los supervisores estáticos están supervisados por un supervisor dinámico para reducir al mínimo los fallos. Además, cuando una sala actualiza su estado, lo guarda utilizando :ets (erlang term storage) para poder recuperarlo en caso de caída. Existe una tabla de :ets por sala para que sean lo más independientes posibles.
Los superisores de sala solo las levantan de vuelta en caso de que acaben de forma anormal; si una sala acaba de forma normal, el supervisor no la vuelve a levantar y también acaba, dejando de ser supervisado por el supervisor dinámico.
El líder y el supervisor dinámico también tienen a un supervisor estático que se encarga de aumentar la tolerancia a fallos de la apliación general, ya que el mayor problema de la arquitectura líder-trabajador es que el líder es un SPoF.

5. **Facilidad de Escalabilidad**
Cada sala se crea como un proceso independiente gestionado por un supervisor. Esto aumenta la escalabilidad del sistema, especialmente en caso de llegar a hacerlo distribuido, ya que permitiría aumentar el número de nodos asignados a alojar salas de forma bastante sencilla.
Además de esto



## Instrucciones

### Compilación y Despliegue
- **Compilación**:
  1. Ejecutar `mix deps.get` para instalar dependencias.
  2. Ejecutar `mix compile` para compilar el código.
- **Despliegue**:
  1. En una terminal (que sera el servidor aplicación) debes ejecutar `iex --name server@127.0.0.1 --cookie mycookie -S mix`
  2. Ejecutar KahootClone.AppSupervisor.start_link

- **Uso**
  1. Por cada jugador o administrador se crea una nueva terminal que debe conectarse al servidor de aplicación ejecutando el comando `iex --name client1@127.0.0.1 --cookie mycookie-S mix` (cambiando "client1" al nombre de cada nodo)
  2. Para conectarse al nodo servidor, hacer Node.connect(:"server@127.0.0.1")
  3. Para ejecutar la función principal pondremos el siguiente comando: `KahootClone.CLI.main` en la terminal del nodo que queramos ejecutar

### Ejecución de Tests
1. Ejecutar `mix test` para realizar pruebas unitarias y de integración.
2. Revisar el informe de cobertura generado en `cover/`.



## Tests

### Tipos de Tests
1. **Unitarios**:  
   Verifican funcionalidades específicas como la validación de respuestas o el manejo de tiempos de espera.
2. **Integración**:  
   Aseguran la correcta interacción entre el servidor y la base de datos.
3. **Aceptación**:  
   Comprueban la experiencia completa del usuario, desde unirse a un cuestionario hasta finalizarlo.

### Escenarios Cubiertos
- Creación de cuestionarios y validación de campos obligatorios.
- Manejo de múltiples jugadores conectados al mismo tiempo.
- Respuesta a preguntas con tiempos límite.

### Escenarios No Cubiertos
- Comportamiento con muchos jugadores simultáneos.
- Ataques malintencionados (e.g., inyección SQL, DDoS).



## Casos de Uso

### Unirse a un cuestionario:
- **Actor principal**: Jugador.
- **Flujo principal**:
  1. El jugador introduce un código único en la interfaz.
  2. El sistema valida el código.
  3. El sistema redirige al jugador al cuestionario correspondiente.

### Hostear cuestionario:
- **Actor principal**: Host
- **Flujo principal**:
  1. El host introduce las preguntas y respuestas correctas de su cuestionario.
  2. El sistema selecciona una de sus salas libres (o crea una) y redirige al host a esa sala, mostrando el código por pantalla
  3. El host espera a que los jugadores se unan e inicia la sala en el momento que quiera



## Configuración del formateador

El proyecto utiliza `mix format` para mantener un estilo de código uniforme. Las configuraciones están definidas en el archivo `.formatter.exs` y son las siguientes:

- **Archivos a formatear (`inputs`)**:
  - Archivos en los directorios `config`, `lib` y `test` con extensión `.ex` y `.exs`.
  - Archivos de configuración principales como `mix.exs` y `.formatter.exs`.

### Ejecución del formateador
Para aplicar el formato al código, ejecuta: `mix format`