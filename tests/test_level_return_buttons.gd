extends SceneTree
var errors=0
func _initialize(): call_deferred("run")
func check(ok,message):
 if not ok:
  errors+=1
  push_error(message)
func run():
 var progress=root.get_node("GameProgress")
 progress.save_path="res://.godot/return_buttons_test.cfg"
 progress.completed.clear()
 var paths=["tutorial_backdrop","level_1","level_2","level_3","level_4"]
 for path in paths:
  for running in [false,true]:
   var level=load("res://scenes/"+path+".tscn").instantiate()
   root.add_child(level)
   current_scene=level
   level.get_node("Transition").cancel()
   if running:
    level.start_level()
    await physics_frame
   var button=level.get_node("MenuLink/Button")
   check(button.pressed.is_connected(level.return_to_level_select),path+" return signal connected")
   var point=button.get_global_rect().get_center()
   for pressed in [true,false]:
    var event=InputEventMouseButton.new()
    event.position=point
    event.global_position=point
    event.button_index=MOUSE_BUTTON_LEFT
    event.pressed=pressed
    root.push_input(event,true)
   await process_frame
   await process_frame
   check(current_scene.scene_file_path=="res://scenes/level_select.tscn",path+" actual return click; running="+str(running))
   current_scene.queue_free()
   await process_frame
 check(progress.completed.is_empty(),"Exiting never grants completion")
 print("Return buttons: ",errors," failures")
 quit(1 if errors else 0)
