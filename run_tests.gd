extends SceneTree

func _initialize() -> void:
    var autowork = ClassDB.instantiate("Autowork")
    root.add_child(autowork)
    autowork.run_tests()
    quit(autowork.get_fail_count())
