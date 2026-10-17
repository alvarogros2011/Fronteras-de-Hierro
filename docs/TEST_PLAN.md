# Plan de pruebas — Fronteras de Hierro

## Principios

- La lógica del juego se prueba **sin interfaz**, con scripts de GDScript ejecutables en modo headless.
- Cada hito del `ROADMAP.md` añade sus pruebas; no se cierra un hito con pruebas fallidas.
- Los informes distinguen siempre entre pruebas **ejecutadas** y **no verificadas**.

## Pruebas automáticas

**Estado actual: ninguna (aún no hay lógica de juego).**

Propuesta: scripts propios en `tests/` (se creará con la primera prueba), ejecutados con
`godot --headless --path . --script res://tests/run_all.gd`, sin plugins (decisión abierta nº 7 del GDD). Cada prueba devuelve código de salida distinto de 0 si falla.

| ID | Hito | Qué comprueba | Resultado esperado |
|---|---|---|---|
| A-01 | 1 | Número de provincias | Entre 12 y 16 |
| A-02 | 1 | Ids y nombres de provincia | Únicos |
| A-03 | 1 | Adyacencia simétrica | Si A es vecina de B, B lo es de A |
| A-04 | 1 | Sin autovecinas | Ninguna provincia es vecina de sí misma |
| A-05 | 1 | Conectividad | Un recorrido desde cualquier provincia alcanza todas |
| A-06 | 2 | Propiedad inicial | Un dueño por provincia; ambos bandos con ≥ 1 |
| A-07 | 2 | Selección válida | Provincia propia seleccionable como origen |
| A-08 | 2 | Selección inválida | Provincia enemiga no seleccionable como origen |
| A-09 | 3 | Ataque válido | Aceptado: origen propio, destino adyacente enemigo, tropas suficientes |
| A-10 | 3 | Ataque a no adyacente | Rechazado |
| A-11 | 3 | Ataque a provincia propia | Rechazado |
| A-12 | 3 | Ataque desde provincia ajena | Rechazado |
| A-13 | 3 | Ataque sin tropas suficientes | Rechazado |
| A-14 | 3 | Combate: atacante mayor | Gana con N − D tropas |
| A-15 | 3 | Combate: atacante menor | Pierde; defensor queda con D − N |
| A-16 | 3 | Combate: igualdad | Gana el defensor con 0 de excedente (regla del GDD) |
| A-17 | 3 | Determinismo | 100 repeticiones con las mismas entradas dan el mismo resultado |
| A-18 | 4 | Cambio de dueño | Tras victoria, dueño nuevo y tropas restantes correctas |
| A-19 | 4 | Sin cambio tras derrota | El dueño no cambia |
| A-20 | 4 | Integridad de propiedad | Tras N ataques, cada provincia tiene un único dueño |
| A-21 | 5 | Validez de la IA | Todas las órdenes de la IA son aceptadas |
| A-22 | 5 | Determinismo de la IA | Mismo estado → misma decisión |
| A-23 | 5 | Escenario fijo | La IA ataca a la vecina débil esperada |
| A-24 | 5 | Sin opciones | Si no hay ataque posible, la IA no hace nada ni falla |
| A-25 | 6 | Victoria | Enemigo sin provincias → fin con victoria |
| A-26 | 6 | Derrota | Jugador sin provincias → fin con derrota |
| A-27 | 6 | Órdenes tras el fin | Rechazadas |
| A-28 | 6 | Reinicio | El estado vuelve exactamente al inicial |

Nota: los resultados de A-14 a A-16 dependen de la regla de combate del GDD (suposición); se ajustarán si el propietario la cambia.

## Pruebas manuales

Se realizan en Godot 4.7 en un PC con Windows.

| ID | Hito | Pasos | Resultado esperado |
|---|---|---|---|
| M-01 | 0 | Importar `project.godot` y abrirlo | Sin errores ni avisos al cargar |
| M-02 | 0 | F5 | Ventana 1280x720 con título "FRONTERAS DE HIERRO" y subtítulo "Prototipo temprano" |
| M-03 | 0 | Redimensionar la ventana | El contenido sigue centrado y legible |
| M-04 | 1 | Ejecutar y observar el mapa | Entre 12 y 16 provincias visibles y distinguibles |
| M-05 | 2 | Clic en provincia propia | Se resalta |
| M-06 | 2 | Clic en vacío o clic derecho | Se deselecciona |
| M-07 | 2 | Clic en provincia enemiga sin selección previa | No ocurre nada |
| M-08 | 3 | Atacar provincia adyacente enemiga | Combate resuelto; tropas actualizadas |
| M-09 | 3 | Intentar atacar provincia no adyacente | Rechazado con mensaje o sin efecto |
| M-10 | 4 | Ganar un ataque | La provincia cambia de color |
| M-11 | 5 | Dejar la partida 2 minutos sin actuar | El enemigo ataca; sin errores |
| M-12 | 6 | Conquistar todas las provincias enemigas | Aparece "Victoria" |
| M-13 | 6 | Perder todas las provincias | Aparece "Derrota" |
| M-14 | 6 | Reiniciar tras el fin | Partida nueva con el estado inicial |

## Pruebas del hito 0 (cimientos)

| Comprobación | Cómo | Estado |
|---|---|---|
| `project.godot` apunta a `res://scenes/main.tscn` | Revisión estática | Hecho en la nube |
| La escena existe y su formato es coherente | Revisión estática | Hecho en la nube |
| Carga sin errores en Godot 4.7 | M-01, M-02, M-03 | **Pendiente** (requiere Godot) |
