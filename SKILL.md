---
name: aseprite-walk-cycle
description: Turn one existing character sprite into a 3-frame walk cycle with Aseprite scripting — measure the feet, shift the whole image down one row, pull both feet one pixel toward the centre, shorten the raised foot by one row, prove frame 2 is byte-identical to the source, then combine front/back/side into a single 288x32 strip of nine 32x32 frames (front 1-3, back 4-6, side 7-9). Use when asked to animate a sprite walking, stepping, marching, or to build a directional walk spritesheet from finished character art.
---

# 从一张立绘生成行走图（3 帧法）

一套**可验证**的机械变换，不是重画：角色本身一格不动，只有腿（和整体 1px 的起伏）在变。
本 skill 的方法来自对一张第三方参考行走精灵条（9 帧，**不随本仓库分发**）的逐像素实测，
数据见 `references/measurements.md`；在本机 Aseprite 1.3.18.6 上跑通过三种朝向的完整闭环。

## 0. 什么时候用 / 不用

**用**：手上已经有一张画好的 32×32（或同比例）角色图，需要走路/踏步动画；需要把正面、背面、侧面
行走合成一张 288×32 的九帧精灵表（正 1-3 / 背 4-6 / 侧 7-9）。

**不用**：需要真正的手绘步态（跨步、手臂摆动、腾空）——那是 8 帧 contact/down/pass/up 的活，
交给 `pixel-art-craft` 的 `rules/42-walk-and-run.md`。本 skill 做的是**三帧原地踏步**，
适合俯视/四向 RPG 的极简行走。

## 1. 前置

```powershell
$ase = 'D:\Softwares\Steam\steamapps\common\Aseprite\Aseprite.exe'   # 找不到就问用户，别退化去用 Pillow
```
先加载 `aseprite-pixel-art`（Aseprite 无头执行的通用套路与坑）和 `pixel-art-craft`（像素画判据）。
Aseprite 调用的两条铁律（踩过的坑，别自己发明）：
- `--script-param k=v` **必须全部写在 `-b --script x.lua` 之前**，写在后面会被静默忽略。
- 用 `cmd /c "..."` 调，PowerShell 直接 `& $ase` 不会等 GUI 进程。
- 非 Windows：直接调用 Aseprite 可执行文件即可，把示例里的 `cmd /c` 去掉、路径分隔符换成 `/`。

## 2. 规律：三帧，中间帧是原图

| 帧 | 做法 |
|---|---|
| **帧2** | 原图逐像素不动（这是"基准帧"） |
| **帧1** | 整图向下移 1 行（底行被裁掉 = 少一格）→ 身体下沉 1px 的起伏；两脚各向中间移动 1px；**一只脚少画一行**（抬起来的那只） |
| **帧3** | 同帧1，但换成另一只脚抬起 |

关键三条，别搞错：
1. **抬脚 = 少一行**，不是往上画。那只脚在地面之上留下 1px 空的间隙。
2. **两脚向中间移动**：左脚 +1、右脚 −1。原本分开的双脚在这一帧会靠拢甚至合并——这是对的。
3. **身体（除 1px 起伏外）不动**：头和躯干相对位置完全不变。

## 3. 五步流程

### 第 1 步：量（必须做，别凭肉眼猜坐标）

```powershell
cmd /c "`"$ase`" --script-param spr=`"$sprite`" -b --script `"templates\probe.lua`" 2>&1"
```
`probe.lua` 输出：画布尺寸、**每个 cel 的 position（裁切偏移）**、逐帧包围盒、
落地行上的脚（不透明像素的连续段，run）、每列最低不透明行（ground profile）、主色统计。

要拿到的东西：
- **落地行**（通常是最后一行，且脚一定踩在上面）
- **几只脚**：正面/背面 = 两个 run（双脚分开）；侧面 = 一个 run（双腿并成一根柱子）
- **脚的 x 区间**和宽度

### 第 2 步：选模板模式

| 情况 | 模式 | 说明 |
|---|---|---|
| 两个 run（正面、背面） | `mode=front` | 保持两脚，各自向中间收 1px；一只脚缩 1 行 |
| 一个 run（侧面） | `mode=side` | 把并起来的腿拆成前后两只脚：前脚 + 后脚，一只抬 1 行（透视上后脚更高、更窄） |

### 第 3 步：生成

```powershell
# 正面 / 背面
cmd /c "`"$ase`" --script-param spr=`"$in`" --script-param out=`"$out`" --script-param mode=front --script-param lift=left -b --script `"templates\make-walk.lua`" 2>&1"

# 侧面（一个 run → 前后跨步）
cmd /c "`"$ase`" --script-param spr=`"$in`" --script-param out=`"$out`" --script-param mode=side --script-param lift=front -b --script `"templates\make-walk.lua`" 2>&1"
```
脚本会自己量脚、生成 3 帧、写 `.aseprite`（tag `walk`，180/140/180ms）、`-strip.png`（96×32）、`.gif`、`-preview10x.png`。

### 第 4 步：验证（不可跳过）

```powershell
cmd /c "`"$ase`" --script-param a=`"$in`" --script-param b=`"$out.aseprite`" -b --script `"templates\verify-walk.lua`" 2>&1"
```
必须满足：
- `frame2 vs source differences: 0` —— 基准帧和原图逐像素一致
- 帧1/帧3 与"原图整体下移 1 行"的差异**只出现在底部几行**（`all in bottom rows: true`）

### 第 5 步：看

`read_image` 打开 `-preview10x.png` 和 `.gif`。**没看图不许说完成**。
看什么：抬起来的那只脚能不能一眼认出来（见第 5 节）；两帧的起伏方向对不对；循环接缝有没有跳。

## 4. 三种朝向

| 朝向 | 脚的来源 | 处理 |
|---|---|---|
| 正面 | 两个 run | 向中收 1px，抬一只 |
| 背面 | 两个 run（背面的左右和本人一致） | 同上；背面图通常需要先把脸用头发盖掉再当基准帧 |
| 侧面 | 一个 run | 拆成前后脚：前脚 x 区间 ≈ run 左移 2，后脚 ≈ run 右移 2~3，中间留 1~2px 空隙；抬起来的那只整体高 1 行 |

**背面图怎么来**（如果只有正面图）：把五官区域（眉毛/眼睛/鼻嘴/下巴的肤色）整块填成头发色——
主体发色 + 正中一条稍暗当发缝 + 最下沿暗一档当头发转进脖子；然后水平镜像（从背后看左右是反的）。

## 5. 可读性判据（这条最容易翻车）

**裙子和鞋同色时，抬脚是看不出来的。** 实测：黑裙 + 纯黑靴（`#070605` vs `#0A0A0A`），
只挪动脚的形状，整条腿会和裙摆糊成一坨。三种补救，按优先级：

1. **保留原图的脚踝行**（肤色/浅色那行）——它天然是腿和裙子的分隔。抬起的脚 = 脚踝 + 靴子各一行，整体高一格。
2. **抬起的脚露出鞋底**：给那一行换成略浅的鞋底色（参考图里靴子的高光色）。透视上正好看得见鞋底。
3. 都做不到就**加宽跨步**，让抬起的脚越出裙摆剪影，靠背后的透明间隙把它读出来。

另外：`pixel-art-craft` 的"A cluster is a form, a single pixel is noise"在这里同样适用——
抬起的脚至少要 3 个像素连成一行，1 个孤立像素不算脚。

## 6. 合成九帧精灵表（288×32）

```powershell
cmd /c "`"$ase`" --script-param front=`"$front.aseprite`" --script-param back=`"$back.aseprite`" --script-param side=`"$side.aseprite`" --script-param out=`"$sheet`" -b --script `"templates\compose-sheet.lua`" 2>&1"
```
产物：`<out>.png` = **288×32**（9 帧 × 32px，单行），`<out>.aseprite` = 9 帧 + `front`/`back`/`side` 三个 tag。

```
帧 1-3 = 正面   帧 4-6 = 背面   帧 7-9 = 侧面      ← 顺序固定，别改
```
Godot：`AnimatedSprite2D` + `hframes=9`，或用 3 个 `SpriteFrames` 动画各取 `[0,1,2]/[3,4,5]/[6,7,8]`；
纯精灵条场景 `sprite_fps ≈ 6`（180/140/180ms ≈ 6.7/7.1/5.6 fps，取平均 6）。

## 7. 坑清单（全部在本机实测踩过）

| 坑 | 现象 | 正确做法 |
|---|---|---|
| `Frame.duration` 单位是**秒** | 赋 `180` 想得到 180ms，实际被夹到 65.535s | 写 `0.18`；读回来核对 |
| **cel 会被裁切** | 从 PNG 载入的 `.aseprite` 里 `cel.position` 可能是 `(3,0)`，直接按 `cels[1].image` 读像素会整体偏移，量到"三只脚" | 一律先按 `position` 合成整幅快照再量；dump/预览脚本同理 |
| `--script-param` 位置 | 放在 `--script` 后面被静默忽略，脚本拿到 nil 还照跑 | 全部放 `-b` 前面 |
| `& $ase` 不等待 | `$LASTEXITCODE` 为空、输出抓不到 | `cmd /c "..."` |
| 参考图里有烤死的棋盘格 | 背景不是透明而是两色灰 | `templates/cutout-bg.lua` 两遍：边框洪水 + 中性灰兜底（被人物围住的灰块只有第二遍能清掉） |
| 只导出不验证 | 帧2 被"顺手"改过、抬脚落到帽子上 | 跑 `verify-walk.lua` + `read_image` |
| 帧1/3 忘裁底行 | 脚穿出画布，动画一抖 | 整图下移就是"少一格"，底部本来就会被裁 |

## 8. 交付清单

- `<name>.aseprite` —— 3 帧、tag `walk`、时长 180/140/180ms
- `<name>-strip.png` —— 96×32（单方向）或 288×32（三向）
- `<name>.gif` —— 动图预览
- `<name>-preview10x.png` —— 肉眼看图用
- 汇报时说明：抬的是哪只脚、抬起行的处理方式（脚踝/鞋底）、以及是否对原图做过任何像素改动（应当为 0）

## 9. 模板与参考

| 文件 | 作用 |
|---|---|
| `templates/probe.lua` | 量尺寸/cel 偏移/包围盒/落地行脚/ground profile/主色 |
| `templates/make-walk.lua` | 生成 3 帧（`mode=front\|side`） |
| `templates/verify-walk.lua` | 帧2 一致性 + 帧1/3 差异范围校验 |
| `templates/compose-sheet.lua` | 288×32 九帧精灵表 + 三个 tag |
| `templates/preview.lua` | 多帧动画的放大对照图 |
| `templates/cutout-bg.lua` | 去掉烤进像素的背景（棋盘格/纯色） |
| `references/measurements.md` | 参考样例三组帧的实测数据（本方法的出处；样例本身不随仓库分发）|

## 10. 许可

本 skill 以 **CC BY-NC-SA 4.0** 发布（署名 + 非商业 + 相同方式共享），作者 kajvs
（<https://github.com/kajvs>），条款见仓库根目录的 `LICENSE`。
生成出来的精灵图属于你的素材，不受本许可约束。
