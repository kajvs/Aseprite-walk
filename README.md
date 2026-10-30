# aseprite-walk-cycle — an Agent Skill

这是我自用的让 Agent 更好的操作 Aseprite 的 skill，其中包含将我自己画的单张静态四方向行走图转换为运动的三帧图片的 skill，但是这个功能并不是适用于所有人，因为这是我为我自己的画风所特化的。尽管如此，这个包里包含很多方便你的 Agent 更好使用 Aseprite 的脚本，它们会很有用。

![format](https://img.shields.io/badge/format-SKILL.md-blue)
[![aseprite](https://img.shields.io/badge/requires-Aseprite-green)](https://www.aseprite.org/)

**A skill (not a library, not a bot) that teaches a coding agent to turn *one* finished 32×32
character sprite into a 3-frame walk cycle — then merge front / back / side walks into a single
288×32 strip: nine 32×32 frames in one row, front 1-3, back 4-6, side 7-9.**

It is a mechanical, verifiable transformation, not a redraw: the character never changes,
only the legs (plus a 1px body bob) move.

## 安装（Installing）

Drop the folder into your agent's skills directory, keeping `SKILL.md` at its root:

| Harness | 目标位置 |
|---|---|
| DSH / 本仓库作者使用的 harness | `<DSH_HOME>/skills/aseprite-walk-cycle/` |
| Claude Code（项目内） | `<repo>/.claude/skills/aseprite-walk-cycle/` |
| 其他读 `skills/<name>/SKILL.md` 的框架 | 各自的 skills 根目录 |

`SKILL.md` 就是技能定义（YAML frontmatter + 正文），agent 加载它会自动获得这套流程的判据；
`templates/*.lua` 是可直接执行的 Aseprite 脚本。

## The rule

```
frame 2 = the original, pixel for pixel
frame 1 = whole image shifted DOWN 1 row (bottom row clipped)
          + both feet pulled 1px toward the centre
          + one foot one row shorter  (that is the raised foot)
frame 3 = same, the other foot is the short one
```

Derived by measuring a reference 9-frame walk sheet frame by frame: frame 1 differs from
"frame 2 shifted down 1 row" by only **34 of 1024** pixels, and every one of them sits in the foot rows.
That sheet is third-party art and is deliberately **not** included in this repository — only the
measurements are. Raw numbers in [`references/measurements.md`](references/measurements.md).

## What is inside

```
SKILL.md                     the method: when to use it, the 5 steps, the gotchas
references/measurements.md   measurements of the reference sheet, front / back / side (the evidence)
templates/probe.lua          measure: canvas, cel trim offsets, feet runs, ground profile
templates/make-walk.lua      build the 3 frames   (mode=front|side)
templates/verify-walk.lua    prove: frame2 == source, frame1/3 differ only in the bottom rows
templates/compose-sheet.lua  288x32 nine-frame strip + front/back/side tags
templates/cutout-bg.lua      strip a baked-in checkerboard / flat background
templates/preview.lua        magnified filmstrip so you can actually look at it
```

## Quick start

Requires [Aseprite](https://www.aseprite.org/) (scripted headless with `aseprite.exe -b --script`).

```powershell
$ase = 'C:\Program Files\Aseprite\Aseprite.exe'   # your install

# 1. measure — never guess foot coordinates
cmd /c "`"$ase`" --script-param spr=`"$sprite`" -b --script templates\probe.lua 2>&1"

# 2. build (front/back view; use mode=side for a side view)
cmd /c "`"$ase`" --script-param spr=`"$in`" --script-param out=`"$out`" --script-param mode=front --script-param lift=left -b --script templates\make-walk.lua 2>&1"

# 3. verify — the rule must hold
cmd /c "`"$ase`" --script-param a=`"$in`" --script-param b=`"$out.aseprite`" -b --script templates\verify-walk.lua 2>&1"

# 4. merge the three directions into one sheet
cmd /c "`"$ase`" --script-param front=... --script-param back=... --script-param side=... --script-param out=`"$sheet`" -b --script templates\compose-sheet.lua 2>&1"
```

Output: `.aseprite` (3 frames, tag `walk`, 180/140/180 ms) · `-strip.png` (96×32) · `.gif` · `-preview10x.png`.

Godot: `AnimatedSprite2D` with `hframes=9`, or three `SpriteFrames` animations taking frames
`[0,1,2]` / `[3,4,5]` / `[6,7,8]`.

## Before you trust it

Three things bite, all documented in `SKILL.md`:

1. **`Frame.duration` is in seconds**, not milliseconds — writing `180` silently clamps to 65.535 s.
2. **Cels are often trimmed** after importing a PNG, so `cel.position` must be honoured or every
   measurement is off by the offset (it will happily report "three feet").
3. **Black boots on a black skirt do not read** — keep the ankle row, or paint a lighter sole on the
   raised foot, or the walk looks like a static sprite.

## Compatibility

The Lua templates are plain [Aseprite Lua](https://www.aseprite.org/api/) and run on any OS —
drop `cmd /c` and use `/` path separators outside Windows.
Aseprite 1.3.x is required for `app.frames[i].duration` (seconds) and `spr:newTag`.

## License

本作品以 CC BY-NC-SA 4.0 发布，完整条款见 [LICENSE](LICENSE)。
