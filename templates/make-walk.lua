-- make-walk.lua — build a 3-frame walk cycle from ONE character sprite
-- The rule (measured from amy.png):
--   frame 2  = the original, verbatim
--   frame 1/3 = whole image shifted down 1 row (bottom row clipped = "one cell less"),
--               feet pulled toward the centre, one foot one row shorter = the raised foot.
--
-- params:
--   spr=<path>      source sprite (.aseprite / .png)
--   out=<base>      output basename -> .aseprite, -strip.png, .gif, -preview10x.png
--   mode=front      front|back view: two feet on the ground row, both pulled inward
--        side       side view: legs merged in one column -> split into front/back feet
--   lift=left       (mode=front) which screen-side foot comes up: left|right
--        front      (mode=side)  which foot comes up: front|back
--   [ankleOffset=1] mode=side only: the raised foot uses rows (GROUND-ankleOffset, GROUND)
--                   use 2 when the boots are the same colour as the skirt (keeps the ankle
--                   row visible so the two legs stay readable)
--   [dxIn=1]        mode=front: how far each foot moves toward the centre
--   [fx0=][fw=][bx0=][bw=]  mode=side: explicit front/back foot placement
local function rgb(c) return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c), app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c) end

local srcPath = app.params["spr"]
local outBase = app.params["out"]
if not srcPath or not outBase then error("usage: --script-param spr=<path> --script-param out=<base> ...") end
local MODE = app.params["mode"] or "front"
local LIFT = app.params["lift"] or "left"
local ANKLE = tonumber(app.params["ankleOffset"] or "1")
local DXIN = tonumber(app.params["dxIn"] or "1")
local SIDE_PRINTED = false

local src = app.open(srcPath)
if not src then error("cannot open " .. srcPath) end
local W, H = src.width, src.height
local GROUND = H - 1

-- ---- snapshot frame 1 onto a full canvas (cels may be trimmed) --------------
local SNAP = {}
for y = 0, H - 1 do SNAP[y] = {} for x = 0, W - 1 do SNAP[y][x] = { 0, 0, 0, 0 } end end
for _, c in ipairs(src.cels) do
  if c.frameNumber == 1 and c.layer.isVisible then
    local im = c.image
    for y = 0, im.height - 1 do
      for x = 0, im.width - 1 do
        local r, g, b, a = rgb(im:getPixel(x, y))
        local wx, wy = x + c.position.x, y + c.position.y
        if a > 8 and wx >= 0 and wx < W and wy >= 0 and wy < H then SNAP[wy][wx] = { r, g, b, a } end
      end
    end
  end
end

-- ---- feet on the ground row ------------------------------------------------
local runs, s = {}, -1
for x = 0, W do
  local opaque = (x < W) and SNAP[GROUND][x][4] > 8
  if opaque and s < 0 then s = x end
  if not opaque and s >= 0 then runs[#runs + 1] = { s, x - 1 }; s = -1 end
end
print(string.format("ground row y%d: %d run(s)", GROUND, #runs))
if MODE == "front" and #runs ~= 2 then
  error("mode=front needs exactly 2 feet on the ground row, found " .. #runs .. " (try mode=side)")
end
if MODE == "side" and #runs ~= 1 then
  error("mode=side needs the legs merged into 1 run, found " .. #runs .. " (try mode=front)")
end

local spr = Sprite(W, H, ColorMode.RGB)
local layer = spr.layers[1]; layer.name = "walk"
spr:newEmptyFrame(2); spr:newEmptyFrame(3)
local function celOf(f) return spr:newCel(layer, f, Image(W, H, ColorMode.RGB), Point(0, 0)) end
local f1, f2, f3 = celOf(1), celOf(2), celOf(3)

local function clear(img)
  for y = 0, H - 1 do for x = 0, W - 1 do img:putPixel(x, y, Color(0, 0, 0, 0)) end end
end
local function put(img, x, y, p)
  if x >= 0 and x < W and y >= 0 and y < H and p[4] > 8 then img:putPixel(x, y, Color(p[1], p[2], p[3], p[4])) end
end

-- frame 2: verbatim
clear(f2.image)
for y = 0, H - 1 do for x = 0, W - 1 do put(f2.image, x, y, SNAP[y][x]) end end

-- everything above the legs, shifted down one row
local function bodyDown(img)
  for y = 0, GROUND - 3 do
    for x = 0, W - 1 do put(img, x, y + 1, SNAP[y][x]) end
  end
end

-- copy a horizontal slice of a source row
local function slice(img, srcY, sx0, w, dstX, dstY)
  for i = 0, w - 1 do
    local sx = sx0 + i
    if sx >= 0 and sx < W then put(img, dstX + i, dstY, SNAP[srcY][sx]) end
  end
end

-- front / back: planted foot = two rows on the ground, raised foot = its ground row one row up
local function buildFront(img, liftLeft)
  clear(img)
  bodyDown(img)
  local L, R = runs[1], runs[2]
  local function planted(run, dx)
    local w = run[2] - run[1] + 1
    slice(img, GROUND - 1, run[1], w, run[1] + dx, GROUND - 1)
    slice(img, GROUND,     run[1], w, run[1] + dx, GROUND)
  end
  local function raised(run, dx)
    local w = run[2] - run[1] + 1
    slice(img, GROUND, run[1], w, run[1] + dx, GROUND - 1)
  end
  if liftLeft then
    raised(L, DXIN); planted(R, -DXIN)
  else
    planted(L, DXIN); raised(R, -DXIN)
  end
end

-- side: one merged column -> split into a front and a back foot (stride)
local function buildSide(img, liftFront)
  clear(img)
  bodyDown(img)
  local run = runs[1]
  local rw = run[2] - run[1] + 1
  local FX0 = tonumber(app.params["fx0"] or tostring(math.max(0, run[1] - 2)))
  local FW  = tonumber(app.params["fw"]  or tostring(math.max(2, rw - 1)))
  local BX0 = tonumber(app.params["bx0"] or tostring(math.min(W - 1, run[1] + 3)))
  local BW  = tonumber(app.params["bw"]  or tostring(math.max(2, rw - 1)))
  local srcUpper = GROUND - ANKLE      -- ankle / upper boot row of the source
  local function foot(x0, w, upperY)
    slice(img, srcUpper, run[1], w, x0, upperY)
    slice(img, GROUND,   run[1], w, x0, upperY + 1)
  end
  if liftFront then
    foot(BX0, BW, GROUND - 1)          -- planted, reaches the ground
    foot(FX0, FW, GROUND - 2)          -- raised, one row up
  else
    foot(FX0, FW, GROUND - 1)
    foot(BX0, BW, GROUND - 2)
  end
  if not SIDE_PRINTED then
    SIDE_PRINTED = true
    print(string.format("stride: front x%d..%d (%d), back x%d..%d (%d), gap %d",
      FX0, FX0 + FW - 1, FW, BX0, BX0 + BW - 1, BW, BX0 - (FX0 + FW)))
  end
end

if MODE == "front" then
  buildFront(f1.image, LIFT == "left")
  buildFront(f3.image, LIFT ~= "left")
else
  buildSide(f1.image, LIFT == "front")
  buildSide(f3.image, LIFT ~= "front")
end

-- Frame.duration is in SECONDS in Aseprite's Lua API (180 ms = 0.18)
spr.frames[1].duration = 0.18
spr.frames[2].duration = 0.14
spr.frames[3].duration = 0.18
local tag = spr:newTag(1)
tag.name = "walk"; tag.fromFrame = spr.frames[1]; tag.toFrame = spr.frames[3]

spr:saveAs(outBase .. ".aseprite")
spr:saveCopyAs(outBase .. ".gif")

-- horizontal strip, 1:1 (engine ready)
local strip = Sprite(W * 3, H, ColorMode.RGB)
local sl = strip.layers[1]; sl.name = "strip"
strip:newCel(sl, 1, Image(W * 3, H, ColorMode.RGB), Point(0, 0))
for i, c in ipairs(spr.cels) do
  for y = 0, H - 1 do
    for x = 0, W - 1 do strip.cels[1].image:putPixel((i - 1) * W + x, y, c.image:getPixel(x, y)) end
  end
end
strip:saveCopyAs(outBase .. "-strip.png")
strip:close()

-- filmstrip preview
local Z, gap = tonumber(app.params["z"] or "10"), 2
local pv = Sprite((W + gap) * 3 * Z, H * Z, ColorMode.RGB)
local pl = pv.layers[1]; pl.name = "preview"
pv:newCel(pl, 1, Image(pv.width, pv.height, ColorMode.RGB), Point(0, 0))
for y = 0, pv.height - 1 do for x = 0, pv.width - 1 do pv.cels[1].image:putPixel(x, y, Color(255, 255, 255, 255)) end end
for i, c in ipairs(spr.cels) do
  local im = c.image
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local r, g, b, a = rgb(im:getPixel(x, y))
      if a > 8 then
        for dy = 0, Z - 1 do
          for dx = 0, Z - 1 do
            pv.cels[1].image:putPixel(((i - 1) * (W + gap) + x) * Z + dx, y * Z + dy, Color(r, g, b, a))
          end
        end
      end
    end
  end
end
pv:saveCopyAs(outBase .. "-preview" .. Z .. "x.png")
pv:close(); spr:close(); src:close()
print("written: " .. outBase .. ".aseprite / -strip.png / .gif / -preview" .. Z .. "x.png")
print("next: run templates/verify-walk.lua, then LOOK at the preview")
print("DONE")
