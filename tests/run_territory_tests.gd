## Escena de pruebas del territorio (hito 3) para ejecutar desde el editor de Godot.
## Abre res://tests/run_territory_tests.tscn y pulsa F6 (Ejecutar escena actual).
##
## Ejecuta las comprobaciones reales de tests/territory_grid_tests.gd (las mismas que usa
## el ejecutor headless) y las muestra en pantalla. No toca la escena principal del juego.
extends Control

## Valores por defecto = pruebas del hito 3. run_view_tests.tscn los cambia para el hito 4.
@export var suite_path: String = "res://tests/territory_grid_tests.gd"
@export var title_text: String = "Pruebas del territorio (hito 3)"

const COLOR_PASS := Color(0.35, 0.85, 0.45)
const COLOR_FAIL := Color(1.0, 0.35, 0.35)
const COLOR_TEXT := Color(0.88, 0.9, 0.93)

var _summary: Label
var _details: RichTextLabel
var _button: Button


func _ready() -> void:
	_build_ui()
	_summary.text = "Ejecutando pruebas..."
	_summary.add_theme_color_override("font_color", COLOR_TEXT)
	_details.clear()
	# Un fotograma de espera para que se vea "Ejecutando..." antes del cálculo.
	await get_tree().process_frame
	_run_tests()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.09, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	column.add_child(title)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 22)
	column.add_child(_summary)

	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.scroll_active = true
	_details.selection_enabled = true
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_font_size_override("normal_font_size", 17)
	_details.add_theme_font_size_override("bold_font_size", 17)
	column.add_child(_details)

	_button = Button.new()
	_button.text = "Ejecutar de nuevo"
	_button.pressed.connect(_run_tests)
	column.add_child(_button)


func _run_tests() -> void:
	_button.disabled = true
	_details.clear()
	# load() en vez de preload(): si el script de pruebas tuviera un error de sintaxis,
	# la escena sigue abierta y lo explica en pantalla en vez de quedarse en blanco.
	var suite_script: GDScript = load(suite_path)
	if suite_script == null or not suite_script.can_instantiate():
		_show_load_error()
		_button.disabled = false
		return
	var results: Array = suite_script.new().run_all()
	var passed := 0
	var failed := 0
	for result: Dictionary in results:
		var errors: Array = result["errors"]
		if errors.is_empty():
			passed += 1
			_details.append_text("[color=#%s][b]PASS[/b][/color]  %s\n" % [COLOR_PASS.to_html(false), _escape(result["name"])])
			print("PASS: %s" % result["name"])
		else:
			failed += 1
			_details.append_text("[color=#%s][b]FAIL[/b][/color]  %s\n" % [COLOR_FAIL.to_html(false), _escape(result["name"])])
			print("FAIL: %s" % result["name"])
			for error: String in errors:
				_details.append_text("[color=#%s]        - %s[/color]\n" % [COLOR_FAIL.to_html(false), _escape(error)])
				print("      - %s" % error)
	var total := passed + failed
	if failed == 0:
		_summary.text = "TODO CORRECTO: %d correctas, 0 fallidas (de %d)" % [passed, total]
		_summary.add_theme_color_override("font_color", COLOR_PASS)
	else:
		_summary.text = "HAY FALLOS: %d correctas, %d fallidas (de %d)" % [passed, failed, total]
		_summary.add_theme_color_override("font_color", COLOR_FAIL)
	print("Resultado: %d PASS, %d FAIL" % [passed, failed])
	_button.disabled = false


func _show_load_error() -> void:
	_summary.text = "NO SE PUDIERON CARGAR LAS PRUEBAS"
	_summary.add_theme_color_override("font_color", COLOR_FAIL)
	_details.append_text("[color=#%s]No se pudo cargar %s.\nRevisa el panel [b]Salida[/b] o [b]Depurador > Errores[/b] de Godot: seguramente hay un error de sintaxis en ese archivo o en scripts/world/territory_grid.gd.[/color]\n" % [COLOR_FAIL.to_html(false), suite_path])


## Evita que los corchetes del texto se interpreten como etiquetas BBCode.
func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
