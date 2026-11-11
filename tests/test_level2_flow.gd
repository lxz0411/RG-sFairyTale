extends SceneTree
var level
var errors := 0
func _initialize(): call_deferred("run")
func place(n,p,r):
 var item=level.get_node(n)
 if not item.collected: level.collect_item(item)
 level.begin_drag(item,level.slot_center(item))
 item.position=p
 level.finish_drag()
 level.selected=item
 level.rotate_item(r-item.rotation)
func check(ok,message):
 if not ok:
  errors+=1
  push_error(message)
func simulate():
 var seen={"loaded":false,"wet":false,"grown":false,"complete":false}
 level.start_level()
 var checked_contact=false
 for tick in range(1500):
  await physics_frame
  if level.attached and absf(level.get_node("Support").rotation)>0.2 and not checked_contact:
   checked_contact=true
   var support=level.get_node("Support")
   var can=level.get_node("Can")
   var a=support.to_local(can.to_global(Vector2(-23,75))) * support.scale
   var b=support.to_local(can.to_global(Vector2(38,61))) * support.scale
   var contact=Geometry2D.get_closest_points_between_segments(a,b,Vector2(-39,-29),Vector2(45,-5))
   check(contact[0].distance_to(contact[1])<=24.1,"Can base stays in contact with rotating tray")
  seen.loaded=seen.loaded or level.loaded
  seen.wet=seen.wet or level.wetness>=0.5
  seen.grown=seen.grown or level.growth>=0.95
  if level.phase==level.Phase.COMPLETE:
   seen.complete=true
   break
  if level.phase==level.Phase.EDIT: break
 return seen
func shot(n):
 if "--visual-check" in OS.get_cmdline_user_args():
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.godot/level2_"+n+".png")
func run():
 var progress=root.get_node("GameProgress")
 progress.save_path="res://.godot/level2_test_progress.cfg"
 progress.completed.clear()
 level=load("res://scenes/level_2.tscn").instantiate()
 root.add_child(level)
 current_scene=level
 level.next_level_scene=""
 level.get_node("Transition").cancel()
 check(level.items.size()==2,"Only bamboo and watering can are movable")
 check(level.find_children("*","Label",true,false).is_empty(),"No text UI")
 await shot("initial")
 place("Can",Vector2(400,560),0.0)
 level.get_node("Mushroom").show()
 level.get_node("Mushroom").scale=Vector2(0.095,0.095)
 check(level.mushroom_can_overlap()>0,"Mushroom detects painted can underside")
 level.resolve_mushroom_can_contact()
 check(level.mushroom_can_contact and level.mushroom_can_overlap()<=0.1,"Mushroom lifts intersecting can clear of cap")
 level.reset_level()
 place("Bamboo",Vector2(650,250),-0.4)
 level.start_level()
 for tick in range(40): await physics_frame
 check(is_instance_valid(level.bamboo) and level.bamboo.position.y>300,"Unsupported bamboo falls instead of remaining an airborne ramp")
 level.reset_level()
 check(level.get_node("Bamboo").position==Vector2(650,250),"Reset restores player pose after gravity simulation")
 place("Bamboo",Vector2(280,460),0.0)
 place("Can",Vector2(262,645),0.0)
 level.backpack.store(level.get_node("Bamboo"))
 var absent=await simulate()
 check(not absent.loaded and not absent.complete,"Missing bamboo fails")
 level.reset_level()
 place("Bamboo",Vector2(280,460),0.0)
 level.backpack.store(level.get_node("Can"))
 var dry=await simulate()
 check(dry.loaded and not dry.wet and not dry.complete,"Missing watering can leaves apple waiting")
 level.reset_level()
 # Rotate the spout away, but keep its base on the support.
 place("Can",Vector2(217,775),PI)
 var wrong=await simulate()
 check(not wrong.wet and not wrong.complete,"Wrong direction cannot water mushroom")
 level.reset_level()
 place("Can",Vector2(262,645),0.0)
 var bamboo_pose=level.get_node("Bamboo").transform
 var can_pose=level.get_node("Can").transform
 await shot("layout")
 var success=await simulate()
 print("CHAIN ",success)
 check(success.loaded and success.wet and success.grown and success.complete,"Full contact, watering, growth and nest chain succeeds")
 check(level.settled>=0.55,"Apple must settle in nest")
 check(progress.is_completed(2) and not progress.is_completed(3),"Only level 2 completion saved")
 await shot("result")
 level.reset_level()
 check(level.get_node("Bamboo").transform==bamboo_pose and level.get_node("Can").transform==can_pose,"Retry preserves placement and rotation")
 check(level.wetness==0 and level.growth==0 and level.physics_root==null,"Reset clears water, growth and physics")
 level.start_level()
 await physics_frame
 level.reset_level()
 for tick in range(30): await physics_frame
 check(level.phase==level.Phase.EDIT,"Mid-run reset cancels simulation")
 place("Bamboo",Vector2(280,460),TAU)
 check(absf(level.get_node("Bamboo").rotation)<0.001,"Continuous full rotation supported")
 level.return_to_level_select()
 await process_frame
 await process_frame
 var names=["Level0","Level1","Level2","Level3","Level4"]
 for i in range(5):
  check(current_scene.get_node(names[i]+"/Number").text==str(i),"Restored five-level numbering")
 check(current_scene.get_node("Level2").completed,"Menu displays level 2 completion")
 current_scene.get_node("Transition").cancel()
 current_scene._on_reset_progress_pressed()
 check(not current_scene.get_node("Level2").completed,"Clear progress refreshes second level")
 current_scene.get_node("Level2/Door").pressed.emit()
 await current_scene.get_node("Transition").covered
 await process_frame
 await process_frame
 check(current_scene.scene_file_path=="res://scenes/level_2.tscn","Second door enters correct scene")
 current_scene.queue_free()
 await process_frame
 DirAccess.remove_absolute("res://.godot/level2_test_progress.cfg")
 print("Level 2 flow: ",errors," failures")
 quit(1 if errors else 0)
