return function(mod)
  mod.options:define({
    {
      key = "show_info",
      label = "SHOW INFO",
      type = "choice",
      default = "both",
      choices = {
        { "OFF", "off" },
        { "LOC", "location" },
        { "POS", "position" },
        { "BOTH", "both" },
      },
    },
    {
      key = "hud_position",
      label = "HUD POS",
      type = "choice",
      default = "top_right",
      choices = {
        { "TL", "top_left" },
        { "TR", "top_right" },
        { "BL", "bottom_left" },
        { "BR", "bottom_right" },
      },
    },
  })

  local INFO_MODES = {
    { "off", "OFF" },
    { "location", "LOC" },
    { "position", "POS" },
    { "both", "BOTH" },
  }

  local POS_MODES = {
    { "top_left", "TL" },
    { "top_right", "TR" },
    { "bottom_left", "BL" },
    { "bottom_right", "BR" },
  }

  local function bucket(game)
    local o = game and game.save and game.save.options
    if not o then
      return nil
    end
    o.modOptions = o.modOptions or {}
    o.modOptions[mod.id] = o.modOptions[mod.id] or {}
    return o.modOptions[mod.id]
  end

  local function getOpt(game, key, fallback)
    local b = bucket(game)
    local v = b and b[key]
    if v == nil then
      v = mod.options:get(key)
    end
    return v or fallback
  end

  local function setOpt(game, key, value)
    local b = bucket(game)
    if b then
      b[key] = value
    end
    if mod.options and type(mod.options.set) == "function" then
      pcall(function()
        mod.options:set(key, value)
      end)
    end
  end

  local function indexOf(list, value)
    for i, m in ipairs(list) do
      if m[1] == value then
        return i
      end
    end
    return 1
  end

  local function cycleList(game, key, list, dir, fallback)
    local cur = indexOf(list, getOpt(game, key, fallback))
    local nextIdx = ((cur - 1 + (dir or 1)) % #list) + 1
    setOpt(game, key, list[nextIdx][1])
    return true
  end

  local function labelOf(list, value, fallbackLabel)
    for _, m in ipairs(list) do
      if m[1] == value then
        return m[2]
      end
    end
    return fallbackLabel
  end

  local function isCancelRow(row)
    if not row then
      return false
    end
    if row.cancel == true or row.id == "cancel" then
      return true
    end
    local label = row.label
    return type(label) == "string" and label:upper() == "CANCEL"
  end

  local function isPreferredAnchor(row)
    if not row then
      return false
    end
    local id = row.id or row.key
    if id == "speedMenu" or id == "speedBattle" or id == "speedOverworld"
        or id == "speed" then
      return true
    end
    local label = row.label
    if type(label) == "string" then
      local u = label:upper()
      if u == "MENU SPEED" or u == "GAME SPEED" or u == "BATTLE SPEED"
          or u == "OVERWORLD SPEED" then
        return true
      end
    end
    return false
  end

  local function makeInfoRow(game)
    return {
      id = "player_pos_hud_show_info",
      label = "SHOW INFO",
      value = function(g)
        return labelOf(INFO_MODES, getOpt(g, "show_info", "both"), "BOTH")
      end,
      step = function(g, dir)
        return cycleList(g, "show_info", INFO_MODES, dir, "both")
      end,
      text = function()
        return labelOf(INFO_MODES, getOpt(game, "show_info", "both"), "BOTH")
      end,
      cycle = function(_options, delta, g)
        return cycleList(g or game, "show_info", INFO_MODES, delta, "both")
      end,
    }
  end

  local function makePosRow(game)
    return {
      id = "player_pos_hud_position",
      label = "HUD POS",
      value = function(g)
        return labelOf(POS_MODES, getOpt(g, "hud_position", "top_right"), "TR")
      end,
      step = function(g, dir)
        return cycleList(g, "hud_position", POS_MODES, dir, "top_right")
      end,
      text = function()
        return labelOf(POS_MODES, getOpt(game, "hud_position", "top_right"), "TR")
      end,
      cycle = function(_options, delta, g)
        return cycleList(g or game, "hud_position", POS_MODES, delta, "top_right")
      end,
    }
  end

  mod.hooks:wrap("ui.options.rows", function(nextFn, game, rows)
    rows = nextFn(game, rows)
    if type(rows) ~= "table" then
      return rows
    end

    local hasInfo, hasPos = false, false
    for _, row in ipairs(rows) do
      if row.id == "player_pos_hud_show_info" then
        hasInfo = true
      end
      if row.id == "player_pos_hud_position" then
        hasPos = true
      end
    end
    if hasInfo and hasPos then
      return rows
    end

    local infoRow = makeInfoRow(game)
    local posRow = makePosRow(game)

    local preferredIdx = nil
    for i, row in ipairs(rows) do
      if isPreferredAnchor(row) then
        preferredIdx = i
      end
    end

    local out = {}
    local inserted = false
    for i, row in ipairs(rows) do
      if not inserted and isCancelRow(row) then
        if not hasInfo then
          out[#out + 1] = infoRow
        end
        if not hasPos then
          out[#out + 1] = posRow
        end
        inserted = true
      end
      out[#out + 1] = row
      if not inserted and preferredIdx == i then
        if not hasInfo then
          out[#out + 1] = infoRow
        end
        if not hasPos then
          out[#out + 1] = posRow
        end
        inserted = true
      end
    end
    if not inserted then
      if not hasInfo then
        out[#out + 1] = infoRow
      end
      if not hasPos then
        out[#out + 1] = posRow
      end
    end
    return out
  end)

  local function formatMapId(id)
    if not id or type(id) ~= "string" then
      return "?"
    end
    local s = id:gsub("_", " "):lower()
    return (s:gsub("(%a)([%w_']*)", function(first, rest)
      return first:upper() .. rest
    end))
  end

  local function getLocation(game)
    if mod.world and type(mod.world.current) == "function" then
      local ok, cur = pcall(function()
        return mod.world:current()
      end)
      if ok and type(cur) == "table" and cur.mapId then
        return cur.mapId, tonumber(cur.x) or 0, tonumber(cur.y) or 0
      end
    end

    local world = game and game.world
    if world and world.map and world.player then
      local p = world.player
      local map = world.map
      local mapId = map.id or map.mapId or (map.def and map.def.id)
      if mapId then
        return mapId, tonumber(p.cellX or p.x) or 0, tonumber(p.cellY or p.y) or 0
      end
    end

    local ow = game and game.overworld
    if ow and ow.map and ow.player then
      local p = ow.player
      local cx, cy
      if type(p.position) == "function" then
        cx, cy = p:position()
      else
        cx = p.cellX or p.x
        cy = p.cellY or p.y
      end
      local mapId = ow.map.id or ow.map.mapId
      if mapId then
        return mapId, tonumber(cx) or 0, tonumber(cy) or 0
      end
    end

    return nil, nil, nil
  end

  local function shouldDraw(game)
    if not game then
      return false
    end
    if game.phase == "play" and game.world and game.world.map then
      return true
    end
    if game.phase == "boot" or game.phase == "error" then
      return false
    end
    if game.overworld and game.overworld.map then
      local stack = game.stack
      if stack and type(stack.top) == "function" then
        local top = stack:top()
        if not top then
          return true
        end
        if top == game.overworld or top.isOverworld then
          return true
        end
        if top.isOpaque then
          return false
        end
      end
      return true
    end
    return getLocation(game) ~= nil
  end

  mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
    if nextFn then
      nextFn(game, viewport)
    end

    local mode = getOpt(game, "show_info", "both")
    if mode == "off" then
      return
    end
    if not shouldDraw(game) then
      return
    end

    local showMap = (mode == "location" or mode == "both")
    local showPos = (mode == "position" or mode == "both")
    if not showMap and not showPos then
      return
    end

    local mapId, cx, cy = getLocation(game)
    if not mapId then
      return
    end

    local lines = {}
    if showMap then
      lines[#lines + 1] = formatMapId(mapId)
    end
    if showPos then
      lines[#lines + 1] = string.format("X:%d  Y:%d", cx, cy)
    end

    local ww, wh = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local lineH = (font and font:getHeight() or 12) + 2
    local maxW = 0
    for _, line in ipairs(lines) do
      local w = font and font:getWidth(line) or (#line * 8)
      if w > maxW then
        maxW = w
      end
    end

    local pad = 4
    local boxW = maxW + pad * 2
    local boxH = #lines * lineH + pad * 2
    local margin = 6

    local pos = getOpt(game, "hud_position", "top_right")
    local x, y
    if pos == "top_left" then
      x, y = margin, margin
    elseif pos == "bottom_left" then
      x, y = margin, wh - boxH - margin
    elseif pos == "bottom_right" then
      x, y = ww - boxW - margin, wh - boxH - margin
    else
      x, y = ww - boxW - margin, margin
    end

    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", x, y, boxW, boxH, 3, 3)

    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, boxW - 1, boxH - 1, 3, 3)

    love.graphics.setColor(1, 1, 1, 1)
    for i, line in ipairs(lines) do
      love.graphics.print(line, x + pad, y + pad + (i - 1) * lineH)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end)
end
