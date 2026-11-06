# 选关

`scenes/level_select.tscn` 为项目主场景（F5）。0 对应教学关，1 对应第一关，均可直接进入；序号在门下方。静态布局、按钮、数字和背景均在 tscn 中搭建。

门按钮显示区域为 180×213.33，数字位于下方；按四列预留位置，现有 0、1 位于第一行前两格，其余位置留白。后续按钮可使用同一场景，按 x=150/370/590/810、y=150/440 排列。数字由按钮自己的 level_number 在 refresh() 中同步，不依赖子节点文字覆盖，防止编辑器重新保存场景后都显示模板默认的 0。

`scenes/level_select_button.tscn` 是两关共用的选关按钮。未通关使用闭门素材；通关后使用开门星星素材；两种情况下 hover 都通过独立 ShaderMaterial 渐显门周围的金色光圈。三态素材原始画布保留 1280×800，通过 AtlasTexture 截取同一区域显示。

通关记录由 `GameProgress` 单例统一保存到 `user://progress.cfg`。两关通过基类的 `record_completion()` 在真实 `pass_level()` 中记录各自的 `level_number`；进入、失败、重置不会增加或清除记录。重新启动游戏仍会读回进度。原先已经玩过但尚未接入存档的历史结果无法自动推断。

教学关通关后进入第一关；第一关通关并播放花瓣结尾后回选关。两关左上角启动按钮右侧的返回箭头共用 `scenes/level_select_link.tscn`，调用基类 `return_to_level_select()`；返回、重玩保留已获通关记录。

返回按钮使用 `assets/ui/return_arrow.png` 的透明手绘素材，通过 AtlasTexture 显示图案区域；两关共用同一实例资源。

新增关卡时，在选关场景实例化同一按钮并填写 level_number / level_scene，在关卡根节点填写对应 level_number，再在本关 pass_level 中调用 record_completion() 即可，不另写进度存档。

回归测试请使用独立存档，避免测试覆盖实际游戏进度：

`Godot --headless --fixed-fps 60 --path . --script res://tests/test_level_select.gd -- --progress-file=user://tests/menu_boot.cfg`

运行其他会触发通关的测试时，同样在末尾传入 `-- --progress-file=user://tests/regression.cfg`。视觉测试去掉 --headless，并在末尾添加 --visual-check。
