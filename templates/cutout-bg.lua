-- cutout-bg.lua — remove a baked-in background (checkerboard or flat grey)
-- Many upscaled/AI-produced "pixel art" PNGs ship with the transparency checkerboard
-- burned into the pixels. This removes it in two passes:
--   pass 1: flood fill from the border through neutral greys  (the open background)
--   pass 2: every remaining neutral grey                      (patches enclosed by the figure)
-- Warm greys (hair/leather shading) survive because they are not neutral.
--
-- params: spr=<path>  out=<basename>  [tol=18] [vmin=0.30] [vmax=0.88] [sat=0.07]
local function rgb(c) return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c), app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c) end

local TOL  = tonumber(app.params["tol"]  or "18")
local VMIN = tonumber(app.params["vmin"] or "0.30")
local VMAX = tonumber(app.params["vmax"] or "0.88")
local SAT  = tonumber(app.params["sat"]  or "0.07")

local src = app.open(app.params["spr"])
if not src then error("cannot open " .. tostring(app.params["spr"])) end
local W, H = src.width, src.height
local img = src.cels[1].image
local offx, offy = src.cels[1].position.x, src.cels[1].position.y
local function px(x, y) return rgb(img:getPixel(x - offx, y - offy)) end   -- cel may be trimmed

local function neutral(r, g, b)
  return math.abs(r - g) <= TOL and math.abs(g - b) <= TOL and math.abs(r - b) <= TOL
end
local function backgroundish(r, g, b)
  local v = math.max(r, g, b) / 255
  return neutral(r, g, b) and v > VMIN and v < VMAX
end
local function neutralGrey(r, g, b)
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local s = mx == 0 and 0 or (mx - mn) / mx
  local v = mx / 255
  return s < SAT and v > VMIN and v < VMAX
end

local kill = {}
for y = 0, H - 1 do kill[y] = {} end

local stack = {}
for x = 0, W - 1 do stack[#stack + 1] = { x, 0 }; stack[#stack + 1] = { x, H - 1 } end
for y = 0, H - 1 do stack[#stack + 1] = { 0, y }; stack[#stack + 1] = { W - 1, y } end
local p1 = 0
while #stack > 0 do
  local p = table.remove(stack)
  local x, y = p[1], p[2]
  if x >= 0 and x < W and y >= 0 and y < H and not kill[y][x] then
    local r, g, b, a = px(x, y)
    if a > 8 and backgroundish(r, g, b) then
      kill[y][x] = true
      p1 = p1 + 1
      stack[#stack + 1] = { x - 1, y }; stack[#stack + 1] = { x + 1, y }
      stack[#stack + 1] = { x, y - 1 }; stack[#stack + 1] = { x, y + 1 }
    end
  end
end

local p2 = 0
for y = 0, H - 1 do
  for x = 0, W - 1 do
    if not kill[y][x] then
      local r, g, b, a = px(x, y)
      if a > 8 and neutralGrey(r, g, b) then kill[y][x] = true; p2 = p2 + 1 end
    end
  end
end
print("pass1 (border flood) removed: " .. p1)
print("pass2 (enclosed neutral grey) removed: " .. p2)

local out = Sprite(W, H, ColorMode.RGB)
local l = out.layers[1]; l.name = "sprite"
out:newCel(l, 1, Image(W, H, ColorMode.RGB), Point(0, 0))
local oi = out.cels[1].image
local kept, semi = 0, 0
for y = 0, H - 1 do
  for x = 0, W - 1 do
    if kill[y][x] then
      oi:putPixel(x, y, Color(0, 0, 0, 0))
    else
      local r, g, b, a = px(x, y)
      oi:putPixel(x, y, Color(r, g, b, a))
      if a > 8 then kept = kept + 1 end
      if a > 8 and a < 250 then semi = semi + 1 end
    end
  end
end
print(string.format("kept %d opaque px, %d semi-transparent (should be 0)", kept, semi))
out:saveAs(app.params["out"] .. ".aseprite")
out:saveCopyAs(app.params["out"] .. ".png")
out:close(); src:close()
print("written: " .. app.params["out"] .. ".png / .aseprite")
print("DONE")
