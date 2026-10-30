-- verify-walk.lua — prove the generated cycle obeys the rule
-- params: a=<source sprite>  b=<generated walk .aseprite>
-- checks:  frame 2  == source, byte for byte
--          frame 1/3 == source shifted down 1 row, EXCEPT the bottom rows (the legs)
-- exit:    prints FAIL lines when the rule is broken (script still returns 0)
local function rgb(c) return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c), app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c) end

local function framesOf(path)
  local spr = app.open(path)
  if not spr then error("cannot open " .. tostring(path)) end
  local W, H = spr.width, spr.height
  local list, tags = {}, {}
  for i = 1, #spr.frames do
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
    list[i] = cv
  end
  for _, t in ipairs(spr.tags) do
    tags[#tags + 1] = string.format("%s %d..%d", t.name, t.fromFrame.frameNumber, t.toFrame.frameNumber)
  end
  spr:close()
  return list, W, H, tags
end

local function eq(p, q)
  if p[4] <= 8 and q[4] <= 8 then return true end
  return p[1] == q[1] and p[2] == q[2] and p[3] == q[3] and p[4] == q[4]
end

local SRC, W, H, _ = framesOf(app.params["a"])
local ANI, _, _, tags = framesOf(app.params["b"])
print("tags: " .. (#tags > 0 and table.concat(tags, ", ") or "(none)"))
if #ANI ~= 3 then print("FAIL: the animation must have exactly 3 frames, found " .. #ANI) end

-- 1) frame 2 must equal the source
local d2 = 0
for y = 0, H - 1 do for x = 0, W - 1 do if not eq(SRC[1][y][x], ANI[2][y][x]) then d2 = d2 + 1 end end end
print(string.format("frame2 vs source differences (must be 0): %d%s", d2, d2 == 0 and "" or "   <-- FAIL"))

-- 2) frames 1 and 3 vs "source shifted down one row"
local lastRow = H - 1
for _, fi in ipairs({ 1, 3 }) do
  local diffs, lowest = 0, H
  local rows = {}
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local want = (y >= 1) and SRC[1][y - 1][x] or { 0, 0, 0, 0 }
      if not eq(want, ANI[fi][y][x]) then
        diffs = diffs + 1
        rows[y] = (rows[y] or 0) + 1
        if y < lowest then lowest = y end
      end
    end
  end
  local rl = {}
  for y = 0, H - 1 do if rows[y] then rl[#rl + 1] = "y" .. y .. "\195\151" .. rows[y] end end
  local bottomOnly = (lowest >= lastRow - 3)
  print(string.format("frame%d vs source-shifted: %d px differ  (%s)", fi, diffs, table.concat(rl, " ")))
  print(string.format("   lowest changed row = y%d ; must sit in the bottom rows: %s",
    lowest, bottomOnly and "ok" or "FAIL (body moved)"))
end
print("rule: frame2 = original, frame1/3 = original shifted down 1 row with only the legs changed")
print("DONE")
