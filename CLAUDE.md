# CLAUDE.md — Instrucciones persistentes para Claude Code

## Proyecto

**Fronteras de Hierro**: estrategia 2D en tiempo real de conquista de territorios. Godot 4.7, GDScript, Windows PC, pixel art, mapa cenital.
Inspirado en conceptos generales de OpenFront y Call of War, **sin copiar** sus mapas, recursos, código, nombres, interfaz ni contenido protegido.

El propietario es **principiante**: toma decisiones técnicas sólidas, explica las importantes con claridad y no amplíes el alcance sin aprobación.

## Idioma

- Toda la documentación, comentarios de código, mensajes de commit e informes finales: **en español**.
- Identificadores de código (variables, funciones, clases): en español o inglés, pero **uno solo por proyecto**. Decisión actual: **inglés** para identificadores (`snake_case` en GDScript), español para texto visible y comentarios.

## Dirección de diseño permanente

Confirmada por el propietario:
- Fácil de aprender y jugar; muy cercano a OpenFront en su bucle general (expansión territorial, ataques y economía sencilla), con una **mecánica propia aún por definir**.
- Presentación **limpia (clean)**: el mapa es el elemento principal; interfaz minimalista y legible; colores territoriales claros y consistentes; elementos visuales discretos; sin exceso de efectos, animaciones, ventanas ni información.
- No convertir el juego en un RTS táctico detallado.
- Economía futura: como máximo uno o dos recursos.
- Los combates deben permitir entender con facilidad si se tiene ventaja antes de atacar.
- Las tropas futuras no tienen por qué ser una única cifra global, pero no se simulan soldados individuales ni se recarga la interfaz.

Pendiente de decisión del propietario (**no inventar ni implementar**): modelo concreto de unidades y mecánica diferenciadora.

## Alcance

- La fuente de verdad del alcance es `docs/GDD.md` (MVP) y `docs/ROADMAP.md` (orden de hitos).
- Trabaja **solo en el hito que se pida**. No empieces el siguiente automáticamente.
- Prohibido sin aprobación expresa: recursos, reclutamiento, edificios, tipos de unidad, investigación, suministros, multijugador, guardado de partida, nuevos plugins, nuevos autoloads, nuevas dependencias.
- Si una tarea exige ampliar el alcance, **pregunta antes**.
- No descargues arte ni instales software ajeno al proyecto.

## Arquitectura

- Simple y nativa de Godot: escenas + scripts GDScript con tipado estático (`var x: int`, `func f() -> void`).
- **Separar lógica y presentación**: las reglas (mapa, propiedad, combate, IA, victoria) viven en scripts sin dependencia de nodos visuales (`RefCounted`/`Resource`), para poder probarlas sin abrir la interfaz.
- El combate debe ser **determinista**: mismas entradas, mismo resultado. Si se añade azar en el futuro, siempre con semilla inyectable.
- Los datos del mapa (provincias, vecinos) se definen de forma declarativa (recurso o archivo de datos), no dispersos en código.
- Comunicación entre nodos con **señales**; evita rutas de nodo frágiles (`get_node("../../x")`).
- Sin autoloads, plugins ni abstracciones "por si acaso". Añádelos solo con justificación escrita.
- Estructura: `scenes/`, `scripts/`, `tests/`, `docs/`, `assets/`. No crear carpetas vacías ni módulos sin uso inmediato.
- Ventana base 1280x720, stretch `canvas_items`, renderizador Compatibility.

## Pruebas

- Cada regla de juego nueva lleva pruebas automáticas, salvo que no sea viable (y se justifique en el informe).
- Plan y casos en `docs/TEST_PLAN.md`; actualízalo en cada hito.
- Si hay ejecutable de Godot en el entorno, valida con `godot --headless --path . --quit` y ejecuta las pruebas. Si no lo hay, **no lo instales**: haz comprobaciones estáticas e informa de lo no verificado.
- **Nunca afirmes** que el juego se ha ejecutado o probado visualmente si no ocurrió. Informa de los resultados reales, incluidos los fallos.
- No se desactivan ni se saltan pruebas para que pasen.

## Flujo de trabajo

- Desarrolla solo en la rama que asigne la sesión. **Nunca fusiones ni empujes a `main`.** No crees pull requests salvo petición expresa.
- Commits pequeños y descriptivos.
- Edita solo lo necesario para el hito; no refactorices por gusto.
- No despliegues ni publiques el juego.
- No afirmes conocer costes ni crédito restante salvo que el dato esté disponible.
- Al terminar, informe en español: archivos modificados, decisiones, pruebas ejecutadas y resultados, lo no verificado, decisiones que requieren revisión humana y siguiente hito recomendado.
- Mantén README, GDD, ROADMAP y TEST_PLAN coherentes entre sí; el README debe reflejar solo lo realmente implementado.
