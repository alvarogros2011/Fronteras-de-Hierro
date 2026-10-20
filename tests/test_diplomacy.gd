## Ejecutor headless (consola) de las pruebas de guerra, diplomacia, treguas y pausa (hito 10).
## Las comprobaciones están en tests/diplomacy_tests.gd (compartidas con la escena de pruebas).
##
## Ejecución (desde la raíz del proyecto):
##   godot --headless --path . --script res://tests/test_diplomacy.gd
##
## Imprime PASS/FAIL por prueba y termina con código 0 si todo pasa o 1 si algo falla.
## Sin terminal: abre res://tests/run_diplomacy_tests.tscn y pulsa F6.
extends SceneTree

const DiplomacyTests := preload("res://tests/diplomacy_tests.gd")


func _initialize() -> void:
	var passed := 0
	var failed := 0
	for result: Dictionary in DiplomacyTests.new().run_all():
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
