# Hoja de ruta — Fronteras de Hierro

Los hitos están en orden de dependencia. Cada uno se pide y se revisa por separado. El MVP coincide con `docs/GDD.md` §6 y termina en el hito 7.

| Hito | Nombre | Estado |
|---|---|---|
| 0 | Cimientos | Hecho (pendiente de revisión en Godot) |
| 1 | Mapa y provincias | Pendiente |
| 2 | Interacción del jugador | Pendiente |
| 3 | Tropas y combate | Pendiente |
| 4 | Captura de provincias | Pendiente |
| 5 | IA enemiga | Pendiente |
| 6 | Victoria, derrota y reinicio | Pendiente |
| 7 | Pulido y cierre del MVP | Pendiente |
| 8+ | Ampliaciones | Fuera del MVP |

## Hito 0 — Cimientos
- Proyecto Godot 4.7 válido, escena de arranque, documentación base.
- **Criterios:**
  - `project.godot` apunta a `res://scenes/main.tscn`.
  - Al abrirlo en Godot 4.7 y pulsar F5 se ve el título y el subtítulo sin errores en la consola.
  - Existen README, CLAUDE.md, GDD, ROADMAP, TEST_PLAN y .gitignore coherentes entre sí.

## Hito 1 — Mapa y provincias
- Definición de 12–16 provincias ficticias, sus vecinas y su dibujo en pantalla.
- **Criterios:**
  - Hay entre 12 y 16 provincias, cada una con id y nombre único.
  - La adyacencia es simétrica y no hay provincias aisladas: el grafo es conexo (prueba automática).
  - Ninguna provincia es vecina de sí misma.
  - Todas se dibujan en pantalla a 1280x720 sin solaparse.

## Hito 2 — Interacción del jugador
- Propiedad inicial jugador/enemigo y selección con el ratón.
- **Criterios:**
  - Cada provincia tiene exactamente un dueño; ambos bandos empiezan con al menos 1 provincia.
  - Clic en una provincia la selecciona y se resalta; clic en vacío o clic derecho deselecciona.
  - Solo se puede seleccionar como origen una provincia propia.
  - La selección se comprueba con pruebas automáticas de la lógica.

## Hito 3 — Tropas y combate
- Tropas por provincia, órdenes de ataque/movimiento y combate determinista.
- **Criterios:**
  - El combate es una función pura: mismas entradas, mismo resultado.
  - Se rechazan ataques inválidos: origen no propio, destino no adyacente, destino propio, tropas insuficientes.
  - Casos de victoria, derrota y empate cubiertos por pruebas automáticas.
  - El número de tropas es visible en cada provincia.

## Hito 4 — Captura de provincias
- Cambio de dueño tras un ataque victorioso.
- **Criterios:**
  - Tras un ataque ganador, el dueño cambia y las tropas restantes quedan en la provincia capturada.
  - Tras un ataque perdido, el dueño no cambia.
  - El color del mapa se actualiza de inmediato.
  - Ninguna provincia queda sin dueño ni con dos dueños (prueba automática).

## Hito 5 — IA enemiga
- IA simple que ataca con las mismas reglas que el jugador.
- **Criterios:**
  - La IA solo realiza órdenes válidas (nunca rechazadas por el sistema).
  - Dado el mismo estado, toma la misma decisión (determinista).
  - En un escenario de prueba prefijado ataca a una provincia adyacente débil.
  - Una partida de 5 minutos sin intervención no produce errores.

## Hito 6 — Victoria, derrota y reinicio
- Fin de partida y reinicio.
- **Criterios:**
  - Si el enemigo no tiene provincias, se muestra "Victoria".
  - Si el jugador no tiene provincias, se muestra "Derrota".
  - Tras el fin, no se aceptan más órdenes.
  - Reiniciar restaura el estado inicial exacto (prueba automática) sin reiniciar el programa.

## Hito 7 — Pulido y cierre del MVP
- Corrección de errores, equilibrio básico, texto visible, revisión de documentación.
- **Criterios:**
  - Se completa una partida entera (victoria y derrota) siguiendo el plan de pruebas manuales.
  - Todas las pruebas automáticas pasan.
  - README, GDD y ROADMAP reflejan lo realmente implementado.

## Hito 8+ — Ampliaciones (fuera del MVP, requieren aprobación)
Recursos, reclutamiento, edificios, tipos de unidad, investigación, suministros, más mapas y facciones. Se planificarán en detalle al cerrar el hito 7.
