-- preview.lua — filmstrip of every frame, magnified, on a white background
-- Use it to actually LOOK at the animation before shipping it.
-- params: f=<sprite (.aseprite with N frames)>  out=<png>  [z=10]
local function rgb(c) return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c), app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c) end

local spr = app.open(app.params["f"])
if not spr then error("cannot open " .. tostring(app.params["f"])) end
local W, H = spr.width, spr.height
local N = #spr.frames
local Z = tonumber(app.params["z"] or "10")
local gap = 2

local out = Sprite((W + gap) * N * Z, H * Z, ColorMode.RGB)
local l = out.layers[1]; l.name = "preview"
out:newCel(l, 1, Image(out.width, out.height, ColorMode.RGB), Point(0, 0))
local oi = out.cels[1].image
for y = 0, out.height - 1 do for x = 0, out.width - 1 do oi:putPixel(x, y, Color(255, 255, 255, 255)) end end

for i = 1, N do
  local cv = {}
  for y = 0, H - 1 do cv[y] = {} for x = 0, W - 1 do cv[y][x] = { 0, 0, 0, 0 } end end
  for _, c in ipairs(spr.cels) do
    if c.frameNumber == i and c.layer.isVisible then
      local im = c.image
      for y = 0, im.height - 1 do
        for x = 0, im.width - 1 do
          local r, g, b, a = rgb(im:getPixel(x, y))
          local wx, wy = x + c.position.x, y + c.position.y
          if a > 8 and wx >= 0 and wx < W and wy >= 0 and wy < H then cv[wy][wx] = { r, g, b, a } end
        end
      end
    end
  end
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local p = cv[y][x]
      if p[4] > 8 then
        for dy = 0, Z - 1 do
          for dx = 0, Z - 1 do
            oi:putPixel(((i - 1) * (W + gap) + x) * Z + dx, y * Z + dy, Color(p[1], p[2], p[3], p[4]))
          end
        end
      end
    end
  end
end
out:saveCopyAs(app.params["out"])
out:close(); spr:close()
print(string.format("%d frame(s) at %dx -> %s", N, Z, tostring(app.params["out"])))
print("DONE")
