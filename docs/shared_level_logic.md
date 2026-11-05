# 关卡共用逻辑

教学关和第一关都继承 `scripts/level_base.gd`，共同实例化 `scenes/hand_drawn_inventory.tscn`。物品栏五格及图标节点保存在场景中；运行时不生成静态 UI。

`scripts/level_inventory.gd` 是唯一的背包实现：

- `collect(item)` 在首次收集时按点击顺序分配格位，后续一直保留。
- `begin_drag(item)`、`deploy(item)`、`store(item)` 统一处理图标、道具显隐及收纳状态。拖出不会挤动其他格位，放回任意物品栏位置都回原格。
- `recall_all()` 收回所有已收集道具，包括正在拖动的道具。未收集的道具不受影响。
- `item_at(point)` 与 `slot_center(item)` 按实际格位处理命中和引导，禁止用道具编号当格位编号。

所有可收集道具使用 `scripts/level_item.gd`；它保存 `collected`、`deployed` 和道具标识，所有关卡使用同一套状态含义。

`scripts/level_base.gd` 提供统一的 `collect_item(item)`、`reset_level()`、按钮纹理和点击处理。重置依次取消转场、停止关卡活动、收回道具、停止音效、恢复按钮、重置本关模拟。关卡不再定义各自的背包列表或重置入口。

新关卡接入方式：

1. 继承 `res://scripts/level_base.gd`，在场景中复用 `Inventory`，保留 `ResetIcon`、`PlayIcon`、`PickupSound` 和 `Transition` 节点。
2. 输入处理首先调用 `handle_level_input(event)`，返回 true 时结束本次处理；收集调用基类的 `collect_item(item)`，背包交互调用 `backpack` 的方法。
3. 实现 `can_edit()`、`start_level()`；需要额外引导限制时覆盖 `allows_start(point)`。
4. `stop_level_activity()` 只停止本关角色/机关动画和清理操作状态；`reset_simulation()` 只恢复角色、机关和关卡阶段。道具收回、声音停止及 UI 复位由基类完成，不在子关卡重复实现。

回归：`Godot --headless --fixed-fps 60 --path . --script res://tests/test_shared_inventory.gd`。测试通过真实点击/拖动验证两关的收集顺序、格位保留、放回、运行中及拖动中单击重置，以及未收集道具和教学遮罩的状态。
