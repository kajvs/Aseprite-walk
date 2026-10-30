-- probe.lua — measure a character sprite before building a walk cycle
-- params:  spr=<path>        sprite to measure (.aseprite or .png)
--          [frame=1]         which frame to measure
-- prints:  canvas size, cels (with trim offsets), bbox, feet runs on the ground row,
--          per-column lowest opaque row (ground profile), palette census
local function rgb(c) return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c), app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c) end

local spr = app.open(app.params["spr"])
if not spr then error("cannot open " .. tostring(app.params["spr"])) end
local W, H = spr.width, spr.height
local FRAME = tonumber(app.params["frame"] or "1")
local GROUND = H - 1
print(string.format("== %s", tostring(spr.filename or app.params["spr"])))
print(string.format("canvas %dx%d   frames=%d layers=%d cels=%d", W, H, #spr.frames, #spr.layers, #spr.cels))

-- cels: a PNG import is often TRIMMED, so cel.position matters
for _, c in ipairs(spr.cels) do
  if c.frameNumber == FRAME then
    print(string.format("  cel frame=%d layer='%s' pos=(%d,%d) bounds=(%d,%d %dx%d)%s",
      c.frameNumber, c.layer.name, c.position.x, c.position.y,
      c.bounds.x, c.bounds.y, c.bounds.width, c.bounds.height,
      (c.position.x ~= 0 or c.position.y ~= 0) and "  <-- TRIMMED, offset matters!" or ""))
  end
end

-- composite that frame onto a full canvas
local CV = {}
for y = 0, H - 1 do CV[y] = {} for x = 0, W - 1 do CV[y][x] = { 0, 0, 0, 0 } end end
for _, c in ipairs(spr.cels) do
  if c.frameNumber == FRAME and c.layer.isVisible then
    local im = c.image
    for y = 0, im.height - 1 do
      for x = 0, im.width - 1 do
        local r, g, b, a = rgb(im:getPixel(x, y))
        local wx, wy = x + c.position.x, y + c.position.y
        if a > 8 and wx >= 0 and wx < W and wy >= 0 and wy < H then CV[wy][wx] = { r, g, b, a } end
      end
    end
  end
end

-- bbox
local x0, y0, x1, y1, npx = 9999, 9999, -1, -1, 0
for y = 0, H - 1 do
  for x = 0, W - 1 do
    if CV[y][x][4] > 8 then
      npx = npx + 1
      if x < x0 then x0 = x end; if x > x1 then x1 = x end
      if y < y0 then y0 = y end; if y > y1 then y1 = y end
    end
  end
end
print(string.format("bbox x%d..%d y%d..%d  (%dx%d, %d opaque px)", x0, x1, y0, y1, x1 - x0 + 1, y1 - y0 + 1, npx))

-- feet: opaque runs on the ground row
local function runsOn(y)
  local out, s = {}, -1
  for x = 0, W do
    local opaque = (x < W) and CV[y][x][4] > 8
    if opaque and s < 0 then s = x end
    if not opaque and s >= 0 then out[#out + 1] = { s, x - 1 }; s = -1 end
  end
  return out
end
local feet = runsOn(GROUND)
print(string.format("ground row y%d: %d run(s)", GROUND, #feet))
for i, r in ipairs(feet) do
  print(string.format("  run %d: x%d..%d  (%d px)", i, r[1], r[2], r[2] - r[1] + 1))
end
if #feet == 1 then print("  -> legs merged in one column: use mode=side (or ask for a redraw)")
elseif #feet == 2 then print("  -> two separate feet: use mode=front")
elseif #feet == 0 then print("  -> nothing on the ground row: check the sprite / cel offsets") end

-- ground profile: lowest opaque row per column (bottom 6 rows of the canvas)
print("ground profile (lowest opaque row per column, '.' = empty):")
for x = 0, W - 1 do
  local low = -1
  for y = H - 1, math.max(0, H - 6), -1 do
    if CV[y][x][4] > 8 then low = y; break end
  end
  if low >= 0 then io.write(string.format("%2d:%2d ", x, low)) end
end
print("")

-- palette census (top 12)
local counts, order = {}, {}
for y = 0, H - 1 do
  for x = 0, W - 1 do
    local p = CV[y][x]
    if p[4] > 8 then
      local k = string.format("#%02X%02X%02X", p[1], p[2], p[3])
      if not counts[k] then counts[k] = 0; order[#order + 1] = k end
      counts[k] = counts[k] + 1
    end
  end
end
table.sort(order, function(a, b) return counts[a] > counts[b] end)
io.write("palette: ")
for i = 1, math.min(12, #order) do io.write(order[i] .. "(" .. counts[order[i]] .. ") ") end
print("")
print("reminder: if the shoes are the same colour as the skirt/dress the raised foot will not read —")
print("          keep the ankle row, or paint a lighter sole on the raised foot.")
spr:close()
print("DONE")
