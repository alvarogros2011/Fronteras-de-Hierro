## Ejecutor headless (consola) de las pruebas de la operación de conquista (hito 5).
## Las comprobaciones están en tests/territory_conquest_tests.gd (compartidas con la escena de pruebas).
##
## Ejecución (desde la raíz del proyecto):
##   godot --headless --path . --script res://tests/test_territory_conquest.gd
##
## Imprime PASS/FAIL por prueba y termina con código 0 si todo pasa o 1 si algo falla.
## Sin terminal: abre res://tests/run_conquest_tests.tscn y pulsa F6.
extends SceneTree

const ConquestTests := preload("res://tests/territory_conquest_tests.gd")


func _initialize() -> void:
	var passed := 0
	var failed := 0
	for result: Dictionary in ConquestTests.new().run_all():
		var errors: Array = result["errors"]
		if errors.is_empty():
			passed += 1
			print("PASS: %s" % result["name"])
		else:
			failed += 1
			print("FAIL: %s" % result["name"])
			for error: String in errors:
				print("      - %s" % error)
	print("")
	print("Resultado: %d PASS, %d FAIL" % [passed, failed])
	quit(1 if failed > 0 else 0)
