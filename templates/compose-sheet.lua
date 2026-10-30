-- compose-sheet.lua — merge the three walks into one strip in amy.png's format
--   288x32 PNG = 9 frames of 32x32:  front 1-3 | back 4-6 | side 7-9
-- params: front=<3-frame .aseprite>  back=<...>  side=<...>  out=<basename>
local function rgb(c) return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c), app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c) end

local FW, FH = 32, 32

local function framesOf(path)
  local spr = app.open(path)
  if not spr then error("cannot open " .. tostring(path)) end
  if spr.width ~= FW or spr.height ~= FH then
    error(string.format("%s is %dx%d, expected %dx%d (the amy format is 32x32 per frame)",
      path, spr.width, spr.height, FW, FH))
  end
  local list = {}
  for i = 1, #spr.frames do
    local cv = {}
    for y = 0, FH - 1 do cv[y] = {} for x = 0, FW - 1 do cv[y][x] = { 0, 0, 0, 0 } end end
    for _, c in ipairs(spr.cels) do
      if c.frameNumber == i and c.layer.isVisible then
        local im = c.image
        for y = 0, im.height - 1 do
          for x = 0, im.width - 1 do
            local r, g, b, a = rgb(im:getPixel(x, y))
            local wx, wy = x + c.position.x, y + c.position.y
            if a > 8 and wx >= 0 and wx < FW and wy >= 0 and wy < FH then cv[wy][wx] = { r, g, b, a } end
          end
        end
      end
    end
    list[i] = cv
  end
  print(string.format("  %-40s %d frames", path:match("[^\\/]+$"), #list))
  spr:close()
  return list
end

print("inputs:")
local front = framesOf(app.params["front"])
local back  = framesOf(app.params["back"])
local side  = framesOf(app.params["side"])
if #front ~= 3 or #back ~= 3 or #side ~= 3 then error("each walk must have exactly 3 frames") end

local N = 9
local outBase = app.params["out"]

-- flat strip = the PNG in amy format
local strip = Sprite(FW * N, FH, ColorMode.RGB)
local sl = strip.layers[1]; sl.name = "sheet"
strip:newCel(sl, 1, Image(FW * N, FH, ColorMode.RGB), Point(0, 0))
local si = strip.cels[1].image

-- multi-frame document = the editable .aseprite
local doc = Sprite(FW, FH, ColorMode.RGB)
local dl = doc.layers[1]; dl.name = "sheet"
for i = 2, N do doc:newEmptyFrame(i) end
local cels = {}
for i = 1, N do cels[i] = doc:newCel(dl, i, Image(FW, FH, ColorMode.RGB), Point(0, 0)) end

local groups = { { "front", front, 0 }, { "back", back, 3 }, { "side", side, 6 } }
local durs = { 0.18, 0.14, 0.18 }    -- seconds
for _, g in ipairs(groups) do
  local name, list, base = g[1], g[2], g[3]
  for i = 1, 3 do
    local idx = base + i
    local cv = list[i]
    for y = 0, FH - 1 do
      for x = 0, FW - 1 do
        local p = cv[y][x]
        local col = Color(p[1], p[2], p[3], p[4])
        si:putPixel((idx - 1) * FW + x, y, col)
        cels[idx].image:putPixel(x, y, col)
      end
    end
    doc.frames[idx].duration = durs[i]
  end
  local t = doc:newTag(1)
  t.name = name
  t.fromFrame = doc.frames[base + 1]
  t.toFrame = doc.frames[base + 3]
  print(string.format("tag %-6s frames %d..%d", name, base + 1, base + 3))
end

doc:saveAs(outBase .. ".aseprite")
strip:saveCopyAs(outBase .. ".png")

-- 4x preview of the whole sheet
local Z = tonumber(app.params["z"] or "4")
local pv = Sprite(FW * N * Z, FH * Z, ColorMode.RGB)
local pl = pv.layers[1]; pl.name = "preview"
pv:newCel(pl, 1, Image(pv.width, pv.height, ColorMode.RGB), Point(0, 0))
for y = 0, pv.height - 1 do for x = 0, pv.width - 1 do pv.cels[1].image:putPixel(x, y, Color(255, 255, 255, 255)) end end
for y = 0, FH - 1 do
  for x = 0, FW * N - 1 do
    local r, g, b, a = rgb(si:getPixel(x, y))
    if a > 8 then
      for dy = 0, Z - 1 do
        for dx = 0, Z - 1 do pv.cels[1].image:putPixel(x * Z + dx, y * Z + dy, Color(r, g, b, a)) end
      end
    end
  end
end
pv:saveCopyAs(outBase .. "-preview" .. Z .. "x.png")
pv:close(); strip:close(); doc:close()
print("sheet: " .. (FW * N) .. "x" .. FH .. "  ->  " .. outBase .. ".png / .aseprite")
print("Godot: AnimatedSprite2D hframes=9, or three SpriteFrames animations using [0,1,2] [3,4,5] [6,7,8]")
print("DONE")
