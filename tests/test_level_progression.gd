extends SceneTree
var errors=0
func _initialize(): call_deferred("run")
func check(ok,message):
 if not ok:
  errors+=1
  push_error(message)
func run():
 var progress=root.get_node("GameProgress")
 progress.save_path="res://.godot/progression_test.cfg"
 progress.completed.clear()
 var menu=load("res://scenes/level_select.tscn").instantiate()
 root.add_child(menu)
 current_scene=menu
 menu.get_node("Transition").cancel()
 for frontier in range(5):
  for n in range(5):
   var door=menu.get_node("Level"+str(n))
   check(door.unlocked==(n<=frontier),"Only completed and current level accessible")
   check(door.get_node("Door").disabled==(n>frontier),"Locked doors disabled")
  if frontier<4:
   menu._on_level_selected("res://scenes/level_4.tscn")
   check(menu.destination=="","Cannot bypass locked door through selection callback")
  progress.complete_level(frontier)
 progress.reset_all()
 check(not menu.get_node("Level1").unlocked,"Reset relocks later levels")
 var scenes=["tutorial_backdrop","level_1","level_2","level_3","level_4"]
 for i in range(5):
  var instance=load("res://scenes/"+scenes[i]+".tscn").instantiate()
  var expected="res://scenes/"+scenes[i+1]+".tscn" if i<4 else "res://scenes/level_select.tscn"
  check(instance.next_level_scene==expected,"Scene uses correct next level")
  instance.free()
 menu.queue_free()
 await process_frame
 DirAccess.remove_absolute("res://.godot/progression_test.cfg")
 print("Progression: ",errors," failures")
 quit(1 if errors else 0)
