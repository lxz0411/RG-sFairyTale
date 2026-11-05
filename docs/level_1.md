# 第一关：号角与蝴蝶

打开 `scenes/level_1.tscn` 后按 F6。教学关通关后也会进入本关。

- 点击收集两个号角和两朵花；右侧物品栏固定五格，蝴蝶和黄金花瓣为角色/机关。
- 左键拖动物品栏图标到场景，右键绕道具中心旋转；滚轮每格 5°，Q / E 连续旋转，尺寸固定。
- 左上角启动；复位将全部已收集的道具（含已摆放、正在拖动的）收回各自原格，并恢复蝴蝶、星星和花瓣。未收集的道具保持原处。
- 道具首次收集时按点击顺序分配格位；从物品栏拖出后保留该格空位，其他图标不移动，放回时仍回原格。
- 参考解：左上角小号朝右下；盘子里放 flower2；两吊灯之间的长号朝下；左侧高花瓶里放 flower1。道具自由摆放，松开鼠标保留实际位置和角度，不吸附或自动转正。
- 蝴蝶自由上升，靠近号角触发气流与声音。气流根据号角实际朝向、距离以及花的实际位置决定能否送达，飞行与停落目标随花的位置和角度变化，不检查预设摆放坐标。到达第一朵花后停留，再次上升进入第二段气流，经过星星后停在第二朵花上。
- 星星使用教学关素材和 Area2D 实际重叠检测；收集星星且最终停落后调用 pass_level，黄金花瓣飞向右上窗口，随后播放退出转场。
- 根节点可调 Flight Speed、Flower Rest Duration、Petal Flight Duration、Horn Trigger Radius、Wind Reach、Wind Cone Degrees 和 Next Level Scene；下一关暂设本关。
- 根节点的 Second Horn 分组可单独调整第二个号角：作用距离 850、送达速度 320、自由气流速度 560、持续时间 1 秒。没有目标花时气流仍按真实朝向吹动蝴蝶。
- 节点组织与教学关一致：道具为根节点下的 Sprite2D，星星使用 GoalStar/Trigger（star 分组），角色的 StarDetector 监听重叠；Inventory、ResetIcon、PlayIcon、音效及 Transition 均直接位于根节点下。
- 两关共同实例化 scenes/hand_drawn_inventory.tscn；五个手绘格子与图标位置均在场景中搭建，均匀排列于右侧。按钮使用同一套普通/选中素材。
- 两关继承 scripts/level_base.gd，共用按钮处理和 reset_level 入口；背包状态由 scripts/level_inventory.gd 统一管理，复用方式见 docs/shared_level_logic.md。
- `Anchors` 只保留蝴蝶出生点与花瓣离场窗口，不设置道具摆放目标；静态场景均保存于 tscn。
- `Butterfly/Wings` 使用 SpriteFrames 四帧序列及两个提供的姿态图；合翼帧用 AtlasTexture 补齐画布，保持动画中心一致。
- 两个号角分别使用柔和的高、低音短号声，含渐入渐出及轻微房间尾音，播放器音量为 -18 dB。声源 assets/level1/horn_blow.wav、horn_low.wav；运行 tools/generate_horn_audio.py 可重新生成。

当前背景使用 back_new.png，可在 Background.texture 中替换。

回归测试：Godot --headless --fixed-fps 60 --path . --script res://tests/test_level1_flow.gd
视觉验证：去掉 --headless 并加 --rendering-method gl_compatibility，末尾加 -- --visual-check。
