return function(mod)
  mod.options:define({
    {
      key = "minimap",
      label = "MINIMAP",
      type = "choice",
      default = "top_left",
      choices = {
        { "OFF", "off" },
        { "TOP LEFT", "top_left" },
        { "TOP RIGHT", "top_right" },
        { "BOTTOM LEFT", "bottom_left" },
        { "BOTTOM RIGHT", "bottom_right" },
      },
    },
    {
      key = "minimap_zoom",
      label = "MAP ZOOM",
      type = "choice",
      default = "0",
      choices = {
        { "-10", "-10" },
        { "-9", "-9" },
        { "-8", "-8" },
        { "-7", "-7" },
        { "-6", "-6" },
        { "-5", "-5" },
        { "-4", "-4" },
        { "-3", "-3" },
        { "-2", "-2" },
        { "-1", "-1" },
        { "0", "0" },
        { "+1", "1" },
        { "+2", "2" },
        { "+3", "3" },
        { "+4", "4" },
        { "+5", "5" },
        { "+6", "6" },
        { "+7", "7" },
        { "+8", "8" },
        { "+9", "9" },
        { "+10", "10" },
      },
    },
    {
      key = "show_markers",
      label = "MARKERS",
      type = "choice",
      default = "all",
      choices = {
        { "OFF", "off" },
        { "NPC", "npc" },
        { "ITM", "items" },
        { "ALL", "all" },
      },
    },
    {
      key = "minimap_bg_size",
      label = "MAP SIZE",
      type = "choice",
      default = "5",
      choices = {
        { "0", "0" }, { "1", "1" }, { "2", "2" }, { "3", "3" }, { "4", "4" },
        { "5", "5" }, { "6", "6" }, { "7", "7" }, { "8", "8" }, { "9", "9" },
        { "10", "10" },
      },
    },
    {
      key = "minimap_map_color",
      label = "MAP COLOR",
      type = "choice",
      default = "recomp",
      choices = {
        { "OG", "og" },
        { "GBC", "gbc" },
        { "RECOMP", "recomp" },
      },
    },
    {
      key = "minimap_colorblind",
      label = "COLORBLIND",
      type = "choice",
      default = "off",
      choices = {
        { "OFF", "off" },
        { "PROTAN", "protanopia" },
        { "DEUTAN", "deuteranopia" },
        { "TRITAN", "tritanopia" },
      },
    },
    -- LoadLocation.lua options (registered here so they are not wiped when
    -- LoadLocation also calls mod.options:define)
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
        { "TOP LEFT", "top_left" },
        { "TOP RIGHT", "top_right" },
        { "BOTTOM LEFT", "bottom_left" },
        { "BOTTOM RIGHT", "bottom_right" },
      },
    },
  })
  -- Prevent LoadLocation.lua from replacing this full option set
  mod._minimapOptionsDefined = true
  local MINIMAP_MODES = {
    { "off", "OFF" },
    { "top_left", "TOP LEFT" },
    { "top_right", "TOP RIGHT" },
    { "bottom_left", "BOTTOM LEFT" },
    { "bottom_right", "BOTTOM RIGHT" },
  }
  local function normalizeMinimapPos(v)
    if v == "on" or v == true or v == "true" then
      return "top_left"
    end
    if v == "off" or v == false or v == "false" or v == nil then
      return v == "off" and "off" or nil
    end
    if v == "top_left" or v == "top_right" or v == "bottom_left" or v == "bottom_right" then
      return v
    end
    return "top_left"
  end
  local MINIMAP_ZOOMS = {
    { "-10", "-10" },
    { "-9", "-9" },
    { "-8", "-8" },
    { "-7", "-7" },
    { "-6", "-6" },
    { "-5", "-5" },
    { "-4", "-4" },
    { "-3", "-3" },
    { "-2", "-2" },
    { "-1", "-1" },
    { "0", "0" },
    { "1", "+1" },
    { "2", "+2" },
    { "3", "+3" },
    { "4", "+4" },
    { "5", "+5" },
    { "6", "+6" },
    { "7", "+7" },
    { "8", "+8" },
    { "9", "+9" },
    { "10", "+10" },
  }
  local MARKER_MODES = {
    { "off", "OFF" },
    { "npc", "NPC" },
    { "items", "ITM" },
    { "all", "ALL" },
  }
  local MINIMAP_BG_SIZES = {
    { "0", "0" }, { "1", "1" }, { "2", "2" }, { "3", "3" }, { "4", "4" },
    { "5", "5" }, { "6", "6" }, { "7", "7" }, { "8", "8" }, { "9", "9" },
    { "10", "10" },
  }
  local MINIMAP_MAP_COLOR_MODES = {
    { "og", "OG" },
    { "gbc", "GBC" },
    { "recomp", "RECOMP" },
  }
  local MINIMAP_COLORBLIND_MODES = {
    { "off", "OFF" },
    { "protanopia", "PROTAN" },
    { "deuteranopia", "DEUTAN" },
    { "tritanopia", "TRITAN" },
  }
  local MINIMAP_BOX = 224
  local ZOOM_BASE_RADIUS = 12
  -- z: -10 (wide) … 0 (default) … +10 (tight). Same curve for Gen1 and Gen2.
  local function radiusForZoom(z, baseRadius)
    if type(z) == "string" then
      z = z:gsub("^%+", ""):gsub("%s+", "")
    end
    z = math.max(-10, math.min(10, tonumber(z) or 0))
    local base = tonumber(baseRadius) or ZOOM_BASE_RADIUS
    local minR, maxR = 1.0, 28.0
    if z > 0 then
      return base + (minR - base) * (z / 10)
    elseif z < 0 then
      return base + (maxR - base) * ((-z) / 10)
    end
    return base
  end
  local BLOCK_PX = 32
  local TILE_PX = 8
  local CELL_PX = 16

  local function normalizeMarkerPalette(pal)
    if type(pal) ~= "table" then return nil end
    if type(pal.colors) == "table" then pal = pal.colors end
    local out = {}
    for i = 1, 4 do
      local c = pal[i]
      if type(c) ~= "table" then return nil end
      local r = tonumber(c[1] or c.r)
      local g = tonumber(c[2] or c.g)
      local b = tonumber(c[3] or c.b)
      if not r or not g or not b then return nil end
      local maxc = math.max(r, g, b)
      if maxc <= 1.001 then
        r, g, b = r * 255, g * 255, b * 255
      elseif maxc <= 31.5 then
        r, g, b = r * (255 / 31), g * (255 / 31), b * (255 / 31)
      end
      out[i] = {
        math.max(0, math.min(255, r)),
        math.max(0, math.min(255, g)),
        math.max(0, math.min(255, b)),
      }
    end
    return out
  end

  local function getGameVersion(game)
    local save = game and game.save
    local v = nil
    if save then
      v = save.version or save.gameVersion or save.game or (save.meta and save.meta.version)
    end
    if not v and game then
      v = game.version or game.gameVersion or game.gameId
    end
    if not v and mod.world and type(mod.world.version) == "function" then
      local ok, vv = pcall(function() return mod.world:version() end)
      if ok then v = vv end
    end
    local s = tostring(v or ""):lower()
    if s:find("gold", 1, true) or s:find("silver", 1, true) or s:find("crystal", 1, true)
        or s == "gen2" or s == "gsc" then
      return "gold"
    end
    if s:find("yellow", 1, true) or s == "y" then return "yellow" end
    if s:find("blue", 1, true) or s == "b" then return "blue" end
    if s:find("red", 1, true) or s == "r" then return "red" end
    return "red"
  end
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
    -- Gold/Silver/Crystal never use the GBC minimap mode.
    -- Normalize old saved settings so GBC cannot be selected or rendered.
    if key == "minimap_map_color" and getGameVersion(game) == "gold" and v == "gbc" then
      v = "recomp"
      if b then b[key] = v end
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

  local function minimapBoxPx(game)
    local v = tonumber(getOpt(game, "minimap_bg_size", "5")) or 5
    if v < 0 then v = 0 end
    if v > 10 then v = 10 end
    return 144 + v * 16 
  end

  local colorblindShader = nil
  local colorblindShaderTried = false
  local COLORBLIND_MODE_ID = { off = 0, protanopia = 1, deuteranopia = 2, tritanopia = 3 }
  local function getColorblindShader()
    if colorblindShaderTried then return colorblindShader end
    colorblindShaderTried = true
    if not (love.graphics and love.graphics.newShader) then return nil end
    local ok, shader = pcall(love.graphics.newShader, [[
      extern int u_mode;
      vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord) {
        vec4 px = Texel(tex, texcoord) * color;
        float r = px.r, g = px.g, b = px.b;
        vec3 outc = vec3(r, g, b);
        if (u_mode == 1) {
          // Protanopia
          outc = vec3(0.567*r + 0.433*g, 0.558*r + 0.442*g, 0.242*g + 0.758*b);
        } else if (u_mode == 2) {
          // Deuteranopia
          outc = vec3(0.625*r + 0.375*g, 0.70*r + 0.30*g, 0.30*g + 0.70*b);
        } else if (u_mode == 3) {
          // Tritanopia
          outc = vec3(0.95*r + 0.05*g, 0.433*g + 0.567*b, 0.475*g + 0.525*b);
        }
        return vec4(clamp(outc, 0.0, 1.0), px.a);
      }
    ]])
    if ok and shader then
      colorblindShader = shader
    else
      colorblindShader = nil
    end
    return colorblindShader
  end

  local function beginColorblindFilter(game)
    local mode = getOpt(game, "minimap_colorblind", "off")
    local modeId = COLORBLIND_MODE_ID[mode] or 0

    if modeId == 0 then
      return function() end
    end
    local shader = getColorblindShader()
    if not shader then
      return function() end
    end
    local prevShader = love.graphics.getShader()
    pcall(function() shader:send("u_mode", modeId) end)
    love.graphics.setShader(shader)
    return function()
      love.graphics.setShader(prevShader)
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
  local function makeOptionRow(id, label, key, list, fallback, game)
    return {
      id = id,
      label = label,
      value = function(g)
        return labelOf(list, getOpt(g, key, fallback), list[1][2])
      end,
      step = function(g, dir)
        return cycleList(g, key, list, dir, fallback)
      end,
      text = function()
        return labelOf(list, getOpt(game, key, fallback), list[1][2])
      end,
      cycle = function(_options, delta, g)
        return cycleList(g or game, key, list, delta, fallback)
      end,
    }
  end
  local function optionRowsForGame(game)
    local colorModes = MINIMAP_MAP_COLOR_MODES
    if getGameVersion(game) == "gold" then
      colorModes = {
        { "og", "OG" },
        { "recomp", "RECOMP" },
      }
    end
    return {
      { id = "player_pos_hud_minimap", label = "MINIMAP", key = "minimap", list = MINIMAP_MODES, fallback = "top_left" },
      { id = "player_pos_hud_minimap_zoom", label = "MAP ZOOM", key = "minimap_zoom", list = MINIMAP_ZOOMS, fallback = "0" },
      { id = "player_pos_hud_bg_size", label = "MAP SIZE", key = "minimap_bg_size", list = MINIMAP_BG_SIZES, fallback = "5" },
      { id = "player_pos_hud_color_mode", label = "MAP COLOR", key = "minimap_map_color", list = colorModes, fallback = "recomp" },
      { id = "player_pos_hud_blindness", label = "COLORBLIND", key = "minimap_colorblind", list = MINIMAP_COLORBLIND_MODES, fallback = "off" },
      { id = "player_pos_hud_markers", label = "MARKERS", key = "show_markers", list = MARKER_MODES, fallback = "all" },
    }
  end
  mod.hooks:wrap("ui.options.rows", function(nextFn, game, rows)
    local OPTION_ROWS = optionRowsForGame(game)
    rows = nextFn(game, rows)
    if type(rows) ~= "table" then
      return rows
    end
    local present = {}
    for _, row in ipairs(rows) do
      for _, def in ipairs(OPTION_ROWS) do
        if row.id == def.id then
          present[def.id] = true
        end
      end
    end
    local missing = {}
    for _, def in ipairs(OPTION_ROWS) do
      if not present[def.id] then
        missing[#missing + 1] = makeOptionRow(def.id, def.label, def.key, def.list, def.fallback, game)
      end
    end
    if #missing == 0 then
      return rows
    end
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
        for _, r in ipairs(missing) do
          out[#out + 1] = r
        end
        inserted = true
      end
      out[#out + 1] = row
      if not inserted and preferredIdx == i then
        for _, r in ipairs(missing) do
          out[#out + 1] = r
        end
        inserted = true
      end
    end
    if not inserted then
      for _, r in ipairs(missing) do
        out[#out + 1] = r
      end
    end
    return out
  end)
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
  local FACING_TO_NESW = {
    up = "N",
    north = "N",
    down = "S",
    south = "S",
    left = "W",
    west = "W",
    right = "E",
    east = "E",
    [0] = "S",
    [1] = "N",
    [2] = "W",
    [3] = "E",
    [4] = "S",
  }
  local function getFacing(game)
    local player = nil
    local world = game and game.world
    if world and world.player then
      player = world.player
    else
      local ow = game and game.overworld
      if ow and ow.player then
        player = ow.player
      end
    end
    if not player or type(player) ~= "table" then
      return nil
    end
    local facing = player.facing or player.direction or player.dir or player.face
    if facing == nil and type(player.getFacing) == "function" then
      local ok, f = pcall(player.getFacing, player)
      if ok then
        facing = f
      end
    end
    if facing == nil then
      return nil
    end
    if type(facing) == "string" then
      local key = facing:lower()
      return FACING_TO_NESW[key]
    end
    if type(facing) == "number" then
      return FACING_TO_NESW[facing] or FACING_TO_NESW[facing % 4]
    end
    return nil
  end
  local function getPlayerEntity(game)
    if not game then return nil end
    if game.overworld and game.overworld.player then
      return game.overworld.player
    end
    local stack = game.stack
    if stack and type(stack.states) == "table" then
      for i = #stack.states, 1, -1 do
        local s = stack.states[i]
        if s and s.isOverworld and s.player then
          return s.player
        end
      end
    end
    local world = game.world
    if world and world.player then
      return world.player
    end
    return nil
  end
  local function getOverworld(game)
    if not game then return nil end
    if mod.world and type(mod.world.overworld) == "function" then
      local ok, ow = pcall(function() return mod.world:overworld() end)
      if ok and type(ow) == "table" and ow.map then
        return ow
      end
    end
    if type(game.overworld) == "table" and game.overworld.map then
      return game.overworld
    end
    if type(game.world) == "table" and game.world.map then
      return game.world
    end
    local stack = game.stack
    if stack then
      if type(stack.top) == "function" then
        local ok, top = pcall(function() return stack:top() end)
        if ok and type(top) == "table" and top.isOverworld and top.map then
          return top
        end
      end
      for _, key in ipairs({ "states", "stack", "_states" }) do
        local states = stack[key]
        if type(states) == "table" then
          for i = #states, 1, -1 do
            local s = states[i]
            if type(s) == "table" and s.isOverworld and s.map then
              return s
            end
          end
        end
      end
    end
    return nil
  end
  local function objectSpriteId(obj)
    if not obj then return nil end
    if type(obj.def) == "table" and type(obj.def.sprite) == "string" then
      return obj.def.sprite
    end
    if type(obj.sprite) == "string" then return obj.sprite end
    if type(obj.sprite) == "table" then
      local d = obj.sprite.def
      if type(d) == "table" then
        return d.id or d.name or d.sprite
      end
    end

    if type(obj.spriteDef) == "table" then
      return obj.spriteDef.id or obj.spriteDef.name or obj.spriteDef.sprite
    end
    return nil
  end
  local function getMapObjects(game)
    local list = {}
    local seen = {}
    local player = getPlayerEntity(game)
    local function add(obj)
      if type(obj) ~= "table" or obj == player then return end
      local ox = tonumber(obj.cellX)
      local oy = tonumber(obj.cellY)
      if not ox or not oy then
        if type(obj.def) == "table" then
          ox = tonumber(obj.def.x)
          oy = tonumber(obj.def.y)
        end
      end
      if not ox or not oy then return end
      local idx = (obj.def and obj.def.index) or obj.index
      local k = idx ~= nil and ("idx:" .. tostring(idx))
          or (obj.id and ("id:" .. tostring(obj.id)))
          or string.format("xy:%s:%s", ox, oy)
      if seen[k] then return end
      seen[k] = true
      list[#list + 1] = obj
    end

    local ow = getOverworld(game)
    local liveIndices = {}
    local liveCount = 0
    local function looksLikePersonSprite(spr)
      if type(spr) ~= "string" then return false end
      local u = spr:upper()
      if u:find("BALL", 1, true) or u:find("FOSSIL", 1, true)
          or u:find("BOULDER", 1, true) or u:find("ROCK", 1, true)
          or u:find("TREE", 1, true) or u:find("BUSH", 1, true)
          or u:find("CUT", 1, true) or u:find("SIGN", 1, true)
          or u:find("SNORLAX", 1, true) then
        return false
      end
      return u:find("SPRITE_", 1, true) ~= nil or u:find("NPC", 1, true) ~= nil
    end
    local function noteLive(npc)
      if type(npc) ~= "table" then return end
      if npc.hidden == true or npc.visible == false or npc.removed == true
          or npc.despawned == true then
        return
      end
      local idx = (npc.def and npc.def.index) or npc.index
      if idx ~= nil then liveIndices[tonumber(idx) or idx] = true end
      liveCount = liveCount + 1
      add(npc)
    end
    if ow and type(ow.npcs) == "table" then
      for _, npc in ipairs(ow.npcs) do
        noteLive(npc)
      end
      if liveCount == 0 then
        for _, npc in pairs(ow.npcs) do
          noteLive(npc)
        end
      end
    end
    if ow and type(ow.entities) == "table" then
      for _, e in ipairs(ow.entities) do
        noteLive(e)
      end
    end
    local def = ow and ow.map and ow.map.def
    if type(def) == "table" and type(def.objects) == "table" then
      for _, o in ipairs(def.objects) do
        if type(o) == "table" and o.x ~= nil and o.y ~= nil then
          local person = looksLikePersonSprite(o.sprite)
          local idx = o.index
          local stillLive = (idx ~= nil and liveIndices[tonumber(idx) or idx])
          if person and liveCount > 0 and not stillLive then
            -- live copy already in list
          else
            add({
              def = o,
              cellX = o.x,
              cellY = o.y,
              index = o.index,
              id = o.name,
              sprite = o.sprite,
              item = o.item or (o.itemball and o.itemball.item),
              pokemon = o.pokemon,
              text = o.text,
              trainerClass = o.trainerClass,
              trainerParty = o.trainerParty,
              trainer = o.trainer,
              sight = o.sight or o.sightRange,
              movement = o.movement,
              range = o.range,
              -- Gen2: needed so markers disappear after pickup
              eventFlag = o.eventFlag or o.event_flag,
              fruitTree = o.fruitTree or o.fruittree or o.tree,
              itemball = o.itemball,
              script = o.script or o.scriptKey,
              type = o.type or o.objectType,
            })
          end
        end
      end
    end
    return list
  end
  local function objectXY(obj)
    if type(obj) ~= "table" then return nil, nil end
    local ox = tonumber(obj.cellX)
    local oy = tonumber(obj.cellY)
    if ox and oy then
      return math.floor(ox + 0.5), math.floor(oy + 0.5)
    end
    if type(obj.def) == "table" then
      ox = tonumber(obj.def.x)
      oy = tonumber(obj.def.y)
      if ox and oy then
        return math.floor(ox + 0.5), math.floor(oy + 0.5)
      end
    end
    return nil, nil
  end
  -- Engine trainerClass (Gen1) / def.trainer + sight (Gen2) / Rival sprites
  local function objectIsTrainer(obj)
    if not obj then return false end
    local def = type(obj.def) == "table" and obj.def or nil
    local function hasTrainerClass(t)
      if type(t) ~= "table" then return false end
      local tc = t.trainerClass
      if tc ~= nil and tc ~= 0 and tc ~= "" and tc ~= false then return true end
      local tp = t.trainerParty
      if tp ~= nil and tp ~= 0 and tp ~= "" then return true end
      -- Gen2: object_event OBJECTTYPE_TRAINER → def.trainer = { class, event, … }
      if t.trainer ~= nil and t.trainer ~= false and t.trainer ~= 0 then
        return true
      end
      local ty = t.type or t.objectType or t.kind
      if type(ty) == "string" then
        local u = ty:upper()
        if u == "TRAINER" or u:find("TRAINER", 1, true) then return true end
      end
      if ty == 2 then return true end -- OBJECTTYPE_TRAINER enum in some extracts
      if t.sight ~= nil or t.sightRange ~= nil or t.range ~= nil then
        -- sight alone is not enough (items can have range); require trainer-ish
        if t.trainer or t.trainerClass or t.trainerParty then return true end
      end
      return false
    end
    if hasTrainerClass(obj) or hasTrainerClass(def) then return true end
    local spr = (def and type(def.sprite) == "string" and def.sprite)
        or (type(obj.sprite) == "string" and obj.sprite) or nil
    if type(spr) == "string" then
      local u = spr:upper()
      if u:find("RIVAL", 1, true) or u == "SPRITE_BLUE" or u:find("SPRITE_BLUE", 1, true) then
        return true
      end
    end
    local name = tostring(obj.name or (def and def.name) or obj.id or ""):upper()
    if name:find("RIVAL", 1, true) or name:find("GARY", 1, true) then return true end
    local text = tostring(obj.text or (def and def.text) or ""):upper()
    if text:find("RIVAL", 1, true) then return true end
    return false
  end
  local function objectItemId(obj)
    if not obj then return nil end
    if obj.item and obj.item ~= 0 and obj.item ~= "0" then return obj.item end
    if type(obj.def) == "table" and obj.def.item and obj.def.item ~= 0 and obj.def.item ~= "0" then
      return obj.def.item
    end
    return nil
  end
  local function objectTextId(obj)
    if not obj then return nil end
    local function asText(t)
      if type(t) == "string" and t ~= "" then return t end
      if type(t) == "number" then return tostring(t) end
      return nil
    end
    local t = asText(obj.text or obj.textId or obj.talk)
    if t then return t end
    if type(obj.def) == "table" then
      t = asText(obj.def.text or obj.def.textId or obj.def.talk)
      if t then return t end
    end
    return nil
  end
  local giftTextCache = {}
  local GIFT_VERBS = {
    give_item = true,
    giveitem = true,
    give_key_item = true,
    givekeyitem = true,
    give_pokemon = true,
    givepokemon = true,
    give_tm = true,
    givettm = true,
    give_hm = true,
    trade = true,
    trade_pokemon = true,
    tradepokemon = true,
    do_trade = true,
    in_game_trade = true,
    start_trade = true,
    give_badge = true,
    give_berry = true,
    giveberry = true,
  }
  local GIFT_EVENT_DEFS = {
  -- Gen1 in-game trades (pret TradeMons / DoInGameTradeDialogue).
  -- Blue marker on the actual trader NPC; disappears after the trade is done.
  -- Object indices match pret object_event order (1-based).
  -- Cerulean Trade House: object 1 = Granny (no trade), object 2 = Gambler (LOLA).
  { event = "EVENT_TRADED_POLIWHIRL_FOR_JYNX",
    maps = { "CERULEAN_TRADE_HOUSE", "CERULEANTRADEHOUSE" },
    indices = { 2 },
    hints = { "LOLA", "TEXT_CERULEANTRADEHOUSE_GAMBLER", "TEXT_CERULEANTRADEHOUSE_LOLA",
              "TRADE_FOR_LOLA" } },
  -- Route 2 Trade House: object 1 = Scientist, object 2 = Gameboy Kid (MARCEL / MILES in Yellow).
  { event = "EVENT_TRADED_ABRA_FOR_MR_MIME",
    maps = { "ROUTE_2_TRADE_HOUSE", "ROUTE2TRADEHOUSE" },
    indices = { 2 },
    hints = { "MARCEL", "MILES", "TEXT_ROUTE2TRADEHOUSE_GAMEBOY_KID", "TRADE_FOR_MARCEL" } },
  -- Underground Path Route 5 entrance: object 1 = Little Girl (SPOT / RICKY in Yellow).
  { event = "EVENT_TRADED_NIDORAN_FOR_NIDORAN",
    maps = { "UNDERGROUND_PATH_ROUTE_5", "UNDERGROUNDPATHROUTE5" },
    indices = { 1 },
    hints = { "SPOT", "RICKY", "TEXT_UNDERGROUNDPATHROUTE5_LITTLE_GIRL", "TRADE_FOR_SPOT" } },
  -- Vermilion Trade House: object 1 = Little Girl (DUX).
  { event = "EVENT_TRADED_SPEAROW_FOR_FARFETCHD",
    maps = { "VERMILION_TRADE_HOUSE", "VERMILIONTRADEHOUSE" },
    indices = { 1 },
    hints = { "DUX", "TEXT_VERMILIONTRADEHOUSE_LITTLE_GIRL", "TRADE_FOR_DUX" } },
  -- Route 11 Gate 2F: object 1 = Youngster (TERRY / GURIO in Yellow).
  -- (Some guides list this as Route 12; include both map aliases.)
  { event = "EVENT_TRADED_NIDORINO_FOR_NIDORINA",
    maps = { "ROUTE_11_GATE_2F", "ROUTE11GATE2F", "ROUTE_12_GATE_2F", "ROUTE12GATE2F" },
    indices = { 1 },
    hints = { "TERRY", "GURIO", "TEXT_ROUTE11GATE2F_YOUNGSTER", "TRADE_FOR_TERRY" } },
  -- Route 18 Gate 2F: object 1 = Youngster (MARC / SPIKE in Yellow).
  { event = "EVENT_TRADED_SLOWBRO_FOR_LICKITUNG",
    maps = { "ROUTE_18_GATE_2F", "ROUTE18GATE2F" },
    indices = { 1 },
    hints = { "MARC", "SPIKE", "TEXT_ROUTE18GATE2F_YOUNGSTER", "TRADE_FOR_MARC" } },
  -- Cinnabar Lab Fossil Room: object 1 = Fossil scientist, object 2 = SAILOR trader.
  { event = "EVENT_TRADED_PONYTA_FOR_SEEL",
    maps = { "CINNABAR_LAB_FOSSIL_ROOM", "CINNABARLABFOSSILROOM" },
    indices = { 2 },
    hints = { "SAILOR", "CEZANNE", "TEXT_CINNABARLABFOSSILROOM_SCIENTIST2", "TRADE_FOR_SAILOR" } },
  -- Cinnabar Lab Trade Room: object 1 = Super Nerd (no trade),
  -- object 2 = Gramps (DORIS / BUFFY in Yellow), object 3 = Beauty (CRINKLES / STICKY in Yellow).
  { event = "EVENT_TRADED_RAICHU_FOR_ELECTRODE",
    maps = { "CINNABAR_LAB_TRADE_ROOM", "CINNABARLABTRADEROOM" },
    indices = { 2 },
    hints = { "DORIS", "BUFFY", "TEXT_CINNABARLABTRADEROOM_GRAMPS", "TRADE_FOR_DORIS" } },
  { event = "EVENT_TRADED_VENONAT_FOR_TANGELA",
    maps = { "CINNABAR_LAB_TRADE_ROOM", "CINNABARLABTRADEROOM" },
    indices = { 3 },
    hints = { "CRINKLES", "STICKY", "TEXT_CINNABARLABTRADEROOM_BEAUTY", "TRADE_FOR_CRINKLES" } },
  -- ---- Gen2-only gifts/trades (gen = 2). Must NOT match Gen1 maps. ----
  -- Berry Man in Route 30 Berry House
  { gen = 2, event = "EVENT_GOT_BERRY_FROM_ROUTE_30_HOUSE",
    eventId = 39,
    maps = { "ROUTE_30_BERRY_HOUSE", "ROUTE30BERRYHOUSE", "ROUTE_30_BERRY_SPEECH_HOUSE" },
    indices = { 1 },
    hints = { "BERRY", "POKEFAN", "ROUTE30BERRYHOUSE", "TEXT_ROUTE30BERRYHOUSE" } },
  -- Goldenrod Bike Shop → Bicycle (NOT Gen1 Cerulean Bike Shop)
  { gen = 2, event = "EVENT_GOT_BICYCLE",
    eventId = 91,
    maps = { "GOLDENROD_BIKE_SHOP", "GOLDENRODBIKESHOP" },
    indices = { 1 },
    hints = { "BICYCLE", "BIKE", "CLERK", "GOLDENRODBIKESHOP" } },
  -- Goldenrod Flower Shop → SquirtBottle
  { gen = 2, event = "EVENT_GOT_SQUIRTBOTTLE",
    eventId = 92,
    maps = { "GOLDENROD_FLOWER_SHOP", "GOLDENRODFLOWERSHOP" },
    indices = { 1 },
    hints = { "SQUIRTBOTTLE", "SQUIRT", "TEACHER", "FLORIA", "FLOWER" } },
  -- Mr. Pokémon → Mystery Egg
  { gen = 2, event = "EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON",
    eventId = 30,
    maps = { "MR_POKEMONS_HOUSE", "MRPOKEMONSHOUSE", "MR_POKEMON_HOUSE", "MRPOKEMONHOUSE" },
    indices = { 1 },
    hints = { "MYSTERY_EGG", "MR_POKEMON", "MRPOKEMON" } },
  -- Elm's Aide → Togepi Egg
  { gen = 2, event = "EVENT_GOT_TOGEPI_EGG_FROM_ELMS_AIDE",
    eventId = 45,
    maps = { "ELMS_LAB", "ELMSLAB", "VIOLET_POKEMON_CENTER_1F", "VIOLETPOKEMONCENTER1F" },
    indices = {},
    hints = { "TOGEPI", "AIDE", "ELMS_AIDE", "EGG" } },
  -- Cianwood Mania → Shuckie
  { gen = 2, event = "EVENT_GOT_SHUCKIE",
    eventId = 69,
    maps = { "MANIAS_HOUSE", "MANIASHOUSE", "CIANWOOD_MANIA_HOUSE" },
    indices = { 1 },
    hints = { "SHUCKIE", "SHUCKLE", "MANIA" } },
  -- Gen2 in-game trades
  { gen = 2, event = "EVENT_TRADE_KYLE_ONIX",
    maps = { "VIOLET_KYLES_HOUSE", "VIOLETKYLESHOUSE" },
    indices = { 2 },
    hints = { "KYLE", "ONIX", "ROCKY", "NPC_TRADE_KYLE", "TRADE" },
    trade = true, tradeId = 1 },
  { gen = 2, event = "EVENT_TRADE_MIKE_MACHOP",
    maps = { "GOLDENROD_DEPT_STORE_5F", "GOLDENRODDEPTSTORE5F", "GOLDENROD_DEPTSTORE_5F" },
    indices = { 3 },
    hints = { "MIKE", "MACHOP", "MUSCLE", "NPC_TRADE_MIKE", "TRADE" },
    trade = true, tradeId = 0 },
  { gen = 2, event = "EVENT_TRADE_TIM_VOLTORB",
    maps = { "OLIVINE_TIMS_HOUSE", "OLIVINETIMSHOUSE" },
    indices = { 1 },
    hints = { "TIM", "VOLTORB", "VOLTY", "NPC_TRADE_TIM", "TRADE" },
    trade = true, tradeId = 2 },
  { gen = 2, event = "EVENT_TRADE_KIM_AERODACTYL",
    maps = { "ROUTE_14", "ROUTE14" },
    indices = {},
    hints = { "KIM", "AERODACTYL", "AEROY", "NPC_TRADE_KIM", "TRADE" },
    trade = true, tradeId = 5 },
  { gen = 2, event = "EVENT_TRADE_FOREST_MAGNETON",
    maps = { "POWER_PLANT", "POWERPLANT" },
    indices = {},
    hints = { "FOREST", "MAGNETON", "MAGGIE", "NPC_TRADE_FOREST", "TRADE" },
    trade = true, tradeId = 6 },
    { event = "EVENT_GOT_POTION_SAMPLE",
      maps = { "ROUTE_1", "ROUTE 1" },
      indices = { 1 },
      hints = { "SAMPLE", "POTION_SAMPLE", "MART_SAMPLE", "VIRIDIANMARTSAMPLE",
                "ROUTE1_YOUNGSTER1", "TEXT_ROUTE1_YOUNGSTER1" } },
    { event = "EVENT_GOT_TM42",
      maps = { "VIRIDIAN_CITY", "VIRIDIANCITY" },
      indices = { 6 },
      hints = { "TM42", "DREAM_EATER", "DREAMEATER", "FISHER",
                "VIRIDIANCITY_FISHER", "TEXT_VIRIDIANCITY_FISHER" } },
    { event = "EVENT_GOT_POKEBALLS_FROM_OAK",
      maps = { "OAKS_LAB", "OAKSLAB" },
      indices = { 1, 2, 3, 4, 5 },
      hints = { "OAKSLAB_OAK", "TEXT_OAKSLAB_OAK1", "TEXT_OAKSLAB_OAK" } },
    { event = "EVENT_GOT_STARTER",
      maps = { "OAKS_LAB", "OAKSLAB" },
      indices = {},
      hints = { "CHARMANDER", "SQUIRTLE", "BULBASAUR", "STARTER" } },
    { event = "EVENT_GOT_TOWN_MAP",
      maps = { "BLUES_HOUSE", "BLUE_S_HOUSE" },
      indices = {},
      hints = { "TOWN_MAP", "DAISY" } },
    { event = "EVENT_GOT_OAKS_PARCEL",
      maps = { "VIRIDIAN_MART", "VIRIDIANMART" },
      indices = {},
      hints = { "PARCEL", "OAKS_PARCEL" } },
    { event = "EVENT_GOT_HM05",
      maps = { "ROUTE_2", "ROUTE 2", "ROUTE2_GATE", "ROUTE_2_GATE", "ROUTE_2_GATE_1F" },
      indices = {},
      hints = { "OAKS_AIDE", "OAKSAIDE", "HM05", "AIDE" } },
    { event = "EVENT_GOT_ITEMFINDER",
      maps = { "ROUTE_11", "ROUTE11", "ROUTE_11_GATE", "ROUTE11GATE", "ROUTE_11_GATE_UPSTAIRS" },
      indices = {},
      hints = { "OAKS_AIDE", "OAKSAIDE", "ITEMFINDER", "AIDE" } },
    { event = "EVENT_GOT_EXP_ALL",
      maps = { "ROUTE_15", "ROUTE15", "ROUTE_15_GATE" },
      indices = {},
      hints = { "OAKS_AIDE", "OAKSAIDE", "EXP_ALL", "EXPALL", "AIDE" } },
    { event = "EVENT_GOT_HM04",
      maps = { "FUCHSIA_CITY", "WARDENS_HOUSE", "FUCHSIA", "SAFARI_ZONE_WARDENS_HOME" },
      indices = {},
      hints = { "WARDEN", "HM04" } },
    { event = "EVENT_GOT_HM02",
      maps = { "ROUTE_16", "ROUTE16", "ROUTE_16_HOUSE", "ROUTE16_HOUSE" },
      indices = {},
      hints = { "HM02", "FLY" } },
    { event = "EVENT_GOT_POKE_FLUTE",
      maps = { "LAVENDER_TOWN", "MR_FUJIS_HOUSE", "LAVENDER" },
      indices = {},
      hints = { "FUJI", "FLUTE", "POKE_FLUTE" } },
    { event = "EVENT_GOT_OLD_ROD",
      maps = { "VERMILION_CITY", "VERMILION", "VERMILION_OLD_ROD_HOUSE" },
      indices = {},
      hints = { "OLD_ROD", "FISHING_GURU", "FISHINGGURU" } },
    { event = "EVENT_GOT_GOOD_ROD",
      maps = { "FUCHSIA_CITY", "FUCHSIA", "FUCHSIA_GOOD_ROD_HOUSE" },
      indices = {},
      hints = { "GOOD_ROD", "FISHING_GURU", "FISHINGGURU" } },
    { event = "EVENT_GOT_SUPER_ROD",
      maps = { "ROUTE_12", "ROUTE12", "ROUTE_12_SUPER_ROD_HOUSE" },
      indices = {},
      hints = { "SUPER_ROD", "FISHING_GURU", "FISHINGGURU" } },
    { event = "EVENT_GOT_BICYCLE",
      maps = { "CERULEAN_CITY", "BIKE_SHOP", "CERULEAN" },
      indices = {},
      hints = { "BICYCLE", "BIKE_SHOP" } },
    { event = "EVENT_GOT_BIKE_VOUCHER",
      maps = { "VERMILION_CITY", "POKEMON_FAN_CLUB", "FAN_CLUB" },
      indices = {},
      hints = { "VOUCHER", "BIKE_VOUCHER" } },
    { event = "EVENT_GOT_TM34", maps = { "PEWTER_GYM" }, indices = {}, hints = { "TM34" } },
    { event = "EVENT_GOT_TM11", maps = { "CERULEAN_GYM" }, indices = {}, hints = { "TM11" } },
    { event = "EVENT_GOT_TM24", maps = { "VERMILION_GYM" }, indices = {}, hints = { "TM24" } },
    { event = "EVENT_GOT_TM21", maps = { "CELADON_GYM" }, indices = {}, hints = { "TM21" } },
    { event = "EVENT_GOT_TM06", maps = { "FUCHSIA_GYM" }, indices = {}, hints = { "TM06" } },
    { event = "EVENT_GOT_TM46", maps = { "SAFFRON_GYM" }, indices = {}, hints = { "TM46" } },
    { event = "EVENT_GOT_TM38", maps = { "CINNABAR_GYM" }, indices = {}, hints = { "TM38" } },
    { event = "EVENT_GOT_TM27", maps = { "VIRIDIAN_GYM" }, indices = {}, hints = { "TM27" } },
    { event = "EVENT_GOT_OLD_AMBER",
      maps = { "PEWTER_MUSEUM", "MUSEUM_1F", "PEWTER_MUSEUM_1F" },
      indices = {},
      hints = { "AMBER", "OLD_AMBER" } },
    { event = "EVENT_GOT_COIN_CASE",
      maps = { "CELADON_CITY", "ROCKET_HIDEOUT", "ROCKET_HIDEOUT_B1F" },
      indices = {},
      hints = { "COIN_CASE", "COINCASE" } },
    { event = "EVENT_GOT_HITMONLEE",
      maps = { "FIGHTING_DOJO" },
      indices = {},
      hints = { "HITMONLEE" } },
    { event = "EVENT_GOT_HITMONCHAN",
      maps = { "FIGHTING_DOJO" },
      indices = {},
      hints = { "HITMONCHAN" } },
  }
  -- Tag any def without gen as Gen1 (legacy entries).
  for _, def in ipairs(GIFT_EVENT_DEFS) do
    if def.gen == nil then def.gen = 1 end
  end
  local GIFT_BY_MAP = {}
  for _, def in ipairs(GIFT_EVENT_DEFS) do
    for _, m in ipairs(def.maps) do
      local key = tostring(m):upper():gsub("%s+", "_")
      GIFT_BY_MAP[key] = GIFT_BY_MAP[key] or {}
      GIFT_BY_MAP[key][#GIFT_BY_MAP[key] + 1] = def
    end
  end
  -- Set every frame in drawMinimap so gift lookups know Gen1 vs Gen2.
  local activeGame = nil
  -- Only return gift defs that match the running generation so Gen1/Gen2
  -- never share markers (e.g. ROUTE_14 / POWER_PLANT / BIKE_SHOP collisions).
  -- Gift defs for this map that match the running generation.
  local function giftsForMap(mapId, game)
    if not mapId then return nil end
    game = game or activeGame
    local key = tostring(mapId):upper():gsub("%s+", "_")
    local all = GIFT_BY_MAP[key] or GIFT_BY_MAP[key:gsub("_", "")]
    if not all then return nil end
    local wantGen = (getGameVersion(game) == "gold") and 2 or 1
    local out = {}
    for _, def in ipairs(all) do
      if (def.gen or 1) == wantGen then
        out[#out + 1] = def
      end
    end
    return #out > 0 and out or nil
  end
  local KNOWN_GIFTS = {}
  for _, def in ipairs(GIFT_EVENT_DEFS) do
    for _, m in ipairs(def.maps) do
      local key = tostring(m):upper():gsub("%s+", "_")
      KNOWN_GIFTS[key] = KNOWN_GIFTS[key] or { texts = {}, events = {}, gens = {} }
      local g = KNOWN_GIFTS[key]
      g.events[#g.events + 1] = def.event
      g.gens[#g.gens + 1] = def.gen or 1
      for _, h in ipairs(def.hints) do
        g.texts[#g.texts + 1] = h
      end
    end
  end
  local KNOWN_GIFT_TEXT_PATTERNS = {
    "OAKS_AIDE",
    "BILL",
    "KURT",
    "CHUCK",
    "COPYCAT",
    "WARDEN",
    "CHAIRMAN",
    "KIMONO",
    "SAILOR",
    "ELDER",
    "PHARMACY",
    "FISHING_GURU", "FISHINGGURU",
    "GUIDE_GENT", "GUIDEGENT",
    "OLD_MAN", "OLDMAN",
  }
  local function isCommandRowList(t)
    if type(t) ~= "table" then
      return false
    end
    if type(t[1]) == "table" or type(t[1]) == "string" then
      return true
    end
    return false
  end
  local function scriptRowsGiveGift(rows, depth, acc)
    depth = depth or 0
    acc = acc or { gift = false, events = {}, primary = nil }
    if depth > 10 or type(rows) ~= "table" then
      return acc.gift, acc.primary, acc.events
    end
    if not isCommandRowList(rows) and depth == 0 then
      return false, nil, {}
    end
    local function rememberEvent(en)
      if type(en) ~= "string" or en == "" then return end
      local u = en:upper()
      local isProgress = u:find("GOT_", 1, true) or u:find("RECEIVED_", 1, true)
          or u:find("GOTTEN_", 1, true) or u:find("GAVE_", 1, true)
          or u:find("BEAT_", 1, true) or u:find("DONE", 1, true)
          or u:find("FINISHED", 1, true)
      if not acc.events[en] then
        acc.events[en] = true
        acc.events[#acc.events + 1] = en
      end
      if isProgress and not acc.primary then
        acc.primary = en
      end
    end

    for _, row in ipairs(rows) do
      if type(row) == "table" then
        local verb = row[1] or row.verb or row.cmd or row.command
        if type(verb) == "string" then
          local v = verb:lower()
          if GIFT_VERBS[v] then
            acc.gift = true
            -- trade tradeIndex, doneFlag  (doneFlag is often arg 3)
            if v == "trade" or v == "trade_pokemon" or v == "do_trade"
                or v == "in_game_trade" or v == "start_trade" then
              acc.trade = true
              for i = 2, 5 do
                if type(row[i]) == "string" then
                  local s = row[i]
                  local u = s:upper()
                  if u:find("EVENT", 1, true) or u:find("GOT_", 1, true)
                      or u:find("TRADE", 1, true) or u:find("DONE", 1, true) then
                    rememberEvent(s)
                  end
                end
              end
            end
          end
          -- static_battle species, level, beatFlag — freestanding mon scripts
          if v == "static_battle" then
            acc.staticMon = true
            if type(row[4]) == "string" then rememberEvent(row[4]) end
            if type(row[3]) == "string" and row[3]:upper():find("EVENT", 1, true) then
              rememberEvent(row[3])
            end
          end
          if (v == "check_flag" or v == "set_flag" or v == "clear_flag"
                or v == "check_event" or v == "set_event" or v == "checkandsetevent"
                or v == "check_and_set_event")
              and type(row[2]) == "string" then
            rememberEvent(row[2])
          end
        end
        scriptRowsGiveGift(row, depth + 1, acc)
      end
    end
    if acc.gift and not acc.primary and acc.events[1] then
      acc.primary = acc.events[1]
    end
    return acc.gift, acc.primary, acc.events
  end
  local function normalizeTextKey(id)
    if type(id) ~= "string" then
      return ""
    end
    return id:upper():gsub("^TEXT_", ""):gsub("[^A-Z0-9]", "")
  end
  local function scanTalkTableInto(set, talk)
    if type(talk) ~= "table" then
      return
    end
    for textId, rows in pairs(talk) do
      if type(textId) == "string" and isCommandRowList(rows) then
        local ok, primary, events = scriptRowsGiveGift(rows)
        if ok then
          local info = { event = primary, events = events }
          set[textId] = info
          set[textId:upper()] = info
          set[normalizeTextKey(textId)] = info
        end
      end
    end
  end
  local function getGiftTextSet(mapId)
    if not mapId then
      return nil
    end
    local cached = giftTextCache[mapId]
    if cached ~= nil then
      return cached or nil
    end
    local set = {}
    if mod.content and mod.content.map_scripts and type(mod.content.map_scripts.get) == "function" then
      local ok, rec = pcall(function()
        return mod.content.map_scripts:get(mapId)
      end)
      if ok and type(rec) == "table" then
        scanTalkTableInto(set, rec.talk)
        if type(rec.scripts) == "table" and type(rec.scripts.talk) == "table" then
          scanTalkTableInto(set, rec.scripts.talk)
        elseif type(rec.scripts) == "table" then
          scanTalkTableInto(set, rec.scripts)
        end
      end
    end
    if mod.content and mod.content.maps and type(mod.content.maps.get) == "function" then
      local ok, mapDef = pcall(function()
        return mod.content.maps:get(mapId)
      end)
      if ok and type(mapDef) == "table" then
        scanTalkTableInto(set, mapDef.talk)
        if type(mapDef.scripts) == "table" then
          scanTalkTableInto(set, mapDef.scripts.talk or mapDef.scripts)
        end
      end
    end
    local known = KNOWN_GIFTS[mapId] or KNOWN_GIFTS[tostring(mapId):upper()]
    if known and known.texts then
      for _, tid in ipairs(known.texts) do
        local info = { event = known.events and known.events[1] or nil }
        set[tid] = info
        set[tid:upper()] = info
        set[normalizeTextKey(tid)] = info
      end
    end
    local has = false
    for _ in pairs(set) do has = true break end
    giftTextCache[mapId] = has and set or false
    return has and set or nil
  end
  local function enrichGiftTextFromGame(game, mapId)
    if not game or not mapId then return end
    local set = giftTextCache[mapId]
    if set == false or set == nil then set = {} end
    if type(set) ~= "table" then set = {} end
    local mapKeys = {
      mapId,
      tostring(mapId):upper(),
      tostring(mapId):lower(),
      tostring(mapId):gsub("%s+", "_"):upper(),
      tostring(mapId):gsub("_", ""):upper(),
    }
    local function pull(root)
      if type(root) ~= "table" then return end
      for _, key in ipairs(mapKeys) do
        local rec = root[key]
        if type(rec) == "table" then
          scanTalkTableInto(set, rec.talk)
          if type(rec.scripts) == "table" then
            scanTalkTableInto(set, rec.scripts.talk or rec.scripts)
          end
          if type(rec[1]) == "table" or type(rec[1]) == "string" then
          else
            for k, v in pairs(rec) do
              if type(k) == "string" and type(v) == "table" and isCommandRowList(v) then
                local ok, primary, events = scriptRowsGiveGift(v)
                if ok then
                  local info = { event = primary, events = events }
                  set[k] = info
                  set[k:upper()] = info
                  set[normalizeTextKey(k)] = info
                end
              end
            end
          end
        end
      end
      if type(root.talk) == "table" then
        scanTalkTableInto(set, root.talk)
      end
    end
    local data = game.data
    if type(data) == "table" then
      pull(data.map_scripts or data.mapScripts)
      pull(data.scripts)
      pull(data.mapScripts)
      pull(data.generated and data.generated.map_scripts)
      pull(data.imported and data.imported.map_scripts)
    end
    if mod.content and mod.content.map_scripts and type(mod.content.map_scripts.get) == "function" then
      for _, key in ipairs(mapKeys) do
        local ok, rec = pcall(function() return mod.content.map_scripts:get(key) end)
        if ok and type(rec) == "table" then
          scanTalkTableInto(set, rec.talk)
          if type(rec.scripts) == "table" then
            scanTalkTableInto(set, rec.scripts.talk or rec.scripts)
          end
        end
      end
    end
    local known = KNOWN_GIFTS[mapId] or KNOWN_GIFTS[tostring(mapId):upper()]
        or KNOWN_GIFTS[tostring(mapId):gsub("%s+", "_"):upper()]
        or KNOWN_GIFTS[tostring(mapId):gsub("_", ""):upper()]
    if known and known.texts then
      for _, tid in ipairs(known.texts) do
        local info = { event = known.events and known.events[1] or nil }
        set[tid] = info
        set[tid:upper()] = info
        set[normalizeTextKey(tid)] = info
      end
    end
    local has = false
    for _ in pairs(set) do has = true break end
    giftTextCache[mapId] = has and set or false
  end
  local function giftInfoForText(mapId, textId)
    if not mapId or not textId then return nil end
    local set = getGiftTextSet(mapId)
    if not set then return nil end
    local hit = set[textId] or set[textId:upper()] or set[normalizeTextKey(textId)]
    if hit then return hit end
    return nil
  end
  local function objectIndex(obj)
    if type(obj) ~= "table" then return nil end
    if type(obj.def) == "table" and obj.def.index ~= nil then
      return tonumber(obj.def.index)
    end
    return tonumber(obj.index)
  end
  local function flagOn(save, name)
    if not save or name == nil or name == "" then return false end
    local function truthy(v)
      return v == true or v == 1 or v == "1"
    end
    -- Gen2: numeric event bitfield (wEventFlags) via Events or Apricorns.event
    if type(name) == "number" then
      local okE, on = pcall(function()
        local Events = require("src.world.gen2.Events")
        if type(Events) == "table" and type(Events.new) == "function" then
          local ev = Events.new()
          if type(save.events) == "table" and save.events.flags then
            ev.flags = save.events.flags
          elseif type(save.events) == "table" then
            ev.flags = save.events
          end
          return ev:get(name)
        end
        return false
      end)
      if okE and on then return true end
      local okA, on2 = pcall(function()
        local Apricorns = require("src.core.gen2.Apricorns")
        return Apricorns.event(save, name)
      end)
      if okA and on2 then return true end
      -- Bitfield: save.events[byte] with bit name%8
      if type(save.events) == "table" then
        local byte = math.floor(name / 8)
        local bitn = name % 8
        local row = save.events[byte] or save.events[tostring(byte)] or 0
        if type(row) == "number" and math.floor(row / (2 ^ bitn)) % 2 == 1 then
          return true
        end
      end
      return false
    end
    if type(name) ~= "string" then return false end
    local candidates = {
      save.flags, save.events, save.eventFlags, save.event,
      save.storyFlags, save.eventSet,
    }
    local keys = { name, name:upper(), name:lower() }
    local short = name:gsub("^EVENT_", "")
    if short ~= name then
      keys[#keys + 1] = short
      keys[#keys + 1] = short:upper()
      keys[#keys + 1] = "EVENT_" .. short
      keys[#keys + 1] = "EVENT_" .. short:upper()
    elseif not name:upper():find("^EVENT_", 1) then
      keys[#keys + 1] = "EVENT_" .. name
      keys[#keys + 1] = "EVENT_" .. name:upper()
    end
    for _, flags in ipairs(candidates) do
      if type(flags) == "table" then
        for _, k in ipairs(keys) do
          if truthy(flags[k]) then
            return true
          end
        end
      end
    end
    return false
  end
  -- Gen2: game.overworld is a facade without .events/.daytime/.fruitTree*.
  -- The real World lives at game.world.
  local function getGen2World(game)
    if not game then return nil end
    if game.world and type(game.world.events) == "table" then
      return game.world
    end
    if game.overworld and type(game.overworld.events) == "table" then
      return game.overworld
    end
    return game.world or game.overworld
  end
  -- Gen2: event bit set in live world.events or serialized save.events
  local function gen2EventFlagSet(game, flagId)
    if flagId == nil or flagId == 0xFFFF or flagId == -1 then return false end
    local id = tonumber(flagId)
    if not id then return false end
    local world = getGen2World(game)
    if world then
      local ev = world.events
      if type(ev) == "table" and type(ev.get) == "function" then
        local ok, on = pcall(function() return ev:get(id) end)
        if ok and on then return true end
      end
      if type(world.getFlag) == "function" then
        local ok, on = pcall(function() return world:getFlag(id) end)
        if ok and on then return true end
      end
    end
    local save = game and game.save
    if save and type(save.events) == "table" then
      local flags = save.events.flags or save.events
      if type(flags) == "table" then
        local byte = math.floor(id / 8)
        local bitn = id % 8
        local row = flags[byte] or flags[tostring(byte)] or 0
        if type(row) == "number" and math.floor(row / (2 ^ bitn)) % 2 == 1 then
          return true
        end
      end
    end
    return false
  end
  local giftMapKey, giftEventsForObject
  local function isGiftAlreadyTaken(game, obj, mapId, index)
    local save = game and game.save
    if not save then return false end
    local events = giftEventsForObject(obj, mapId)
    for _, ev in ipairs(events) do
      if type(ev) == "number" then
        if gen2EventFlagSet(game, ev) then return true end
      elseif flagOn(save, ev) then
        return true
      end
    end
    -- GIFT_EVENT_DEFS may carry a numeric Gen2 eventId. For small gift houses
    -- match by map alone (object index can be 0- or 1-based depending on extract).
    local isGen2 = getGameVersion(game) == "gold"
    local defs = giftsForMap(mapId, game)
    local idx = objectIndex(obj) or index
    if defs then
      for _, gdef in ipairs(defs) do
        local match = false
        if type(gdef.indices) == "table" and idx ~= nil then
          for _, gi in ipairs(gdef.indices) do
            if tonumber(idx) == tonumber(gi) then match = true break end
          end
        end
        -- Map-level gift: single known event on this map
        if not match and gdef.eventId then
          match = true
        end
        if match and isGen2 and gdef.eventId and gen2EventFlagSet(game, gdef.eventId) then
          return true
        end
        if match and gdef.event and flagOn(save, gdef.event) then
          return true
        end
      end
    end
    -- Gen2-only: Berry House event id
    if isGen2 and gen2EventFlagSet(game, 39) then
      local mk = giftMapKey(mapId)
      if mk and (mk:find("BERRY_HOUSE", 1, true) or mk:find("BERRYHOUSE", 1, true)) then
        return true
      end
    end
    local textId = objectTextId(obj)
    local info = giftInfoForText(mapId, textId)
    if info then
      if info.event and flagOn(save, info.event) then return true end
      if type(info.events) == "table" then
        for _, ev in ipairs(info.events) do
          if type(ev) == "number" and gen2EventFlagSet(game, ev) then return true end
          if flagOn(save, ev) then return true end
        end
      end
    end
    local def = obj.def or obj
    if def.giftTaken or obj.giftTaken or obj.itemGiven then
      return true
    end
    -- Gen2 gift NPCs sometimes only have eventFlag on the object itself
    local ef = obj.eventFlag or def.eventFlag
    if isGen2 and ef and ef ~= 0xFFFF and ef ~= -1 and type(ef) == "number"
        and gen2EventFlagSet(game, ef) then
      return true
    end
    if not isGen2 and type(ef) == "string" and flagOn(save, ef) then
      return true
    end
    -- Fahrradladen: mapId ist ein String-Kartenname (z. B. "BIKE_SHOP"),
    -- keine Zahl — direkt über den normalisierten Kartennamen prüfen.
    local bikeKey = giftMapKey(mapId)
    if bikeKey and bikeKey:find("BIKE_SHOP", 1, true) and flagOn(save, "EVENT_GOT_BICYCLE") then
      return true
    end
    -- Tauschhaus-NPCs: anders als bei normalen Geschenken gibt es hier kein
    -- einzelnes benanntes "EVENT_..."-Flag (auch im Originalspiel nicht —
    -- Tausche werden über einen Index/Bitmask-Zustand verfolgt, nicht über
    -- ein Story-Event). Generisch in den üblichen Save-Tabellen suchen.
    local okGiver, isGiver, reason = pcall(objectIsItemGiver, obj, mapId, index)
    if okGiver and isGiver and reason == "trade" then
      if def.traded == true or obj.traded == true then return true end
      local tradeIndex = obj.tradeIndex or def.tradeIndex
      local idx = objectIndex(obj) or obj.index or def.index
      local candidateTables = {
        save.tradesCompleted, save.completedTrades, save.tradedPokes,
        save.trades, save.tradeFlags,
      }
      for _, tab in ipairs(candidateTables) do
        if type(tab) == "table" then
          local keys = {}
          if tradeIndex ~= nil then
            keys[#keys + 1] = tradeIndex
            keys[#keys + 1] = tostring(tradeIndex)
          end
          if mapId and idx ~= nil then
            keys[#keys + 1] = tostring(mapId) .. "_obj_" .. tostring(idx)
            keys[#keys + 1] = tostring(mapId) .. "_" .. tostring(idx)
            keys[#keys + 1] = tostring(idx)
          end
          for _, k in ipairs(keys) do
            local v = tab[k]
            if v == true or v == 1 or v == "1" then return true end
          end
        end
      end
    end
    return false
  end
  giftMapKey = function(mapId)
    if not mapId then return nil end
    return tostring(mapId):upper():gsub("%s+", "_")
  end
  -- Known Gen1 in-game trade maps (pret TradeMons locations)
  local TRADE_MAPS = {
    CERULEAN_TRADE_HOUSE = true, CERULEANTRADEHOUSE = true,
    ROUTE_2_TRADE_HOUSE = true, ROUTE2TRADEHOUSE = true,
    VERMILION_TRADE_HOUSE = true, VERMILIONTRADEHOUSE = true,
    ROUTE_11_GATE_2F = true, ROUTE11GATE2F = true,
    ROUTE_12_GATE_2F = true, ROUTE12GATE2F = true, -- alias used by some guides/recomps
    ROUTE_18_GATE_2F = true, ROUTE18GATE2F = true,
    CINNABAR_LAB_TRADE_ROOM = true, CINNABARLABTRADEROOM = true,
    CINNABAR_LAB_FOSSIL_ROOM = true, CINNABARLABFOSSILROOM = true,
    UNDERGROUND_PATH_ROUTE_5 = true, UNDERGROUNDPATHROUTE5 = true,
    UNDERGROUND_PATH_NORTH_SOUTH = true,
  }
  local function isTradeMap(mapId, game)
    -- Gen1-only trade-house list (must not fire on Gen2 Route/Lab maps)
    if getGameVersion(game or activeGame) == "gold" then return false end
    local k = giftMapKey(mapId)
    if not k then return false end
    if TRADE_MAPS[k] then return true end
    if k:find("TRADE_HOUSE", 1, true) or k:find("TRADEHOUSE", 1, true)
        or k:find("TRADE_ROOM", 1, true) or k:find("TRADEROOM", 1, true) then
      return true
    end
    return false
  end
  -- Scan map_scripts for THIS map only: textIds with give_item / trade
  -- (no global normalizeTextKey — that caused random blue markers on tiles)
  local function mapTalkHasGiftOrTrade(mapId, textId)
    if not mapId or not textId then return false, false end
    local set = getGiftTextSet(mapId)
    if type(set) ~= "table" then return false, false end
    local tu = type(textId) == "string" and textId:upper() or ""
    local info = set[textId] or set[tu]
    if not info then return false, false end
    -- Determine trade vs gift from events / reason stored
    local isTrade = false
    if type(info.events) == "table" then
      for _, ev in ipairs(info.events) do
        if type(ev) == "string" and ev:upper():find("TRADE", 1, true) then
          isTrade = true
          break
        end
      end
    end
    if type(tu) == "string" and tu:find("TRADE", 1, true)
        and not tu:find("TRADE_HOUSE", 1, true) then
      isTrade = true
    end
    return true, isTrade
  end

  -- Strict NPC giver/trade classification.
  -- IMPORTANT: only the NPC's own text/script, explicit object flags, or a
  -- known map+object definition may make an NPC BLUE. We do NOT scan all
  -- scripts on the map for every NPC.
  local function objectIsItemGiver(obj, mapId, index)
    if not obj then return false end
    if objectIsTrainer(obj) then return false end

    local def = type(obj.def) == "table" and obj.def or obj
    local textId = objectTextId(obj)

    -- 1) Exact talk-script match for this object's own text ID.
    if textId ~= nil then
      local has, isTrade = mapTalkHasGiftOrTrade(mapId, textId)
      if has then
        return true, isTrade and "trade" or "talk-gift"
      end
    end

    -- 2) Explicit object metadata. These are safe because they belong to
    -- the object itself and cannot be caused by another NPC's script.
    if def.trade == true or def.isTrade == true
        or def.tradePokemon == true or def.isTradePokemon == true
        or obj.trade == true or obj.isTrade == true
        or obj.tradePokemon == true or obj.isTradePokemon == true then
      return true, "trade-flag"
    end
    if def.giveItem == true or def.givePokemon == true
        or def.giveKeyItem == true or def.giveTM == true or def.giveHM == true
        or obj.giveItem == true or obj.givePokemon == true
        or obj.giveKeyItem == true or obj.giveTM == true or obj.giveHM == true then
      return true, "giver-flag"
    end

    -- 3) Known gift/trade definitions for THIS generation only.
    local defs = giftsForMap(mapId, activeGame)
    local idx = objectIndex(obj) or tonumber(index)
    local tu = type(textId) == "string" and textId:upper() or ""
    if defs then
      for _, gdef in ipairs(defs) do
        local match = false
        -- indices = { n }: only that object. indices = {}: hints/text only —
        -- never paint every indoor NPC blue.
        if type(gdef.indices) == "table" and #gdef.indices > 0 and idx ~= nil then
          for _, gi in ipairs(gdef.indices) do
            if tonumber(idx) == tonumber(gi) then
              match = true
              break
            end
          end
        end
        if not match and tu ~= "" and type(gdef.hints) == "table" then
          for _, hint in ipairs(gdef.hints) do
            local hu = tostring(hint):upper()
            if #hu >= 3 and (tu == hu or tu:find(hu, 1, true)) then
              match = true
              break
            end
          end
        end
        if match then
          local trade = gdef.trade == true
          if type(gdef.event) == "string" and gdef.event:upper():find("TRADE", 1, true) then
            trade = true
          end
          return true, trade and "trade-known" or "gift-known"
        end
      end
    end
    -- Gen2-only: Berry House single-NPC gift
    if getGameVersion(activeGame) == "gold" then
      local mk = giftMapKey(mapId)
      if mk and (mk:find("BERRY_HOUSE", 1, true) or mk:find("BERRYHOUSE", 1, true)
          or mk:find("BERRY_SPEECH", 1, true)) then
        if not objectIsTrainer(obj) and not objectIsBerryTree(obj)
            and not isItemBallObject(obj) then
          return true, "gift-known"
        end
      end
    end

    -- 4) Gen1 trade houses: always mark the real trader object index(es)
    -- (pret object_event order). Do NOT bail out when getGiftTextSet is
    -- non-nil — that used to return false and kill all blue trade markers.
    if isTradeMap(mapId, activeGame) then
      local k = giftMapKey(mapId)
      local TRADE_NPC_INDICES = {
        CERULEAN_TRADE_HOUSE = { 2 }, CERULEANTRADEHOUSE = { 2 },
        ROUTE_2_TRADE_HOUSE = { 2 }, ROUTE2TRADEHOUSE = { 2 },
        VERMILION_TRADE_HOUSE = { 1 }, VERMILIONTRADEHOUSE = { 1 },
        ROUTE_11_GATE_2F = { 1 }, ROUTE11GATE2F = { 1 },
        ROUTE_12_GATE_2F = { 1 }, ROUTE12GATE2F = { 1 },
        ROUTE_18_GATE_2F = { 1 }, ROUTE18GATE2F = { 1 },
        UNDERGROUND_PATH_ROUTE_5 = { 1 }, UNDERGROUNDPATHROUTE5 = { 1 },
        CINNABAR_LAB_FOSSIL_ROOM = { 2 }, CINNABARLABFOSSILROOM = { 2 },
        CINNABAR_LAB_TRADE_ROOM = { 2, 3 }, CINNABARLABTRADEROOM = { 2, 3 },
      }
      local indices = TRADE_NPC_INDICES[k]
      if type(indices) == "table" then
        local nIdx = tonumber(index) or tonumber(idx)
        for _, ti in ipairs(indices) do
          if nIdx == ti or tonumber(idx) == ti then
            return true, "trade"
          end
        end
      end
    end

    -- 5) Bike Shop has a known seller object. Keep the original special case,
    -- but only for object 1 on the actual Bike Shop map.
    local mapKey = giftMapKey(mapId)
    if mapKey and mapKey:find("BIKE_SHOP", 1, true) then
      if idx == 1 or tonumber(index) == 1 then
        return true, "bike-giver"
      end
    end

    return false
  end

 -- Freestanding overworld pokemon (Snorlax, birds, Sudowoodo, …)
  local function objectIsStaticPokemon(obj)
    if not obj then return false end
    local def = (type(obj.def) == "table" and obj.def) or obj
    if obj.pokemon or def.pokemon then return true end
    if obj.species and not objectIsTrainer(obj) and not (obj.item or def.item) then
      -- species without trainerClass often means static encounter
      if not (obj.trainerClass or def.trainerClass) then
        return true
      end
    end
    if def.species and not (def.trainerClass or obj.trainerClass)
        and not (obj.item or def.item) then
      return true
    end
    local spr = objectSpriteId(obj)
    if type(spr) == "string" then
      local u = spr:upper()
      if u:find("SNORLAX", 1, true) or u:find("RELAXO", 1, true)
          or u:find("SUDOWOODO", 1, true) or u:find("LAPRAS", 1, true)
          or u:find("MEWTWO", 1, true) or u:find("ARTICUNO", 1, true)
          or u:find("ZAPDOS", 1, true) or u:find("MOLTRES", 1, true)
          or u:find("LUGIA", 1, true) or u:find("HO_OH", 1, true)
          or u:find("HOOH", 1, true) or u:find("CELEBI", 1, true)
          or u:find("GYARADOS", 1, true) or u:find("RED_GYARADOS", 1, true) then
        return true
      end
    end
    return false
  end
  giftEventsForObject = function(obj, mapId)
    local out = {}
    local seen = {}
    local function add(ev)
      if ev == nil or ev == "" then return end
      local key = tostring(ev)
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = ev
      end
    end
    local textId = objectTextId(obj)
    local tu = type(textId) == "string" and textId:upper() or ""
    local idx = objectIndex(obj)
    local defs = giftsForMap(mapId, activeGame)
    if defs then
      for _, gdef in ipairs(defs) do
        local match = false
        if type(gdef.indices) == "table" and #gdef.indices > 0 and idx ~= nil then
          for _, gi in ipairs(gdef.indices) do
            if idx == gi or tonumber(idx) == tonumber(gi) then
              match = true
              break
            end
          end
        end
        if not match and tu ~= "" and type(gdef.hints) == "table" then
          for _, hint in ipairs(gdef.hints) do
            local hu = tostring(hint):upper()
            if #hu >= 3 and (tu == hu or tu:find(hu, 1, true)) then
              match = true
              break
            end
          end
        end
        if match then
          add(gdef.event)
          if gdef.eventId then add(gdef.eventId) end
        end
      end
    end
    local info = giftInfoForText(mapId, textId)
    if info then
      if info.event then add(info.event) end
      if type(info.events) == "table" then
        for _, ev in ipairs(info.events) do add(ev) end
      end
    end
    return out
  end
  local function objectFacing(obj)
    if type(obj) ~= "table" then
      return "down"
    end
    local f = obj.facing or obj.direction or obj.dir or obj.face
    if f == nil and type(obj.getFacing) == "function" then
      local ok, got = pcall(obj.getFacing, obj)
      if ok then
        f = got
      end
    end
    if type(f) == "string" then
      local key = f:lower()
      if key == "up" or key == "north" or key == "n" then
        return "up"
      end
      if key == "down" or key == "south" or key == "s" then
        return "down"
      end
      if key == "left" or key == "west" or key == "w" then
        return "left"
      end
      if key == "right" or key == "east" or key == "e" then
        return "right"
      end
    end
    if type(f) == "number" then
      local map = { [0] = "down", [1] = "up", [2] = "left", [3] = "right", [4] = "down" }
      return map[f] or map[f % 4] or "down"
    end
    if type(obj.def) == "table" and type(obj.def.range) == "string" then
      local r = obj.def.range:lower()
      if r == "up" or r == "down" or r == "left" or r == "right" then
        return r
      end
    end
    return "down"
  end
  local function isPersonSprite(spr)
    if type(spr) ~= "string" then return false end
    local u = spr:upper()
    if u:find("BALL", 1, true) or u:find("FOSSIL", 1, true)
        or u:find("BOULDER", 1, true) or u:find("ROCK", 1, true)
        or u:find("TREE", 1, true) or u:find("BUSH", 1, true)
        or u:find("CUT", 1, true) or u:find("PLANT", 1, true)
        or u:find("CABLE", 1, true) or u:find("SIGN", 1, true)
        or u:find("SNORLAX", 1, true) or u:find("RELAXO", 1, true) then
      return false
    end
    return u:find("SPRITE_", 1, true) ~= nil or u:find("NPC", 1, true) ~= nil
  end
  local function isItemBallObject(obj)
    if not obj then return false end
    if obj.isHiddenItem or obj.kindHint == "hidden" then return false end
    local spr = objectSpriteId(obj)
    if type(spr) == "string" then
      local u = spr:upper()
      if u:find("BALL", 1, true) or u:find("FOSSIL", 1, true) then
        return true
      end
    end
    if objectItemId(obj) and not isPersonSprite(spr) then
      local def = obj.def or obj
      if objectIsTrainer(obj) then return false end
      if def.trainerClass or def.movement or def.range then return false end
      if type(spr) == "string" and isPersonSprite(spr) then return false end
      if spr == nil or (type(spr) == "string" and spr:upper():find("BALL", 1, true)) then
        return true
      end
    end
    return false
  end
  local lastGiftReason = nil
  -- Auto kinds → marker colors:
  --   trainer  → RED
  --   item/hidden → GREEN (pokéball)
  --   gift_npc (item reward OR in-game trade) → BLUE
  --   object (freestanding pokemon sprite, NOT a give-item) → BLUE
  --   npc → neutral
  -- Gen2 fruit/berry trees only (strict — no random TREE sprites)
  local function objectIsBerryTree(obj)
    if not obj then return false end
    local def = (type(obj.def) == "table" and obj.def) or obj
    if obj.fruitTree == true or def.fruitTree == true then return true end
    if obj.berryTree == true or def.berryTree == true then return true end
    if type(obj.fruitTree) == "string" or type(def.fruitTree) == "string" then return true end
    if type(obj.berry) == "string" or type(def.berry) == "string" then return true end
    if type(obj.fruit) == "string" or type(def.fruit) == "string" then return true end
    local spr = objectSpriteId(obj)
    if type(spr) == "string" then
      local u = spr:upper()
      if u:find("FRUIT_TREE", 1, true) or u:find("FRUITTREE", 1, true)
          or u:find("BERRY_TREE", 1, true) or u:find("BERRYTREE", 1, true)
          or u:find("APRICORN_TREE", 1, true) or u:find("APRICORNTREE", 1, true)
          or u == "SPRITE_FRUIT_TREE" or u == "SPRITE_BERRY_TREE" then
        return true
      end
    end
    return false
  end
  -- pret FRUITTREE_* ids (const_def 1) keyed by map + cell (x,y).
  -- Used when the object def does not carry the tree id itself.
  local FRUIT_TREE_XY = {
    ROUTE_29 = { ["12,2"] = 1 },
    ROUTE29 = { ["12,2"] = 1 },
    ROUTE_30 = { ["5,39"] = 2, ["11,5"] = 5 },
    ROUTE30 = { ["5,39"] = 2, ["11,5"] = 5 },
    ROUTE_31 = { ["16,7"] = 7 },
    ROUTE31 = { ["16,7"] = 7 },
    ROUTE_33 = { ["14,16"] = 6 },
    ROUTE33 = { ["14,16"] = 6 },
    ROUTE_35 = { ["2,25"] = 11 },
    ROUTE35 = { ["2,25"] = 11 },
    ROUTE_36 = { ["21,4"] = 13 },
    ROUTE36 = { ["21,4"] = 13 },
    ROUTE_37 = { ["13,5"] = 17, ["16,5"] = 18, ["15,7"] = 19 },
    ROUTE37 = { ["13,5"] = 17, ["16,5"] = 18, ["15,7"] = 19 },
    ROUTE_38 = { ["12,10"] = 3 },
    ROUTE38 = { ["12,10"] = 3 },
    ROUTE_39 = { ["9,3"] = 15 },
    ROUTE39 = { ["9,3"] = 15 },
    ROUTE_42 = { ["27,16"] = 21, ["28,16"] = 22, ["29,16"] = 23 },
    ROUTE42 = { ["27,16"] = 21, ["28,16"] = 22, ["29,16"] = 23 },
    ROUTE_43 = { ["1,26"] = 8 },
    ROUTE43 = { ["1,26"] = 8 },
    ROUTE_44 = { ["9,5"] = 16 },
    ROUTE44 = { ["9,5"] = 16 },
    ROUTE_45 = { ["16,82"] = 12 },
    ROUTE45 = { ["16,82"] = 12 },
    ROUTE_46 = { ["7,5"] = 4, ["8,6"] = 10 },
    ROUTE46 = { ["7,5"] = 4, ["8,6"] = 10 },
    VIOLET_CITY = { ["14,29"] = 9 },
    VIOLETCITY = { ["14,29"] = 9 },
    AZALEA_TOWN = { }, -- FRUITTREE_AZALEA_TOWN = 20, coords filled if needed
    AZALEATOWN = { },
  }
  -- Gen2 fruit trees are keyed by FRUITTREE_* (1-based) in save.fruitTrees.
  -- true = already picked today (Apricorns.treePicked / World:fruitTreePicked).
  local function fruitTreeIdOf(obj, game, mapId)
    if not obj then return nil end
    local def = (type(obj.def) == "table" and obj.def) or obj
    local candidates = {
      obj.fruitTree, def.fruitTree, obj.treeId, def.treeId,
      obj.tree, def.tree, obj.fruittree, def.fruittree,
      obj.fruit_tree, def.fruit_tree,
    }
    for _, c in ipairs(candidates) do
      if type(c) == "number" and c > 0 then return c end
      if type(c) == "string" and c ~= "" then
        local n = tonumber(c)
        if n and n > 0 then return n end
        local num = c:match("(%d+)$")
        if num then
          n = tonumber(num)
          if n and n > 0 then return n end
        end
      end
    end
    -- Script form: { op = "fruittree", tree = N } or { "fruittree", N }
    local function scanScript(rows, depth)
      if depth > 8 or type(rows) ~= "table" then return nil end
      if rows.op == "fruittree" or rows.cmd == "fruittree"
          or rows[1] == "fruittree" then
        local t = rows.tree or rows.arg1 or rows[2] or rows.id
        t = tonumber(t) or t
        if type(t) == "number" and t > 0 then return t end
      end
      for _, row in pairs(rows) do
        if type(row) == "table" then
          local hit = scanScript(row, depth + 1)
          if hit then return hit end
        end
      end
      return nil
    end
    local script = obj.script or def.script or obj.commands or def.commands
        or obj.talk or def.talk or obj.scriptKey or def.scriptKey
    if type(script) == "table" then
      local hit = scanScript(script, 0)
      if hit then return hit end
    end
    -- Resolve script key string via content/data tables
    if type(script) == "string" and script ~= "" then
      local sources = {}
      pcall(function()
        if mod.content and mod.content.scripts and mod.content.scripts.get then
          sources[#sources + 1] = mod.content.scripts:get(script)
        end
      end)
      pcall(function()
        local data = game and game.data
        if type(data) == "table" then
          local bag = data.scripts or data.map_scripts or data.generated
          if type(bag) == "table" then
            sources[#sources + 1] = bag[script] or (bag.scripts and bag.scripts[script])
          end
        end
      end)
      for _, src in ipairs(sources) do
        if type(src) == "table" then
          local hit = scanScript(src, 0)
          if hit then return hit end
        end
      end
    end
    -- Static pret FRUITTREE_* lookup by map + cell
    if mapId then
      local mk = tostring(mapId):upper():gsub("%s+", "_")
      local byXy = FRUIT_TREE_XY[mk] or FRUIT_TREE_XY[mk:gsub("_", "")]
      if byXy then
        local ox = tonumber(obj.cellX) or (def and tonumber(def.x))
        local oy = tonumber(obj.cellY) or (def and tonumber(def.y))
        if ox and oy then
          local key = tostring(math.floor(ox)) .. "," .. tostring(math.floor(oy))
          if byXy[key] then return byXy[key] end
        end
      end
    end
    return nil
  end
  local function berryTreeHasBerry(game, obj, mapId)
    -- Hide when already picked today / empty
    local def = (type(obj.def) == "table" and obj.def) or obj
    if obj.berry == false or def.berry == false then return false end
    if obj.hasBerry == false or def.hasBerry == false then return false end
    if obj.fruit == false or def.fruit == false then return false end
    if obj.picked == true or def.picked == true then return false end
    if obj.empty == true or def.empty == true then return false end

    local treeId = fruitTreeIdOf(obj, game, mapId)
    local save = game and game.save
    local world = getGen2World(game)

    -- Preferred: engine API (exact Gen2 semantics)
    if treeId then
      if world and type(world.fruitTreePicked) == "function" then
        local ok, picked = pcall(function() return world:fruitTreePicked(treeId) end)
        if ok and picked then return false end
      end
      if save then
        local okA, picked = pcall(function()
          local Apricorns = require("src.core.gen2.Apricorns")
          return Apricorns.treePicked(save, treeId)
        end)
        if okA and picked then return false end
        if type(save.fruitTrees) == "table" then
          local st = save.fruitTrees[treeId] or save.fruitTrees[tostring(treeId)]
          if st == true or st == 1 then return false end
        end
      end
    end

    -- Fallback: any save.fruitTrees entry for this map object index
    if save then
      local idx = objectIndex(obj) or obj.index or (def and def.index)
      local tables = { save.fruitTrees, save.berryTrees, save.fruit_trees,
                       save.dailyFruit, save.gen2FruitTrees }
      for _, t in ipairs(tables) do
        if type(t) == "table" then
          if treeId then
            local st = t[treeId] or t[tostring(treeId)]
            if st == true or st == 1 or st == false or st == 0 then
              if st == true or st == 1 then return false end
            end
          end
          if mapId and idx ~= nil then
            local key = tostring(mapId) .. "_obj_" .. tostring(idx)
            local st = t[key] or t[idx] or t[tostring(idx)]
            if st == true or st == 1 then return false end
            if st == false or st == 0
                or (type(st) == "table" and (st.berry == false or st.picked or st.empty)) then
              return false
            end
          end
        end
      end
    end
    return true
  end
  local function objectKind(obj, mapId, index)
    if obj.isHiddenItem or obj.kindHint == "hidden" then return "hidden" end
    local def = (type(obj.def) == "table" and obj.def) or obj
    if objectIsStaticPokemon(obj) then return "object" end
    -- Berry/fruit tree with available berry → green item marker
    if objectIsBerryTree(obj) then
      return "item"
    end
    local hasItem = (obj.item and obj.item ~= 0 and obj.item ~= "0")
        or (def.item and def.item ~= 0 and def.item ~= "0")
    if hasItem then return "item" end
    if objectIsTrainer(obj) then return "trainer" end
    local isGiver, reason = objectIsItemGiver(obj, mapId, index)
    if isGiver then
      lastGiftReason = reason
      return "gift_npc"
    end
    if isItemBallObject(obj) then return "item" end
    return "npc"
  end
  local spriteCache = {}
  local function markerMapColorMode(game)
    return getOpt(game, "minimap_map_color", "recomp")
  end

  local NPC_PALETTE = {
    { 250, 242, 222 },
    { 235, 168, 90 },
    { 140, 90, 55 },
    { 35, 25, 20 },
  }
  local TRAINER_PALETTE = {
    { 250, 235, 230 },
    { 235, 70, 55 },
    { 150, 30, 25 },
    { 30, 10, 10 },
  }
  local PLAYER_PALETTE = {
    { 245, 240, 235 },
    { 225, 40, 40 },
    { 40, 80, 170 },
    { 20, 15, 15 },
  }
  local POKEBALL_PALETTE = {
    { 250, 250, 250 },
    { 230, 40, 40 },
    { 140, 20, 20 },
    { 20, 20, 20 },
  }

  local ITEM_PALETTE = POKEBALL_PALETTE
  -- Original Game Boy look for player/NPC/item markers on the minimap.
  -- Mirrors the neutral 4-shade fallback already used by drawPokeballIcon
  -- so OG mode is visually consistent (monochrome) across all markers.
  local OG_MARKER_PALETTE = {
    { 255, 255, 255 },
    { 190, 190, 190 },
    { 90, 90, 90 },
    { 20, 20, 20 },
  }
  local function recolorImageDataFromPath(imgPath, palette)
    if not love.image or not love.image.newImageData then
      return nil
    end
    local okData, data = pcall(love.image.newImageData, imgPath)
    if not okData or not data then
      return nil
    end
    local iw, ih = data:getWidth(), data:getHeight()

    do
      local samples, chroma = 0, 0
      local step = math.max(1, math.floor(math.max(iw, ih) / 24))
      for y = 0, ih - 1, step do
        for x = 0, iw - 1, step do
          local r, g, b, a = data:getPixel(x, y)
          if a and a > 0.1 then
            samples = samples + 1
            chroma = chroma + (math.max(r, g, b) - math.min(r, g, b))
          end
        end
      end
      local mostlyGray = samples < 1 or (chroma / samples) < 0.06
      if not mostlyGray then
        return nil
      end
    end
    local out = love.image.newImageData(iw, ih)
    for y = 0, ih - 1 do
      for x = 0, iw - 1 do
        local r, g, b, a = data:getPixel(x, y)
        if a and a > 0 then
          local lum = r * 0.2126 + g * 0.7152 + b * 0.0722
          local shade = lum > 0.83 and 1 or (lum > 0.5 and 2 or (lum > 0.17 and 3 or 4))
          local c = palette[shade]
          out:setPixel(x, y, c[1] / 255, c[2] / 255, c[3] / 255, a)
        else
          out:setPixel(x, y, 0, 0, 0, 0)
        end
      end
    end
    local okImg, colored = pcall(love.graphics.newImage, out)
    if okImg and colored then
      pcall(function()
        colored:setFilter("nearest", "nearest")
      end)
      return colored
    end
    return nil
  end
  -- Same luminance-to-palette remap as recolorImageDataFromPath, but always
  -- applies regardless of the source sprite's original colorfulness. The
  -- gated version above only recolors already-near-grayscale GBC-style art;
  -- OG mode needs to flatten full-color recomp sprites into a monochrome
  -- look too, so it must skip that "mostlyGray" bailout.
  local function recolorImageDataForced(imgPath, palette)
    if not love.image or not love.image.newImageData then
      return nil
    end
    local okData, data = pcall(love.image.newImageData, imgPath)
    if not okData or not data then
      return nil
    end
    local iw, ih = data:getWidth(), data:getHeight()
    local out = love.image.newImageData(iw, ih)
    for y = 0, ih - 1 do
      for x = 0, iw - 1 do
        local r, g, b, a = data:getPixel(x, y)
        if a and a > 0 then
          local lum = r * 0.2126 + g * 0.7152 + b * 0.0722
          local shade = lum > 0.83 and 1 or (lum > 0.5 and 2 or (lum > 0.17 and 3 or 4))
          local c = palette[shade]
          out:setPixel(x, y, c[1] / 255, c[2] / 255, c[3] / 255, a)
        else
          out:setPixel(x, y, 0, 0, 0, 0)
        end
      end
    end
    local okImg, colored = pcall(love.graphics.newImage, out)
    if okImg and colored then
      pcall(function()
        colored:setFilter("nearest", "nearest")
      end)
      return colored
    end
    return nil
  end
  local function tryLoadImage(path, palette, forceRecolor)
    if type(path) ~= "string" then return nil end
    local paths = { path }
    for _, prefix in ipairs({
      "", "assets/", "assets/generated/", "assets/generated/sprites/",
    }) do
      if prefix ~= "" or path ~= paths[1] then
        paths[#paths + 1] = prefix .. path
      end
    end
    local seen = {}
    local uniq = {}
    for _, p in ipairs(paths) do
      if not seen[p] then
        seen[p] = true
        uniq[#uniq + 1] = p
      end
    end
    for _, p in ipairs(uniq) do
      if palette then
        local colored = forceRecolor and recolorImageDataForced(p, palette)
            or recolorImageDataFromPath(p, palette)
        if colored then
          return colored
        end
      end
      local ok, img = pcall(love.graphics.newImage, p)
      if ok and img then
        pcall(function() img:setFilter("nearest", "nearest") end)
        return img
      end
    end
    return nil
  end
  local STANDING_FRAME = {
    down = 0,
    up = 1,
    left = 2,
    right = 2,
  }
  local function normalizeFacing(facing)
    if type(facing) ~= "string" then
      return "down"
    end
    local f = facing:lower()
    if f == "up" or f == "north" or f == "n" then
      return "up"
    end
    if f == "down" or f == "south" or f == "s" then
      return "down"
    end
    if f == "left" or f == "west" or f == "w" then
      return "left"
    end
    if f == "right" or f == "east" or f == "e" then
      return "right"
    end
    return "down"
  end
  local function lookupStandingInFrames(frames, facing)
    if type(frames) ~= "table" then
      return nil
    end
    local candidates = {
      facing,
      facing .. "_idle",
      facing .. "_stand",
      "idle_" .. facing,
      "stand_" .. facing,
    }
    for _, key in ipairs(candidates) do
      local f = frames[key]
      if type(f) == "number" then
        return f
      end
      if type(f) == "table" then
        if type(f.frame) == "number" then
          return f.frame
        end
        if f.quad then
          return f
        end
        if type(f[1]) == "number" then
          return f[1]
        end
        if type(f[1]) == "table" then
          if f[1].quad then
            return f[1]
          end
          if type(f[1].frame) == "number" then
            return f[1].frame
          end
        end
      end
    end
    return nil
  end
  local function standingFrameIndex(def, facing)
    facing = normalizeFacing(facing)
    local frames = type(def) == "table" and (def.frames or def.directionFrames) or nil
    if facing == "right" then
      local rightHit = lookupStandingInFrames(frames, "right")
      local leftHit = lookupStandingInFrames(frames, "left")
      if rightHit ~= nil then
        if type(rightHit) == "number" and type(leftHit) == "number" and rightHit == leftHit then
          return leftHit
        end
        if type(rightHit) == "table" then
          return rightHit
        end
        if type(leftHit) ~= "number" or rightHit ~= leftHit then
          return rightHit
        end
      end
      if type(leftHit) == "number" then
        return leftHit
      end
      if type(leftHit) == "table" then
        return leftHit
      end
      return STANDING_FRAME.left
    end
    local hit = lookupStandingInFrames(frames, facing)
    if hit ~= nil then
      return hit
    end
    return STANDING_FRAME[facing] or 0
  end
  local function loadSpriteFrame(spriteId, facing, palette, paletteTag, forceRecolor)
    if not spriteId or type(spriteId) ~= "string" then
      return nil
    end
    facing = normalizeFacing(facing)
    local cacheKey = spriteId .. ":stand:" .. facing .. (paletteTag and (":" .. paletteTag) or "")
    local cached = spriteCache[cacheKey]
    if cached ~= nil then
      return cached or nil
    end
    local def = nil
    if mod.content and mod.content.sprites and type(mod.content.sprites.get) == "function" then
      local ok, d = pcall(function()
        return mod.content.sprites:get(spriteId)
      end)
      if ok then
        def = d
      end
    end
    if type(def) ~= "table" or not def.image then
      spriteCache[cacheKey] = false
      return nil
    end
    local img = tryLoadImage(def.image, palette, forceRecolor)
    if not img then
      spriteCache[cacheKey] = false
      return nil
    end
    local fw = tonumber(def.frameWidth) or 16
    local fh = tonumber(def.frameHeight) or 16
    local iw, ih = img:getWidth(), img:getHeight()
    local cols = math.max(1, math.floor(iw / fw))
    local rows = math.max(1, math.floor(ih / fh))
    local maxFrame = cols * rows - 1
    local function makeEntry(frameIndex, flipX)
      if frameIndex < 0 or frameIndex > maxFrame then
        return nil
      end
      local fx = (frameIndex % cols) * fw
      local fy = math.floor(frameIndex / cols) * fh
      if fx + fw > iw or fy + fh > ih then
        return nil
      end
      return {
        image = img,
        quad = love.graphics.newQuad(fx, fy, fw, fh, iw, ih),
        fw = fw,
        fh = fh,
        flipX = flipX and true or nil,
      }
    end
    local picked = standingFrameIndex(def, facing)
    local flipX = (facing == "right")
    if type(picked) == "table" and picked.quad then
      local entry = {
        image = img,
        quad = picked.quad,
        fw = fw,
        fh = fh,
        flipX = picked.flipX or (facing == "right" and not picked.noFlip) or nil,
      }
      if facing == "right" and def and def.frames and def.frames.right and not picked.flipX then
        entry.flipX = nil
      end
      spriteCache[cacheKey] = entry
      return entry
    end
    local frame = type(picked) == "number" and picked or (STANDING_FRAME[facing] or 0)
    if facing == "right" then
      local leftPicked = standingFrameIndex(def, "left")
      local leftIdx = type(leftPicked) == "number" and leftPicked or STANDING_FRAME.left
      local rightPicked = lookupStandingInFrames(
        type(def) == "table" and (def.frames or def.directionFrames) or nil,
        "right"
      )
      if type(rightPicked) == "number" and rightPicked ~= leftIdx then
        frame = rightPicked
        flipX = false
      else
        frame = leftIdx
        flipX = true
      end
    end
    local entry = makeEntry(frame, flipX)
    if not entry then
      entry = makeEntry(STANDING_FRAME.left or 2, facing == "right")
    end
    if not entry then
      entry = makeEntry(0, false)
    end
    if not entry then
      spriteCache[cacheKey] = false
      return nil
    end
    spriteCache[cacheKey] = entry
    return entry
  end
  local function spriteFromEntity(obj, facing)
    local sr = obj and obj.sprite
    if type(sr) ~= "table" then
      return nil
    end
    facing = normalizeFacing(facing)
    local img = sr.image
    if type(img) == "string" then
      img = tryLoadImage(img)
    end
    if type(sr.resolveImage) == "function" then
      local ok, resolved = pcall(function()
        return sr:resolveImage()
      end)
      if ok and resolved then
        img = resolved
        if type(img) == "string" then
          img = tryLoadImage(img)
        end
      end
    end
    if not img or type(img) ~= "userdata" or type(img.getWidth) ~= "function" then
      return nil
    end
    local fw = tonumber(sr.frameWidth) or 16
    local fh = tonumber(sr.frameHeight) or 16
    local frames = sr.frames or sr.directionFrames
    local flipX = false
    local frame = STANDING_FRAME[facing] or 0
    if facing == "right" then
      local rightHit = lookupStandingInFrames(frames, "right")
      local leftHit = lookupStandingInFrames(frames, "left")
      if type(rightHit) == "table" and rightHit.quad then
        return { image = img, quad = rightHit.quad, fw = fw, fh = fh }
      end
      if type(rightHit) == "number"
          and type(leftHit) == "number"
          and rightHit ~= leftHit then
        frame = rightHit
        flipX = false
      else
        if type(leftHit) == "table" and leftHit.quad then
          return { image = img, quad = leftHit.quad, fw = fw, fh = fh, flipX = true }
        end
        frame = type(leftHit) == "number" and leftHit or STANDING_FRAME.left
        flipX = true
      end
    else
      local hit = lookupStandingInFrames(frames, facing)
      if type(hit) == "table" and hit.quad then
        return { image = img, quad = hit.quad, fw = fw, fh = fh }
      end
      if type(hit) == "number" then
        frame = hit
      else
        frame = STANDING_FRAME[facing] or 0
      end
    end
    if type(sr.getFrameGeometry) == "function" then
      local ok, geo = pcall(function()
        return sr:getFrameGeometry(frame)
      end)
      if ok and geo and geo.quad then
        return { image = img, quad = geo.quad, fw = fw, fh = fh, flipX = flipX or nil }
      end
    end
    local iw, ih = img:getWidth(), img:getHeight()
    local cols = math.max(1, math.floor(iw / fw))
    local rows = math.max(1, math.floor(ih / fh))
    local maxFrame = cols * rows - 1
    if frame < 0 or frame > maxFrame then
      frame = flipX and (STANDING_FRAME.left or 2) or 0
      if frame > maxFrame then
        frame = 0
        flipX = false
      end
    end
    local fx = (frame % cols) * fw
    local fy = math.floor(frame / cols) * fh
    local quad = love.graphics.newQuad(
      fx,
      fy,
      math.min(fw, iw - fx),
      math.min(fh, ih - fy),
      iw,
      ih
    )
    return { image = img, quad = quad, fw = fw, fh = fh, flipX = flipX or nil }
  end
  local function resolveGbcMarkerPalette(game, mapId)
    if markerMapColorMode(game) ~= "gbc" then return nil end
    local ver = getGameVersion(game)
    if ver == "gold" then
      return nil
    end
    local okP, P = pcall(require, "src.render.PaletteFX")
    if okP and P and type(P.ogObj) == "function" then
      local ok, colors = pcall(function()
        local c = P.ogObj()
        if type(c) == "table" and c.colors then return c.colors end
        return c
      end)
      if ok and colors then
        return normalizeMarkerPalette(colors) or colors
      end
    end
    return { {255,255,255}, {123,255,49}, {0,132,0}, {0,0,0} }
  end

  local function resolveGoldRecompMarkerPalette(game, obj)
    local world = game and game.world
    if not world then return nil end
    local okP, Palettes = pcall(require, "src.world.gen2.Palettes")
    if not okP or not Palettes then return nil end
    local spriteDef = obj and (obj.spriteDef or (obj.sprite and obj.sprite.def))
    if not spriteDef and mod.content and mod.content.sprites
        and type(mod.content.sprites.get) == "function" then
      for _, id in ipairs({
        "SPRITE_POKE_BALL", "SPRITE_BALL", "SPRITE_POKEBALL",
        "SPRITE_ITEM_BALL", "POKE_BALL", "BALL", "ITEM_BALL"
      }) do
        local ok, d = pcall(function() return mod.content.sprites:get(id) end)
        if ok and type(d) == "table" then
          spriteDef = d
          break
        end
      end
    end
    if not spriteDef then return nil end
    local daytime = world.daytime
    if not daytime and type(world.hour) == "function" then
      local ok, hour = pcall(function() return world:hour() end)
      if ok then daytime = Palettes.daytimeFor(world.map and world.map.def, hour, world.flashUsed) end
    end
    daytime = daytime or "DAY"
    local colors = nil
    pcall(function()
      colors = Palettes.spritePalette(world.palettes, daytime, spriteDef, obj and obj.def)
    end)
    return colors
  end

  local function resolveRecompMarkerPalette(game, obj, mapId)
    local mode = markerMapColorMode(game)
    if mode ~= "recomp" then return nil end
    local ver = getGameVersion(game)
    if ver == "gold" then
      return resolveGoldRecompMarkerPalette(game, obj)
    end
    local okP, P = pcall(require, "src.render.PaletteFX")
    if not okP or not P or not P.usesGbcPack or not P.usesGbcPack() then
      return nil
    end
    local def = obj and (obj.spriteDef or obj.def)
    if not def and mod.content and mod.content.sprites
        and type(mod.content.sprites.get) == "function" then
      for _, id in ipairs({
        "SPRITE_POKE_BALL", "SPRITE_BALL", "SPRITE_POKEBALL",
        "SPRITE_ITEM_BALL", "POKE_BALL", "BALL", "ITEM_BALL"
      }) do
        local ok, d = pcall(function() return mod.content.sprites:get(id) end)
        if ok and type(d) == "table" then
          def = d
          break
        end
      end
    end
    local colors = nil
    pcall(function() colors = P.spriteObp(def, obj and (obj.id or obj.index or mapId)) end)
    return colors
  end

  local function getPokeballSprite(palette, paletteTag)
    for _, id in ipairs({
      "SPRITE_POKE_BALL", "SPRITE_BALL", "SPRITE_POKEBALL", "SPRITE_ITEM_BALL",
      "SPRITE_POKE_BALL_ITEM", "POKE_BALL", "BALL", "ITEM_BALL",
      "SPRITE_OBJ_POKE_BALL", "SPRITE_FIELD_POKE_BALL", "SPRITE_HIDDEN_ITEM",
    }) do
      local s = loadSpriteFrame(id, "down", palette, paletteTag or "ball")
      if s then
        return s
      end
    end
    return nil
  end

  local function drawPokeballIcon(px, py, r, mode, game, mapId, obj)
    local p = nil
    if mode == "og" then
      p = OG_MARKER_PALETTE
    elseif mode == "gbc" then
      p = resolveGbcMarkerPalette(game, mapId) or ITEM_PALETTE
    elseif mode == "recomp" then
      if getGameVersion(game) == "gold" then
        p = resolveGoldRecompMarkerPalette(game, obj)
      else
        p = resolveRecompMarkerPalette(game, obj, mapId)
      end
      p = p or ITEM_PALETTE
    end
    p = p or OG_MARKER_PALETTE
    local function c(i)
      local q = p[i] or p[#p] or {255,255,255}
      love.graphics.setColor(q[1]/255, q[2]/255, q[3]/255, 1)
    end
    love.graphics.push()
    c(2); love.graphics.arc("fill", px, py, r, 0, math.pi)
    c(3); love.graphics.arc("fill", px, py, r, math.pi, math.pi * 2)
    c(4); love.graphics.setLineWidth(math.max(1, r * 0.28)); love.graphics.line(px-r, py, px+r, py)
    love.graphics.setLineWidth(1.2); love.graphics.circle("line", px, py, r)
    c(1); love.graphics.circle("fill", px, py, r*0.32)
    c(4); love.graphics.setLineWidth(1); love.graphics.circle("line", px, py, r*0.32)
    love.graphics.setColor(1,1,1,1)
    love.graphics.pop()
  end
  local function drawSpriteMarker(spr, px, py, markerSize, facing, tint)
    if not spr or not spr.image or not spr.quad then
      return false
    end
    local fw = spr.fw or 16
    local fh = spr.fh or 16
    local scale = markerSize / math.max(fw, fh)
    local dw = fw * scale
    local dh = fh * scale
    local sx = scale
    local ox = -dw / 2
    if spr.flipX then
      sx = -scale
      ox = dw / 2
    end
    love.graphics.push()
    love.graphics.translate(px, py)
    if tint then
      love.graphics.setColor(tint[1], tint[2], tint[3], tint[4] or 1)
    else
      love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.draw(spr.image, spr.quad, ox, -dh / 2, 0, sx, scale)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    return true
  end
  local function drawGlow(px, py, radius, r, g, b)
    love.graphics.setColor(r, g, b, 0.35)
    love.graphics.circle("fill", px, py, radius * 1.9)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", px, py, radius * 1.9)
    love.graphics.setColor(1, 1, 1, 1)
  end
  local function getHiddenItems(game, mapId)
    local out = {}
    local seen = {}
    local function add(x, y)
      x, y = tonumber(x), tonumber(y)
      if not x or not y then return end
      local k = x .. ":" .. y
      if seen[k] then return end
      seen[k] = true
      out[#out + 1] = { x = x, y = y }
    end
    local data = game and game.data
    local field = data and data.field
    local rows = field and field.hiddenItems and field.hiddenItems[mapId]
    if type(rows) == "table" then
      for _, row in ipairs(rows) do
        if type(row) == "table" then
          add(row.x or row[1], row.y or row[2])
        end
      end
    end
    if mod.world and type(mod.world.mapOverview) == "function" then
      local ok, overview = pcall(function() return mod.world:mapOverview() end)
      if ok and type(overview) == "table" and type(overview.markers) == "table" then
        for _, m in ipairs(overview.markers) do
          if m.kind == "hidden" then
            add(m.x, m.y)
          end
        end
      end
    end
    if #out == 0 and mod.content and mod.content.field then
      local f = mod.content.field
      if type(f.get) == "function" then
        local ok, hi = pcall(function() return f:get("hiddenItems") end)
        if ok and type(hi) == "table" and type(hi[mapId]) == "table" then
          for _, row in ipairs(hi[mapId]) do
            if type(row) == "table" then
              add(row.x or row[1], row.y or row[2])
            end
          end
        end
      end
    end
    return out
  end
  local function isHiddenTaken(game, mapId, x, y)
    local save = game and game.save
    if not save or type(save.hiddenTaken) ~= "table" then return false end
    local key = string.format("%s_%d_%d", tostring(mapId), x, y)
    return not not save.hiddenTaken[key]
  end
  local function isTrainerDefeated(game, obj, mapId)
    local def = (type(obj.def) == "table" and obj.def) or obj
    -- Gen2: trainer.event / eventFlag set when beaten
    if getGameVersion(game) == "gold" then
      local tr = obj.trainer or (def and def.trainer)
      local ef = nil
      if type(tr) == "table" then
        ef = tr.event or tr.eventFlag or tr.flag
      end
      ef = ef or obj.eventFlag or (def and def.eventFlag)
      if ef and ef ~= 0xFFFF and ef ~= -1 and type(ef) == "number" then
        if gen2EventFlagSet(game, ef) then return true end
      end
    end
    local save = game and game.save
    if not save or type(save.defeatedTrainers) ~= "table" then
      return false
    end
    local idx = objectIndex(obj)
    if mapId and idx ~= nil then
      local key = string.format("%s_obj_%s", tostring(mapId), tostring(idx))
      if save.defeatedTrainers[key] then
        return true
      end
      if save.defeatedTrainers[tostring(idx)] then
        return true
      end
    end
    if obj.id and save.defeatedTrainers[obj.id] then
      return true
    end
    if type(def) == "table" and def.id and save.defeatedTrainers[def.id] then
      return true
    end
    local tc = obj.trainerClass or (type(def) == "table" and def.trainerClass)
    if tc and mapId then
      local key2 = string.format("%s_%s", tostring(mapId), tostring(tc))
      if save.defeatedTrainers[key2] then
        return true
      end
    end
    return false
  end
  local function isObjectTaken(game, obj, mapId)
    if not obj then return false end
    local def = (type(obj.def) == "table" and obj.def) or obj
    local ef = obj.eventFlag or def.eventFlag or obj.event_flag or def.event_flag
    local isGen2 = getGameVersion(game) == "gold"
    -- Gen1: named string flags. Gen2: numeric bitfield. Never cross-read.
    if ef ~= nil and ef ~= 0xFFFF and ef ~= -1 and ef ~= 0 then
      if isGen2 and type(ef) == "number" then
        if gen2EventFlagSet(game, ef) then return true end
      elseif type(ef) == "string" then
        local save = game and game.save
        if save and flagOn(save, ef) then return true end
      end
    end
    local save = game and game.save
    if not save then return false end
    local tables = {}
    if type(save.itemsTaken) == "table" then tables[#tables + 1] = save.itemsTaken end
    if type(save.itemTaken) == "table" then tables[#tables + 1] = save.itemTaken end
    if type(save.takenItems) == "table" then tables[#tables + 1] = save.takenItems end
    if type(save.pickedItems) == "table" then tables[#tables + 1] = save.pickedItems end
    local idx = objectIndex(obj) or obj.index or (def and def.index)
    local name = obj.name or (def and def.name)
    local keys = {}
    if obj.id then keys[#keys + 1] = obj.id end
    if mapId and idx ~= nil then
      keys[#keys + 1] = tostring(mapId) .. "_obj_" .. tostring(idx)
      keys[#keys + 1] = tostring(mapId) .. "_" .. tostring(idx)
      keys[#keys + 1] = tostring(idx)
    end
    if name then
      keys[#keys + 1] = name
      if mapId then keys[#keys + 1] = tostring(mapId) .. "_" .. tostring(name) end
    end
    for _, tab in ipairs(tables) do
      for _, k in ipairs(keys) do
        if tab[k] then return true end
      end
    end
    return false
  end
  local function isObjectHidden(game, obj, mapId)
    if obj.hidden == true or obj.visible == false or obj.removed == true
        or obj.despawned == true then
      return true
    end
    local def = obj.def or obj
    local ef = obj.eventFlag or def.eventFlag or obj.event_flag or def.event_flag
    local isGen2 = getGameVersion(game) == "gold"
    if ef ~= nil and ef ~= 0xFFFF and ef ~= -1 and ef ~= 0 then
      if isGen2 and type(ef) == "number" then
        if gen2EventFlagSet(game, ef) then return true end
      elseif type(ef) == "string" then
        local save = game and game.save
        if save and flagOn(save, ef) then return true end
      end
    end
    local save = game and game.save
    if not save then return false end
    local name = obj.name or (def and def.name)
    if name and mapId and type(save.objectToggles) == "table"
        and type(save.objectToggles[mapId]) == "table"
        and save.objectToggles[mapId][name] == false then
      return true
    end
    local idx = objectIndex(obj)
    if mapId and idx ~= nil and type(save.objectToggles) == "table"
        and type(save.objectToggles[mapId]) == "table" then
      local t = save.objectToggles[mapId]
      if t[idx] == false or t[tostring(idx)] == false then
        return true
      end
    end
    -- Taken item balls always hide (engine removes them)
    local hasItem = (obj.item and obj.item ~= 0 and obj.item ~= "0")
        or (def.item and def.item ~= 0 and def.item ~= "0")
        or isItemBallObject(obj)
    if hasItem and isObjectTaken(game, obj, mapId) then
      return true
    end
    -- Static pokemon gone after battle
    local hasPokemon = obj.pokemon or def.pokemon
    if hasPokemon and type(save.defeatedTrainers) == "table" then
      local key = (mapId and idx ~= nil) and (tostring(mapId) .. "_obj_" .. tostring(idx))
      if (key and save.defeatedTrainers[key]) or (obj.id and save.defeatedTrainers[obj.id]) then
        return true
      end
    end
    return false
  end

  -- Build an uppercase name blob from common identity fields on a screen/frame.
  local function screenNameBlob(obj)
    if type(obj) ~= "table" then return "" end
    local parts = {
      obj.screenId, obj.id, obj.name, obj.type, obj.key, obj.state,
      obj.class, obj.className, obj.scene, obj.mode, obj.kind,
      obj.__name, obj.screen, obj.label, obj.title,
    }
    local mt = getmetatable(obj)
    if type(mt) == "table" and type(mt.__name) == "string" then
      parts[#parts + 1] = mt.__name
    end
    local out = {}
    for _, v in ipairs(parts) do
      if type(v) == "string" and v ~= "" then
        out[#out + 1] = v:upper()
      end
    end
    return table.concat(out, " ")
  end

  -- Keywords that mean "full-screen UI — hide the minimap".
  local BLOCKED_KWS = {
    "BATTLE", "FIGHT", "TRANSITION",
    "INTRO", "TITLE", "TUTORIAL", "NEWGAME", "NEW_GAME",
    "SPEECH", "CUTSCENE", "CINEMATIC", "PROFESSOR",
    "NAMING", "STARTER", "GENDER",
    "MENU", "PAUSE", "BAG", "PARTY", "POKEDEX", "SAVE", "OPTIONS",
    "PC", "MART", "SHOP", "STATE", "SCREEN",
  }

  local function blobMatchesBlocked(blob)
    if blob == "" then return false end
    for _, kw in ipairs(BLOCKED_KWS) do
      if blob:find(kw, 1, true) then return true end
    end
    return false
  end

  local function isDialogFrame(top)
    if type(top) ~= "table" then return false end
    if top.isDialog or top.isTextBox or top.isMessage then return true end
    local b = screenNameBlob(top)
    return b:find("DIALOG", 1, true)
        or b:find("TEXTBOX", 1, true)
        or b:find("MESSAGE", 1, true)
        or b:find("YESNO", 1, true)
        or b:find("CHOICEBOX", 1, true)
  end

  local function isOverworldFrame(game, top)
    if type(top) ~= "table" then return false end
    return top == game.overworld or top == game.world or top.isOverworld == true
  end

  -- True when this stack frame should hide the minimap.
  local function frameBlocksMinimap(game, top)
    if type(top) ~= "table" then return false end
    if isOverworldFrame(game, top) or isDialogFrame(top) then return false end
    if top.isBattle or top.isBattleState or top.isOpaque then return true end
    if top.isIntro or top.isTitle or top.isCutscene then return true end
    return blobMatchesBlocked(screenNameBlob(top))
  end

  local function collectStackFrames(stack)
    local frames = {}
    if not stack then return frames end
    if type(stack.top) == "function" then
      local ok, top = pcall(function() return stack:top() end)
      if ok and top then frames[#frames + 1] = top end
    end
    for _, key in ipairs({ "states", "frames", "items" }) do
      local list = stack[key]
      if type(list) == "table" then
        for _, f in ipairs(list) do frames[#frames + 1] = f end
      end
    end
    for i = 1, 8 do
      if type(stack[i]) == "table" then frames[#frames + 1] = stack[i] end
    end
    return frames
  end

  local HIDDEN_PHASES = {
    boot = true, error = true, title = true, menu = true,
    intro = true, battle = true, naming = true, newgame = true,
  }

  local function shouldDraw(game)
    if not game then return false end

    local phase = tostring(game.phase or ""):lower()
    if HIDDEN_PHASES[phase] then return false end

    if game.battle or game.inBattle or game.isBattle
        or game.battleState or game.battleScene or game.currentBattle then
      return false
    end
    if game.intro or game.inIntro or game.isIntro
        or game.titleScreen or game.inTitle then
      return false
    end

    local world = game.world
    if world and (world.battleActive or world.inBattle or world.battle) then
      return false
    end
    local ow = game.overworld
    if ow and (ow.battleActive or ow.inBattle or ow.battle or ow.isBattle) then
      return false
    end

    for _, frame in ipairs(collectStackFrames(game.stack)) do
      if frameBlocksMinimap(game, frame) then return false end
    end

    if phase == "play" and world and world.map and not world.battle then
      return true
    end
    if ow and ow.map and not (ow.battle or ow.inBattle) then
      return true
    end
    return false
  end


  local mapCanvasCache = {}
  local mapCanvasOrder = {}
  local MAP_CANVAS_CACHE_LIMIT = 8
  local function releaseCanvasEntry(entry)
    if type(entry) ~= "table" or entry.fromOverview then return end
    local c = entry.canvas
    if c and type(c) == "userdata" and type(c.release) == "function" then
      pcall(function() c:release() end)
    end
  end
  local function cacheMapCanvas(cacheKey, built)
    local old = mapCanvasCache[cacheKey]
    if old and old ~= built then
      releaseCanvasEntry(old)
    end
    mapCanvasCache[cacheKey] = built
    mapCanvasOrder[#mapCanvasOrder + 1] = cacheKey
    while #mapCanvasOrder > MAP_CANVAS_CACHE_LIMIT do
      local oldKey = table.remove(mapCanvasOrder, 1)
      if oldKey ~= cacheKey and mapCanvasCache[oldKey] ~= nil then
        releaseCanvasEntry(mapCanvasCache[oldKey])
        mapCanvasCache[oldKey] = nil
      end
    end
  end
  local IMAGE_FIELD_CANDIDATES = { "sheet", "image", "path", "spriteSheet", "atlas", "texture" }
  local BLOCKDEF_FIELD_CANDIDATES = { "blocks", "blockDefs", "metatiles", "blockData" }
  local function looksLikeImagePath(s)
    return type(s) == "string" and (s:match("%.png$") or s:match("%.jpg$") or s:match("%.jpeg$")) ~= nil
  end
  local function findImagePath(record)
    if type(record) ~= "table" then
      return nil
    end
    for _, key in ipairs(IMAGE_FIELD_CANDIDATES) do
      if looksLikeImagePath(record[key]) then
        return record[key]
      end
    end
    for _, v in pairs(record) do
      if looksLikeImagePath(v) then
        return v
      end
    end
    return nil
  end
  local function looksLikeBlockDefTable(t)
    if type(t) ~= "table" then
      return false
    end
    local checked, matched = 0, 0
    for _, def in pairs(t) do
      if type(def) == "table" then
        checked = checked + 1
        local n = 0
        for _, tileId in ipairs(def) do
          if type(tileId) == "number" then
            n = n + 1
          end
        end
        if n >= 8 then
          matched = matched + 1
        end
      end
      if checked >= 5 then
        break
      end
    end
    return checked > 0 and matched == checked
  end
  local function findBlockDefs(record)
    if type(record) ~= "table" then
      return nil
    end
    for _, key in ipairs(BLOCKDEF_FIELD_CANDIDATES) do
      if looksLikeBlockDefTable(record[key]) then
        return record[key]
      end
    end
    for _, v in pairs(record) do
      if looksLikeBlockDefTable(v) then
        return v
      end
    end
    return nil
  end
  local function blockColor(blockId)
    local id = tonumber(blockId) or 0
    if id == 0x14 or id == 0x20 or id == 0x48 or id == 0x49 or id == 0x4A
        or id == 0x4B or id == 0x4C or id == 0x4D or id == 0x4E or id == 0x4F
        or id == 0x50 or id == 0x51 or id == 0x52 or id == 0x53
        or id == 0x43 or id == 0x44 or id == 0x45 or id == 0x46 or id == 0x47 then
      return 0.25, 0.55, 0.92
    end
    if id == 0x0A or id == 0x0B or id == 0x0C or id == 0x0D
        or id == 0x02 or id == 0x03 then
      return 0.32, 0.78, 0.28
    end
    if id == 0x0F or id == 0x10 or id == 0x11 or id == 0x12 or id == 0x3E then
      return 0.12, 0.42, 0.16
    end
    if id == 0x2B or id == 0x2C or id == 0x2D or id == 0x2E
        or id == 0x31 or id == 0x32 or id == 0x33 or id == 0x34
        or id == 0x05 or id == 0x06 then
      return 0.55, 0.42, 0.28
    end
    if id == 0x01 or id == 0x27 or id == 0x28 or id == 0x29 then
      return 0.82, 0.75, 0.48
    end
    if id == 0x07 or id == 0x08 or id == 0x09 or id == 0x15
        or id == 0x16 or id == 0x17 or id == 0x18 or id == 0x19 then
      return 0.55, 0.52, 0.48
    end
    local h = (id * 17) % 7
    if h <= 2 then
      return 0.40, 0.72, 0.30
    elseif h <= 4 then
      return 0.50, 0.42, 0.28
    else
      return 0.62, 0.68, 0.42
    end
  end
  local function blockTint(blockId)
    local r, g, b = blockColor(blockId)
    local mix = 0.35 
    return r + (1 - r) * mix, g + (1 - g) * mix, b + (1 - b) * mix
  end
  local function buildTerrainCanvas(mapId, game)
    local gameVer = getGameVersion(game)
    local mapDef = mod.content and mod.content.maps and mod.content.maps:get(mapId)
    if not mapDef or type(mapDef.width) ~= "number" or type(mapDef.height) ~= "number"
        or type(mapDef.blocks) ~= "table" then
      return nil
    end
    local w, h = mapDef.width, mapDef.height
    if w <= 0 or h <= 0 or w * h > 20000 then
      return nil
    end
    local mapBlocks = mapDef.blocks
    local tsDef = nil
    if mapDef.tileset and mod.content.tilesets then
      tsDef = mod.content.tilesets:get(mapDef.tileset)
    end
    local tilesetNameU = tostring(mapDef.tileset or ""):upper()
    local outdoorTileset = (
      tilesetNameU == "OVERWORLD"
      or tilesetNameU:find("JOHTO", 1, true) or tilesetNameU:find("KANTO", 1, true)
      or tilesetNameU:find("ROUTE", 1, true) or tilesetNameU:find("TOWN", 1, true)
      or tilesetNameU:find("CITY", 1, true) or tilesetNameU:find("PARK", 1, true)
      or tilesetNameU:find("FOREST", 1, true)
      or tilesetNameU:find("OUTDOOR", 1, true)
      or tilesetNameU:find("EXT", 1, true)
    )
    if tilesetNameU:find("HOUSE", 1, true) or tilesetNameU:find("CENTER", 1, true)
        or tilesetNameU:find("MART", 1, true) or tilesetNameU:find("GYM", 1, true)
        or tilesetNameU:find("INTERIOR", 1, true) or tilesetNameU:find("INDOOR", 1, true)
        or tilesetNameU:find("GATE", 1, true) or tilesetNameU:find("CAVE", 1, true) then
      outdoorTileset = false
    end

    local mapColorMode = getOpt(game, "minimap_map_color", "recomp")

    local function resolveGbcPalette()
      local okP, P = pcall(require, "src.render.PaletteFX")
      if not okP or not P then
        return { {255,255,255}, {255,132,132}, {148,58,58}, {0,0,0} }
      end
      local name = nil
      pcall(function()
        local ow = game and game.overworld
        local liveMap = ow and ow.map and ow.map.id == mapId and ow.map or nil
        if liveMap and type(ow.paletteNameFor) == "function" then
          name = ow:paletteNameFor(liveMap)
        end
      end)
      name = name or mapDef.palette or mapDef.paletteName or mapDef.tileset
      local colors = nil
      if type(name) == "string" then
        -- PaletteFX.pal() only returns the real per-map GBC-boost colors
        -- (the ones Yellow actually shows on a Game Boy Color / color
        -- emulator) when mode is "ogred". Flip it just for this lookup,
        -- the same way this file already toggles GbcPalette.mode elsewhere.
        local prevMode = P.mode
        P.mode = "ogred"
        local ok, c = pcall(function() return P.pal(game.data, name) end)
        P.mode = prevMode
        if ok and c then colors = c end
      end
      if colors then return normalizeMarkerPalette(colors) end
      local ok2, bg = pcall(function() return P.ogBg() end)
      if ok2 and bg then return normalizeMarkerPalette(bg) end
      return { {255,255,255}, {255,132,132}, {148,58,58}, {0,0,0} }
    end

    local PaletteFX = nil
    local exactPalette = nil
    if mapColorMode == "recomp" then
      PaletteFX = require("src.render.PaletteFX")
      local okPal, pal = pcall(function()
        local ow = game and game.overworld
        if not ow or type(ow.paletteNameFor) ~= "function" then return nil end
        local liveMap = (ow.map and ow.map.id == mapId) and ow.map or nil
        if not liveMap then return nil end
        local name = ow:paletteNameFor(liveMap)
        if not name then return nil end
        return PaletteFX.pal(game.data, name)
      end)
      if okPal then exactPalette = pal end
    end

    if mapColorMode == "recomp" and not exactPalette then
      pcall(function()
        local name = mapDef.tileset
        if type(name) == "string" then
          exactPalette = PaletteFX.pal(game.data, name)
        end
      end)
    end
    if mapColorMode == "recomp" and not exactPalette then
      pcall(function()
        local name = mapDef.palette or mapDef.paletteName
        if type(name) == "string" then
          exactPalette = PaletteFX.pal(game.data, name)
        end
      end)
    end
    if mapColorMode == "recomp" and not exactPalette then
      pcall(function()
        local ow = game and game.overworld
        if ow and type(ow.paletteNameFor) == "function" then
          local name = ow:paletteNameFor(mapDef)
          if name then exactPalette = PaletteFX.pal(game.data, name) end
        end
      end)
    end

    if mapColorMode == "recomp" and not exactPalette then
      pcall(function()
        local ow = game and game.overworld
        local zones = ow and type(ow.sgbWorldZones) == "function"
                    and ow:sgbWorldZones() or nil
        if zones and zones[1] and zones[1].colors then
          exactPalette = zones[1].colors
        end
      end)
    end

    local function recolorExact(data, colors)
      if not data then return nil end
      if not colors then return nil end
      local iw, ih = data:getWidth(), data:getHeight()
      colors = PaletteFX.effectiveColors(colors) or colors
      local out = love.image.newImageData(iw, ih)
      for y = 0, ih - 1 do
        for x = 0, iw - 1 do
          local r, g, b, a = data:getPixel(x, y)
          if a and a > 0 then
            local lum = r * 0.2126 + g * 0.7152 + b * 0.0722
            local shade = lum > 0.83 and 1
                       or (lum > 0.5 and 2
                       or (lum > 0.17 and 3 or 4))
            local c = colors[shade]
            if c then
              out:setPixel(x, y, c[1] / 255, c[2] / 255, c[3] / 255, a)
            else
              out:setPixel(x, y, r, g, b, a)
            end
          else
            out:setPixel(x, y, r, g, b, a)
          end
        end
      end
      local ok, image = pcall(love.graphics.newImage, out)
      if ok and image then
        pcall(function() image:setFilter("nearest", "nearest") end)
        return image
      end
      return nil
    end

    local function recolorSgb(data, colors)
      colors = normalizeMarkerPalette(colors)
      if not data or not colors then return nil end
      local iw, ih = data:getWidth(), data:getHeight()
      local out = love.image.newImageData(iw, ih)
      for y = 0, ih - 1 do
        for x = 0, iw - 1 do
          local r, g, b, a = data:getPixel(x, y)
          if a and a > 0 then
            local lum = r * 0.2126 + g * 0.7152 + b * 0.0722
            local shade = lum > 0.83 and 1 or (lum > 0.5 and 2 or (lum > 0.17 and 3 or 4))
            local c = colors[shade]
            out:setPixel(x, y, c[1] / 255, c[2] / 255, c[3] / 255, a)
          else
            out:setPixel(x, y, r, g, b, a)
          end
        end
      end
      local ok, image = pcall(love.graphics.newImage, out)
      if ok and image then
        pcall(function() image:setFilter("nearest", "nearest") end)
        return image
      end
      return nil
    end

    local img, blockDefs, tilesPerRow
    local rawTileData = nil
    -- Gen 2 is intentionally built from its block/tile data below.  The live
    -- world image can contain the engine's visual/design points, which must
    -- not be part of the minimap terrain.

    if type(tsDef) == "table" and not img then
      local imgPath = tsDef.image or findImagePath(tsDef)
      if type(imgPath) == "string" then
        if mapColorMode == "og" then
          local okImg, native = pcall(love.graphics.newImage, imgPath)
          if okImg and native then
            pcall(function() native:setFilter("nearest", "nearest") end)
            img = native
          end
        elseif love.image and love.image.newImageData then
          local okData, data = pcall(love.image.newImageData, imgPath)
          if okData and data then
            rawTileData = data
            if mapColorMode == "gbc" then
              img = recolorSgb(data, resolveGbcPalette())
            else
              local mostlyGray = true
              local samples, chroma = 0, 0
              local step = math.max(1, math.floor(math.max(data:getWidth(), data:getHeight()) / 32))
              for y = 0, data:getHeight() - 1, step do
                for x = 0, data:getWidth() - 1, step do
                  local r, g, b, a = data:getPixel(x, y)
                  if a and a > 0.1 then
                    samples = samples + 1
                    chroma = chroma + (math.max(r, g, b) - math.min(r, g, b))
                  end
                end
              end
              mostlyGray = samples < 1 or (chroma / samples) < 0.06
              if mostlyGray and exactPalette then
                img = recolorExact(data, exactPalette)
              elseif mostlyGray and gameVer == "gold" then
                -- Gen2: never fall back to the Gen1/SGB red palette — keep
                -- grayscale for now; real GBC colors come from bgSet below.
                local okImg, native = pcall(love.graphics.newImage, data)
                if okImg and native then
                  pcall(function() native:setFilter("nearest", "nearest") end)
                  img = native
                end
              elseif mostlyGray then
                img = recolorSgb(data, resolveGbcPalette())
              else
                local okImg, native = pcall(love.graphics.newImage, data)
                if okImg and native then
                  pcall(function() native:setFilter("nearest", "nearest") end)
                  img = native
                end
              end
            end
          end
        end
        if not img then
          local okImg, native = pcall(love.graphics.newImage, imgPath)
          if okImg and native then
            pcall(function() native:setFilter("nearest", "nearest") end)
            img = native
          end
        end
      end
    end
    if type(tsDef) == "table" then
      if not blockDefs then
        if type(tsDef.blocks) == "table" then
          blockDefs = tsDef.blocks
        else
          blockDefs = findBlockDefs(tsDef)
        end
      end
      if not tilesPerRow or tilesPerRow <= 0 then
        tilesPerRow = tonumber(tsDef.tilesPerRow)
      end
      if img and (not tilesPerRow or tilesPerRow <= 0) then
        tilesPerRow = math.max(1, math.floor(img:getWidth() / TILE_PX))
      end
    end
    local canUseTiles = img and blockDefs and tilesPerRow and tilesPerRow > 0
    local imgByGroup = nil
    local activeWorldGroups = nil
    if canUseTiles and mapColorMode == "recomp" and PaletteFX then
      local okAdvanced, advanced = pcall(function() return PaletteFX.usesGbcPack() end)
      if okAdvanced and advanced and type(tsDef) == "table"
          and type(mapDef.tileset) == "string"
          and PaletteFX.hasWorldTileset(mapDef.tileset)
          and rawTileData then
        activeWorldGroups = PaletteFX.worldGroupColors(
          game.data, mapDef.tileset, mapId,
          game.overworld and game.overworld.player and game.overworld.player.cellY)
        if activeWorldGroups then
          imgByGroup = {}
          for gi = 1, #activeWorldGroups do
            imgByGroup[gi] = recolorExact(rawTileData, activeWorldGroups[gi])
          end
        end
      end
    end

    local isGold = (gameVer == "gold")
    -- Gen2 recomp: color tiles via the same 8 BG palettes the engine bakes
    -- (Palettes.bgSet + tileset.tilePalettes), matching World:bakeMapImage.
    -- Daytime MUST match the live world (NITE/DARK/MORN), not always DAY.
    local gen2TilePalettes = nil
    local gen2Daytime = nil
    local gen2ClearColor = nil
    if isGold and mapColorMode == "recomp" and canUseTiles and rawTileData
        and type(tsDef) == "table" then
      pcall(function()
        local Palettes = require("src.world.gen2.Palettes")
        local world = game and game.overworld
        local palData = (world and world.palettes)
          or (game and game.data and (game.data.gen2Palettes or game.data.palettes))
        if not palData then return end

        -- Live engine daytime first; otherwise derive from the GAME clock
        -- (Clock.hour / World:hour), never os.date host time alone.
        local daytime = nil
        if world then
          if type(world.daytime) == "string" and world.daytime ~= "" then
            daytime = world.daytime
          elseif type(world.tod) == "string" and world.tod ~= "" then
            daytime = world.tod
          end
          if not daytime and type(world.timeOfDay) == "function" then
            local okT, t = pcall(function()
              if type(world.hour) == "function" then
                local okH, h = pcall(function() return world:hour() end)
                if okH then return world:timeOfDay(h) end
              end
              return world:timeOfDay()
            end)
            if okT and type(t) == "string" and t ~= "" then daytime = t end
          end
        end
        if not daytime then
          local hour = nil
          if world and type(world.hour) == "function" then
            local okH, h = pcall(function() return world:hour() end)
            if okH then hour = h end
          end
          if hour == nil and world and world.clockHour ~= nil then
            hour = world.clockHour
          end
          if hour == nil and game and game.save then
            pcall(function()
              local Clock = require("src.core.gen2.Clock")
              if type(Clock.hour) == "function" then
                hour = Clock.hour(game.save)
              end
            end)
          end
          daytime = Palettes.daytimeFor(mapDef, hour, world and world.flashUsed)
        end
        daytime = daytime or "DAY"
        gen2Daytime = daytime

        -- Prefer the engine's already-baked BG set (exact on-screen colors).
        local bgSet = nil
        if world and type(world.bgSets) == "table" then
          local liveKey = nil
          if type(world.mapCacheKey) == "function" then
            local okK, k = pcall(function() return world:mapCacheKey(mapId) end)
            if okK then liveKey = k end
          end
          if not liveKey then
            liveKey = tostring(mapId) .. "|" .. tostring(daytime)
          end
          local live = world.bgSets[liveKey]
          if type(live) == "table" then bgSet = live end
          -- Fallback: scan keys that start with this mapId
          if not bgSet then
            local prefix = tostring(mapId) .. "|"
            for k, v in pairs(world.bgSets) do
              if type(k) == "string" and k:sub(1, #prefix) == prefix
                  and type(v) == "table" then
                bgSet = v
                break
              end
            end
          end
        end
        if not bgSet then
          bgSet = Palettes.bgSet(palData, mapDef, daytime)
        end
        if not bgSet then return end

        gen2TilePalettes = tsDef.tilePalettes
        imgByGroup = {}
        for slot = 1, 8 do
          if bgSet[slot] then
            imgByGroup[slot] = recolorExact(rawTileData, bgSet[slot])
          end
        end
        for slot = 1, 8 do
          if imgByGroup[slot] then
            img = imgByGroup[slot]
            break
          end
        end
        if bgSet[1] and bgSet[1][1] then
          local c = bgSet[1][1]
          gen2ClearColor = {
            (c[1] or 0) / 255,
            (c[2] or 0) / 255,
            (c[3] or 0) / 255,
          }
        end
      end)
    end
    local BORDER_BLOCKS = 10
    -- Gen1 OVERWORLD tree wall; Gen2 Johto outdoor often uses $05 as border tree
    local TREE_WALL_BLOCK = isGold and 0x05 or 0x0F
    local WATER_BORDER_BLOCK = 0x43
    local function resolveBorderBlock(def)
      if not def then return TREE_WALL_BLOCK end
      if type(def.borderBlock) == "number" then
        return def.borderBlock
      end
      if type(def.border) == "number" then
        return def.border
      end
      local ts = tostring(def.tileset or ""):upper()
      if outdoorTileset or ts == "OVERWORLD" or ts:find("JOHTO", 1, true)
          or ts:find("KANTO", 1, true) or ts:find("PARK", 1, true) then
        return TREE_WALL_BLOCK
      end
      -- Indoor: solid floor/wall block 0 looks wrong; keep black clear
      return 0
    end
    local borderId = resolveBorderBlock(mapDef)

    local function blockColorLocal(blockId)
      if blockId ~= nil and blockColor then
        local ok, r, g, b = pcall(blockColor, blockId)
        if ok and r then return r, g, b end
      end
      local fallback = { red = { 0.22, 0.32, 0.16 }, blue = { 0.16, 0.24, 0.42 },
                         yellow = { 0.40, 0.38, 0.12 }, gold = { 0.18, 0.24, 0.30 } }
      local c = fallback[gameVer] or fallback.red
      return c[1] * 0.7, c[2] * 0.7, c[3] * 0.7
    end

    local voidR, voidG, voidB = blockColorLocal(borderId)
    if outdoorTileset then
      voidR, voidG, voidB = 0.12, 0.18, 0.12
      -- Gen2 outdoor: wash with BG palette color 0 (matches engine)
      if gen2ClearColor then
        voidR, voidG, voidB = gen2ClearColor[1], gen2ClearColor[2], gen2ClearColor[3]
      end
    else
      -- Indoor OOB: always black (gen2ClearColor is often near-white indoors)
      voidR, voidG, voidB = 0, 0, 0
    end

    local cw = w + BORDER_BLOCKS * 2
    local ch = h + BORDER_BLOCKS * 2
    local originBX = BORDER_BLOCKS
    local originBY = BORDER_BLOCKS
    local canvas = love.graphics.newCanvas(cw * BLOCK_PX, ch * BLOCK_PX)
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(voidR, voidG, voidB, 1)

    local sheetW, sheetH = 0, 0
    local quadCache = {}
    local function quadFor(tileId)
      if not img or type(tileId) ~= "number" or not tilesPerRow or tilesPerRow <= 0 then
        return nil
      end
      local q = quadCache[tileId]
      if not q then
        local col = tileId % tilesPerRow
        local row = math.floor(tileId / tilesPerRow)
        local qx, qy = col * TILE_PX, row * TILE_PX
        if sheetW == 0 then
          sheetW, sheetH = img:getWidth(), img:getHeight()
        end
        if qx + TILE_PX <= sheetW and qy + TILE_PX <= sheetH then
          q = love.graphics.newQuad(qx, qy, TILE_PX, TILE_PX, sheetW, sheetH)
          quadCache[tileId] = q
        else
          return nil
        end
      end
      return q
    end

    local function drawBlockAt(blockId, col, row)
      local bx, by = col * BLOCK_PX, row * BLOCK_PX
      if canUseTiles and blockDefs then
        local def = blockDefs[blockId + 1] or blockDefs[blockId]
        if type(def) == "table" then
          love.graphics.setColor(1, 1, 1, 1)
          for ty = 0, 3 do
            for tx = 0, 3 do
              local tileId = def[ty * 4 + tx + 1]
              local q = quadFor(tileId)
              local sheet = img
              if imgByGroup and type(tileId) == "number" then
                if gen2TilePalettes then
                  -- Gen2: tilePalettes is 1-based over sheet tiles (slot 1..8)
                  local slot = gen2TilePalettes[tileId + 1] or 1
                  sheet = imgByGroup[slot] or img
                else
                  local okGroup, group = pcall(function()
                    return PaletteFX.worldGroupAt(mapDef.tileset, mapId, tileId)
                  end)
                  if okGroup and group ~= nil then
                    sheet = imgByGroup[group + 1] or img
                  end
                end
              end
              if q and sheet then
                love.graphics.draw(sheet, q, bx + tx * TILE_PX, by + ty * TILE_PX)
              else
                love.graphics.setColor(0.12, 0.12, 0.12, 1)
                love.graphics.rectangle("fill", bx + tx * TILE_PX,
                  by + ty * TILE_PX, TILE_PX, TILE_PX)
                love.graphics.setColor(1, 1, 1, 1)
              end
            end
          end
          return
        end
      end
      love.graphics.setColor(0.12, 0.12, 0.12, 1)
      love.graphics.rectangle("fill", bx, by, BLOCK_PX, BLOCK_PX)
      love.graphics.setColor(1, 1, 1, 1)
    end

    -- Fill OOB with the map's border block (trees/walls) — Gen1 and Gen2.
    -- Indoor maps with borderId 0 keep the black clear from above.
    if borderId ~= nil and borderId ~= 0 then
      for row = 0, ch - 1 do
        for col = 0, cw - 1 do
          drawBlockAt(borderId, col, row)
        end
      end
    end

    local usedRealTiles = canUseTiles and true or false
    for i = 1, math.min(w * h, #mapBlocks) do
      local blockId = mapBlocks[i]
      if blockId ~= nil then
        local col = (i - 1) % w + originBX
        local row = math.floor((i - 1) / w) + originBY
        drawBlockAt(blockId, col, row)
      end
    end

    -- Gen1 + Gen2: draw neighboring map strips (next route/town on the edge)
    local conns = mapDef.connections
    if type(conns) == "table" and mod.content and mod.content.maps then
      local sides = {
        { key = "north", dx = 0, dy = -1 },
        { key = "south", dx = 0, dy = 1 },
        { key = "west", dx = -1, dy = 0 },
        { key = "east", dx = 1, dy = 0 },
        { key = "up", dx = 0, dy = -1 },
        { key = "down", dx = 0, dy = 1 },
        { key = "left", dx = -1, dy = 0 },
        { key = "right", dx = 1, dy = 0 },
      }
      local drawnSide = {}
      for _, side in ipairs(sides) do
        local c = conns[side.key]
        local destMap = type(c) == "table" and (c.map or c.mapId) or nil
        if type(c) == "table" and destMap and not drawnSide[side.dx .. "," .. side.dy] then
          drawnSide[side.dx .. "," .. side.dy] = true
          local nDef = nil
          local okN, got = pcall(function()
            return mod.content.maps:get(destMap)
          end)
          if okN then nDef = got end
          if not nDef then
            -- Gen2: maps may live on the live World
            pcall(function()
              local world = getGen2World and getGen2World(game) or (game and game.world)
              if world and world.maps and world.maps[destMap] then
                nDef = world.maps[destMap]
              end
            end)
          end
          if type(nDef) == "table" and type(nDef.blocks) == "table"
              and type(nDef.width) == "number" and type(nDef.height) == "number" then
            local nw, nh = nDef.width, nDef.height
            local nBlocks = nDef.blocks
            local offset = tonumber(c.offset) or 0
            local depth = BORDER_BLOCKS
            if side.dy == -1 then
              for row = 0, depth - 1 do
                local nRow = nh - depth + row
                if nRow >= 0 and nRow < nh then
                  for col = 0, nw - 1 do
                    local destCol = originBX + offset + col
                    local destRow = originBY - depth + row
                    if destCol >= 0 and destCol < cw and destRow >= 0 and destRow < ch then
                      local bi = nRow * nw + col + 1
                      local bid = nBlocks[bi]
                      if bid ~= nil then
                        drawBlockAt(bid, destCol, destRow)
                      end
                    end
                  end
                end
              end
            elseif side.dy == 1 then
              for row = 0, depth - 1 do
                local nRow = row
                if nRow < nh then
                  for col = 0, nw - 1 do
                    local destCol = originBX + offset + col
                    local destRow = originBY + h + row
                    if destCol >= 0 and destCol < cw and destRow >= 0 and destRow < ch then
                      local bi = nRow * nw + col + 1
                      local bid = nBlocks[bi]
                      if bid ~= nil then
                        drawBlockAt(bid, destCol, destRow)
                      end
                    end
                  end
                end
              end
            elseif side.dx == -1 then
              for col = 0, depth - 1 do
                local nCol = nw - depth + col
                if nCol >= 0 and nCol < nw then
                  for row = 0, nh - 1 do
                    local destCol = originBX - depth + col
                    local destRow = originBY + offset + row
                    if destCol >= 0 and destCol < cw and destRow >= 0 and destRow < ch then
                      local bi = row * nw + nCol + 1
                      local bid = nBlocks[bi]
                      if bid ~= nil then
                        drawBlockAt(bid, destCol, destRow)
                      end
                    end
                  end
                end
              end
            elseif side.dx == 1 then
              for col = 0, depth - 1 do
                local nCol = col
                if nCol < nw then
                  for row = 0, nh - 1 do
                    local destCol = originBX + w + col
                    local destRow = originBY + offset + row
                    if destCol >= 0 and destCol < cw and destRow >= 0 and destRow < ch then
                      local bi = row * nw + nCol + 1
                      local bid = nBlocks[bi]
                      if bid ~= nil then
                        drawBlockAt(bid, destCol, destRow)
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas(prevCanvas)
    return {
      canvas = canvas,
      width = w,
      height = h,
      usedRealTiles = usedRealTiles,
      originBX = originBX,
      originBY = originBY,
      canvasW = cw,
      canvasH = ch,
    }
  end
  local function tryMapOverviewCanvas(mapId, game)
    if not (mod.world and type(mod.world.mapOverview) == "function") then
      return nil
    end
    local ok, overview = pcall(function()
      return mod.world:mapOverview(mapId)
    end)
    if not ok or type(overview) ~= "table" then
      return nil
    end
    local img = overview.image or overview.canvas or overview.texture
    if img and type(img) == "userdata" then
      local iw, ih = 0, 0
      pcall(function()
        iw, ih = img:getWidth(), img:getHeight()
      end)
      if iw > 0 and ih > 0 then
        local mw = tonumber(overview.width) or tonumber(overview.w)
        local mh = tonumber(overview.height) or tonumber(overview.h)
        if not mw then
          mw = math.max(1, math.floor(iw / CELL_PX))
        end
        if not mh then
          mh = math.max(1, math.floor(ih / CELL_PX))
        end
        return {
          canvas = img,
          width = math.floor(mw / 2),
          height = math.floor(mh / 2),
          usedRealTiles = true,
          originBX = 0,
          originBY = 0,
          canvasW = math.floor(mw / 2),
          canvasH = math.floor(mh / 2),
          pixelWidth = iw,
          pixelHeight = ih,
          fromOverview = true,
        }
      end
    end
    return nil
  end
  -- Resolve the Gen2 palette daytime the overworld is currently drawn with.
  -- Prefer live engine state; never fall back to the host clock alone (that
  -- made the minimap stay on DAY while the in-game RTC was NITE).
  local function resolveGen2Daytime(game, mapDef)
    local world = game and game.overworld
    if world then
      if type(world.daytime) == "string" and world.daytime ~= "" then
        return world.daytime
      end
      if type(world.tod) == "string" and world.tod ~= "" then
        return world.tod
      end
      if type(world.timeOfDay) == "function" then
        local okT, t = pcall(function()
          if type(world.hour) == "function" then
            local okH, h = pcall(function() return world:hour() end)
            if okH then return world:timeOfDay(h) end
          end
          return world:timeOfDay()
        end)
        if okT and type(t) == "string" and t ~= "" then return t end
      end
    end
    local hour = nil
    if world and type(world.hour) == "function" then
      local okH, h = pcall(function() return world:hour() end)
      if okH then hour = h end
    end
    if hour == nil then
      -- Game RTC via Clock (same as World:hour) — not os.date host time
      pcall(function()
        local Clock = require("src.core.gen2.Clock")
        if game and game.save and type(Clock.hour) == "function" then
          hour = Clock.hour(game.save)
        end
      end)
    end
    local okP, Palettes = pcall(require, "src.world.gen2.Palettes")
    if okP and Palettes and type(Palettes.daytimeFor) == "function" then
      return Palettes.daytimeFor(mapDef, hour, world and world.flashUsed) or "DAY"
    end
    return "DAY"
  end

  -- Use the engine's own night-correct map bake when available (exact colors).
  local function tryGoldEngineMapCanvas(mapId, game)
    local world = game and game.overworld
    if not world then return nil end
    local img = nil
    if type(world.imageFor) == "function" then
      local ok, result = pcall(function() return world:imageFor(mapId) end)
      if ok and result then img = result end
    end
    if not img and type(world.mapImages) == "table" then
      local key = nil
      if type(world.mapCacheKey) == "function" then
        local okK, k = pcall(function() return world:mapCacheKey(mapId) end)
        if okK then key = k end
      end
      if key then img = world.mapImages[key] end
      if not img then
        local prefix = tostring(mapId) .. "|"
        for k, v in pairs(world.mapImages) do
          if type(k) == "string" and k:sub(1, #prefix) == prefix and v then
            img = v
            break
          end
        end
      end
    end
    if not img then return nil end
    local iw, ih = 0, 0
    pcall(function() iw, ih = img:getWidth(), img:getHeight() end)
    if iw <= 0 or ih <= 0 then return nil end
    local mapDef = mod.content and mod.content.maps and mod.content.maps:get(mapId)
    local bw = mapDef and tonumber(mapDef.width) or math.max(1, math.floor(iw / BLOCK_PX))
    local bh = mapDef and tonumber(mapDef.height) or math.max(1, math.floor(ih / BLOCK_PX))
    return {
      canvas = img,
      width = bw,
      height = bh,
      usedRealTiles = true,
      originBX = 0,
      originBY = 0,
      canvasW = bw,
      canvasH = bh,
      pixelWidth = iw,
      pixelHeight = ih,
      fromEngineBake = true,
    }
  end

  local function getTerrainCanvas(mapId, game)
    local ver = getGameVersion(game)
    local mapColorMode = getOpt(game, "minimap_map_color", "recomp")
    local goldRendererKey = ""
    if ver == "gold" and mapColorMode == "recomp" then
      local world = game and game.overworld
      local r = world and world.map and world.map.renderer
      local mapDef = mod.content and mod.content.maps and mod.content.maps:get(mapId)
      local daytime = resolveGen2Daytime(game, mapDef)
      goldRendererKey = "#goldRenderer:" .. tostring(r and r.image or "none")
        .. "#tod:" .. tostring(daytime)
    end
    local cacheKey = tostring(mapId) .. "#v:" .. tostring(ver) .. "#mode:" .. tostring(mapColorMode) .. goldRendererKey
    local cached = mapCanvasCache[cacheKey]
    if cached == nil then
      local built = nil
      -- Gen2: use buildTerrainCanvas (not engine single-map bake) so
      -- neighboring map strips and indoor OOB colors work like Gen1.
      if not built and mapColorMode == "recomp" and ver ~= "gold" then
        local ok, overview = pcall(tryMapOverviewCanvas, mapId, game)
        if ok and overview then
          built = overview
        end
      end
      if not built then
        local ok, b = pcall(buildTerrainCanvas, mapId, game)
        built = (ok and b) or false
      end
      cached = built or false
      cacheMapCanvas(cacheKey, cached)
    end
    return cached or nil
  end
  local minimapWarned = false
  local minimapWarnedMaps = {}
  local function drawMinimap(game, mapId, mmX, mmY, cx, cy)
    activeGame = game
    pcall(enrichGiftTextFromGame, game, mapId)
    local gameVer = getGameVersion(game)
    local zoomOpt = getOpt(game, "minimap_zoom", "0")
    local legacy = { near = 8, close = 4, medium = 0, far = -4, wide = -8, small = 4, large = -4 }
    if type(zoomOpt) == "string" and legacy[zoomOpt] ~= nil then
      zoomOpt = tostring(legacy[zoomOpt])
    end
    -- Same radius math for Gen1 and Gen2 (no gen-specific zoom path)
    local radius = radiusForZoom(zoomOpt, ZOOM_BASE_RADIUS)
    local boxPx = minimapBoxPx(game)
    local endColorblind = beginColorblindFilter(game)
    love.graphics.setColor(0.04, 0.04, 0.07, 0.92)
    love.graphics.rectangle("fill", mmX, mmY, boxPx, boxPx, 4, 4)
    local borderPad = 2
    local contentX = mmX + borderPad
    local contentY = mmY + borderPad
    local contentPx = boxPx - borderPad * 2
    local terrain = getTerrainCanvas(mapId, game)
    if terrain then
      local cellsAcross = radius * 2 + 1
      local cellPxOnScreen = contentPx / cellsAcross
      local scale = cellPxOnScreen / CELL_PX
      local originCellsX = (terrain.originBX or 0) * 2
      local originCellsY = (terrain.originBY or 0) * 2
      local playerPxX = (cx + originCellsX + 0.5) * CELL_PX
      local playerPxY = (cy + originCellsY + 0.5) * CELL_PX
      do
        local ver = getGameVersion(game)
        love.graphics.setColor(0.12, 0.16, 0.12, 1)
      end
      love.graphics.rectangle("fill", contentX, contentY, contentPx, contentPx)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.setScissor(contentX, contentY, contentPx, contentPx)
      love.graphics.draw(
        terrain.canvas,
        contentX + contentPx / 2 - playerPxX * scale,
        contentY + contentPx / 2 - playerPxY * scale,
        0, scale, scale
      )
      love.graphics.setScissor()
    else
      do
        local ver = getGameVersion(game)
        love.graphics.setColor(0.12, 0.16, 0.12, 1)
      end
      love.graphics.rectangle("fill", contentX, contentY, contentPx, contentPx)
      love.graphics.setColor(1, 1, 1, 1)
    end
    local cellScale = contentPx / (radius * 2 + 1)
    local centerX = contentX + contentPx / 2
    local centerY = contentY + contentPx / 2
    local markerSize = math.max(10, math.min(22, cellScale * 1.35))
    local markerMode = getOpt(game, "show_markers", "all")
    local showNpc = (markerMode == "npc" or markerMode == "all")
    local showItems = (markerMode == "items" or markerMode == "all")
    love.graphics.setScissor(contentX, contentY, contentPx, contentPx)
    local player = getPlayerEntity(game)
    local objsOk, objs = pcall(getMapObjects, game)
    if not objsOk then
      if not minimapWarned then
        minimapWarned = true
        mod.log:warn("getMapObjects failed: %s", tostring(objs))
      end
      objs = nil
    end
    if objs and markerMode ~= "off" then
      for objIndex, obj in ipairs(objs) do
        local okObj, errObj = pcall(function()
          if obj == player then
            return
          end
          local defIndex = objectIndex(obj) or objIndex
          local kind = objectKind(obj, mapId, defIndex)
          local want = (kind == "item" or kind == "hidden") and showItems
              or (kind == "gift_npc" and (showItems or showNpc))
              or ((kind == "npc" or kind == "trainer" or kind == "object") and showNpc)
          if not want then return end
          if isObjectHidden(game, obj, mapId) then return end
          if kind == "item" and isObjectTaken(game, obj, mapId)
              and not objectIsBerryTree(obj) then
            return
          end
          -- Empty berry/fruit tree: drop only the green item marker, keep the
          -- tree sprite on the minimap (same idea as completed gift NPCs).
          if kind == "item" and objectIsBerryTree(obj)
              and not berryTreeHasBerry(game, obj, mapId) then
            kind = "npc"
          end
          -- Completed gift/trade: drop blue marker, keep NPC sprite.
          if kind == "gift_npc" and isGiftAlreadyTaken(game, obj, mapId, defIndex) then
            kind = "npc"
          end
          local ox, oy = objectXY(obj)
          if not ox or not oy then return end
          if math.abs(ox - cx) > radius or math.abs(oy - cy) > radius then return end
          local px = centerX + (ox - cx) * cellScale
          local py = centerY + (oy - cy) * cellScale
          local facing = objectFacing(obj)
          local spr = nil
          local sid = objectSpriteId(obj)
          if sid then
            local mode = markerMapColorMode(game)
            local palette, tag = nil, nil
            if mode == "gbc" then
              palette = nil
              tag = "gbc_native"
            elseif mode == "recomp" then
              palette = resolveRecompMarkerPalette(game, obj, mapId)
              tag = palette and "recomp" or nil
            end
            if mode == "og" then
              spr = loadSpriteFrame(sid, facing, OG_MARKER_PALETTE, "og", true)
            elseif palette then
              spr = loadSpriteFrame(sid, facing, palette, tag)
            end
            if not spr and mode ~= "og" then
              spr = spriteFromEntity(obj, facing)
            end
          end
          if not spr and mode ~= "og" then
            spr = spriteFromEntity(obj, facing)
          end
          if not spr and gameVer == "gold" and mode ~= "og"
              and type(obj.spriteDef) == "table" and obj.spriteDef.image then
            local temp = {
              sprite = {
                image = obj.spriteDef.image,
                frameWidth = obj.spriteDef.frameWidth or 16,
                frameHeight = obj.spriteDef.frameHeight or 16,
                frames = obj.spriteDef.frames or obj.spriteDef.directionFrames,
                directionFrames = obj.spriteDef.directionFrames,
                getFrameGeometry = obj.spriteDef.getFrameGeometry,
              }
            }
            spr = spriteFromEntity(temp, facing)
          end
          if kind == "item" or kind == "hidden" then
            local mode = markerMapColorMode(game)
            local itemSpriteId = sid or "SPRITE_POKE_BALL"
            local itemSpr = nil
            if mode == "og" then
              itemSpr = loadSpriteFrame(itemSpriteId, "down", OG_MARKER_PALETTE, "item_og", true)
            elseif mode == "gbc" then
              local ip = nil
              itemSpr = loadSpriteFrame(itemSpriteId, "down", ip, "item_gbc_native")
            elseif mode == "recomp" then
              local ip
              if getGameVersion(game) == "gold" then
                ip = resolveGoldRecompMarkerPalette(game, obj)
              else
                ip = resolveRecompMarkerPalette(game, obj, mapId)
              end
              ip = ip or ITEM_PALETTE
              itemSpr = loadSpriteFrame(itemSpriteId, "down", ip, "item_recomp")
            end

            if not itemSpr then
              local fp = nil
              local ftag = "ball"
              if mode == "gbc" then
                fp = resolveGbcMarkerPalette(game, mapId) or ITEM_PALETTE
                ftag = "ball_gbc"
              elseif mode == "recomp" then
                fp = (getGameVersion(game) == "gold" and resolveGoldRecompMarkerPalette(game, obj))
                  or resolveRecompMarkerPalette(game, obj, mapId)
                  or ITEM_PALETTE
                ftag = "ball_recomp"
              end
              itemSpr = getPokeballSprite(fp, ftag)
            end
            if itemSpr then spr = itemSpr end
          end
          local defeatedTrainer = (kind == "trainer") and isTrainerDefeated(game, obj, mapId)
          local drawn = false
          -- Color markers: GREEN items, BLUE gift/trade/pokemon, RED trainers
          if kind == "hidden" or kind == "item" then
            drawGlow(px, py, markerSize * 0.45, 0.20, 0.95, 0.30)
          elseif kind == "gift_npc" or kind == "object" then
            drawGlow(px, py, markerSize * 0.55, 0.15, 0.55, 1.0)
          elseif kind == "trainer" and not defeatedTrainer then
            drawGlow(px, py, markerSize * 0.55, 1.0, 0.15, 0.15)
          end
          if spr then
            local tint = nil
            if kind == "gift_npc" or kind == "object" then
              tint = { 0.45, 0.75, 1.0, 1 }
            elseif kind == "trainer" then
              tint = { 1.0, 0.40, 0.35, 1 }
            elseif kind == "item" or kind == "hidden" then
              tint = { 0.45, 1.0, 0.45, 1 }
            end
            drawn = drawSpriteMarker(spr, px, py, markerSize, facing, tint)
          end
          if not drawn then
            if kind == "trainer" and not defeatedTrainer then
              love.graphics.setColor(1.0, 0.15, 0.15, 1)
              love.graphics.circle("fill", px, py, 4.0)
            elseif kind == "trainer" and defeatedTrainer then
              love.graphics.setColor(0.80, 0.80, 0.85, 1)
              love.graphics.circle("fill", px, py, 3)
            elseif kind == "gift_npc" then
              love.graphics.setColor(0.15, 0.9, 1, 1)
              love.graphics.circle("fill", px, py, 3.5)
              love.graphics.setColor(1, 1, 1, 1)
              love.graphics.circle("line", px, py, 3.5)
            elseif kind == "hidden" or kind == "item" then
              drawPokeballIcon(px, py, 4.5, markerMapColorMode(game), game, mapId, obj)
            elseif kind == "object" then
              love.graphics.setColor(0.35, 0.65, 1.0, 1)
              love.graphics.rectangle("fill", px - 3, py - 3, 6, 6)
            else
              -- normal NPC: neutral (no blue)
              love.graphics.setColor(0.95, 0.85, 0.55, 1)
              love.graphics.circle("fill", px, py, 3)
            end
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.setLineWidth(1.2)
            if not (kind == "hidden" or kind == "item") then
              love.graphics.circle("line", px, py, 3.5)
            end
          end
          if kind == "gift_npc" then
            love.graphics.setColor(0.15, 0.95, 1, 1)
            love.graphics.circle("fill", px + markerSize * 0.30, py - markerSize * 0.30, 2.6)
            love.graphics.setColor(0, 0, 0, 0.85)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", px + markerSize * 0.30, py - markerSize * 0.30, 2.6)
          elseif kind == "trainer" and not defeatedTrainer then
            local bx, by = px + markerSize * 0.32, py - markerSize * 0.32
            love.graphics.setColor(1.0, 0.12, 0.10, 1)
            love.graphics.circle("fill", bx, by, 3.4)
            love.graphics.setColor(0, 0, 0, 0.9)
            love.graphics.setLineWidth(1.2)
            love.graphics.circle("line", bx, by, 3.4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(1.5)
            love.graphics.line(bx, by - 1.6, bx, by + 0.35)
            love.graphics.points(bx, by + 1.55)
          end
        end)
        if not okObj and not minimapWarnedMaps[mapId] then
          minimapWarnedMaps[mapId] = true
          mod.log:warn("marker draw failed on map '%s': %s", tostring(mapId), tostring(errObj))
        end
      end
    end
    if showItems and markerMode ~= "off" then
      local hiddenMode = markerMapColorMode(game)
      local ball = nil
      if hiddenMode == "og" then
        ball = loadSpriteFrame("SPRITE_POKE_BALL", "down", OG_MARKER_PALETTE, "hidden_og", true)
      elseif hiddenMode == "gbc" then
        local bp = nil
        ball = loadSpriteFrame("SPRITE_POKE_BALL", "down", bp, "hidden_gbc_native")
      elseif hiddenMode == "recomp" then
        local bp
        if getGameVersion(game) == "gold" then
          bp = resolveGoldRecompMarkerPalette(game, nil)
        else
          bp = resolveRecompMarkerPalette(game, nil, mapId)
        end
        bp = bp or ITEM_PALETTE
        ball = loadSpriteFrame("SPRITE_POKE_BALL", "down", bp, "hidden_recomp")
      end
      if not ball then
        local bp = (hiddenMode == "gbc" or hiddenMode == "recomp") and ITEM_PALETTE or nil
        ball = getPokeballSprite(bp, "hidden_fallback")
      end
      for _, hi in ipairs(getHiddenItems(game, mapId)) do
        if not isHiddenTaken(game, mapId, hi.x, hi.y) then
          if math.abs(hi.x - cx) <= radius and math.abs(hi.y - cy) <= radius then
            local px = centerX + (hi.x - cx) * cellScale
            local py = centerY + (hi.y - cy) * cellScale
            drawGlow(px, py, markerSize * 0.4, 0.30, 0.90, 0.35)
            local drawn = ball and drawSpriteMarker(ball, px, py, markerSize * 0.95, "down")
            if not drawn then
              drawPokeballIcon(px, py, 4.5, hiddenMode, game, mapId, nil)
            end
          end
        end
      end
    end
    do
      local faceStr = "down"
      local okFace, nesw = pcall(getFacing, game)
      if okFace then
        if nesw == "N" then faceStr = "up"
        elseif nesw == "S" then faceStr = "down"
        elseif nesw == "W" then faceStr = "left"
        elseif nesw == "E" then faceStr = "right"
        end
      end
      local playerSpr = nil
      pcall(function()
        local mode = markerMapColorMode(game)
        if player then
          local sid = objectSpriteId(player)
          if mode == "og" then
            if sid then playerSpr = loadSpriteFrame(sid, faceStr, OG_MARKER_PALETTE, "player_og", true) end
          elseif mode == "gbc" then
            if sid then playerSpr = loadSpriteFrame(sid, faceStr, nil, "player_gbc_native") end
            if not playerSpr and getGameVersion(game) == "gold" then
              for _, id in ipairs({
                "SPRITE_CHRIS", "SPRITE_PLAYER", "SPRITE_GOLD",
              }) do
                playerSpr = loadSpriteFrame(id, faceStr, nil, "gold_player_gbc")
                if playerSpr then break end
              end
            end
          elseif mode == "recomp" then
            if getGameVersion(game) == "gold" then
              playerSpr = spriteFromEntity(player, faceStr)
            else
              local pp = resolveRecompMarkerPalette(game, player, mapId)
              if sid and pp then playerSpr = loadSpriteFrame(sid, faceStr, pp, "player_recomp") end
            end
          end
        end
        if not playerSpr and mode == "og" then
          for _, id in ipairs({
            "SPRITE_RED", "SPRITE_GOLD", "SPRITE_YELLOW", "SPRITE_BOY",
            "SPRITE_RED_BIKE", "SPRITE_PLAYER",
          }) do
            playerSpr = loadSpriteFrame(id, faceStr, OG_MARKER_PALETTE, "player_og", true)
            if playerSpr then break end
          end
        end
        if not playerSpr and mode ~= "og" then
          playerSpr = spriteFromEntity(player, faceStr)
        end
      end)
      local drawn = false
      if playerSpr then
        local okD = pcall(drawSpriteMarker, playerSpr, centerX, centerY, markerSize * 1.15, faceStr)
        drawn = okD and true
      end
      if not drawn then
        local markerColorMode = markerMapColorMode(game)
        if markerColorMode == "og" then
          love.graphics.setColor(0.35, 0.35, 0.35, 1)
        elseif markerColorMode == "gbc" then
          love.graphics.setColor(0.35, 0.70, 0.35, 1)
        else
          love.graphics.setColor(0.25, 0.95, 0.35, 1)
        end
        love.graphics.circle("fill", centerX, centerY, 4.5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", centerX, centerY, 4.5)
      end
    end
    love.graphics.setScissor()
    endColorblind()
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", mmX + 0.5, mmY + 0.5, boxPx - 1, boxPx - 1, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", mmX + 1.5, mmY + 1.5, boxPx - 3, boxPx - 3, 3, 3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
  end
  -- LoadLocation.lua is a sibling module, not an engine require(). The
  -- Recomp mod loader does not put the mod directory on package.path, so a
  -- normal require("LoadLocation") will silently fail to find a local file.
  -- Load it through the mod filesystem after Minimap has installed its HUD
  -- geometry export. Supports both `return function(mod) ... end` modules and
  -- modules that execute directly when called with mod.
  do
    if not mod._minimapLoadLocationLoaded then
      mod._minimapLoadLocationLoaded = true
      local okRead, source = pcall(function()
        return mod:read("LoadLocation.lua")
      end)
      if okRead and type(source) == "string" and source ~= "" then
        local chunk, compileErr = load(source, "@" .. tostring(mod.path or "mod") .. "/LoadLocation.lua")
        if not chunk then
          mod.log:error("LoadLocation.lua compile failed: %s", tostring(compileErr))
        else
          local okRun, result = pcall(chunk, mod)
          if not okRun then
            mod.log:error("LoadLocation.lua load failed: %s", tostring(result))
          elseif type(result) == "function" then
            local okEntry, entryErr = pcall(result, mod)
            if not okEntry then
              mod.log:error("LoadLocation.lua entry failed: %s", tostring(entryErr))
            else
              mod.log:info("LoadLocation.lua loaded")
            end
          else
            mod.log:info("LoadLocation.lua loaded")
          end
        end
      else
        mod.log:warn("LoadLocation.lua not found in the Minimap mod folder")
      end
    end
  end

  mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
    if nextFn then
      nextFn(game, viewport)
    end
    -- Publish "nothing drawn yet" so LoadLocation.lua (which must be
    -- required AFTER this file, see main.lua) can decide whether to
    -- stack its info box under/around the minimap this frame.
    mod._playerPosHud_minimapGeom = nil
    if not shouldDraw(game) then
      return
    end
    local mapId, cx, cy = getLocation(game)
    if not mapId then
      return
    end
    local rawMap = getOpt(game, "minimap", "top_left")
    local mapPos = normalizeMinimapPos(rawMap)
    if mapPos == nil then
      mapPos = "top_left"
    end
    if rawMap == "off" then
      mapPos = "off"
    end
    local wantMap = mapPos ~= "off"
    if not wantMap then
      return
    end
    local margin = 6
    local ww, wh = love.graphics.getDimensions()
    local boxPx = minimapBoxPx(game)
    local function cornerXY(corner, w, h)
      if corner == "top_left" then
        return margin, margin
      elseif corner == "top_right" then
        return ww - w - margin, margin
      elseif corner == "bottom_left" then
        return margin, wh - h - margin
      elseif corner == "bottom_right" then
        return ww - w - margin, wh - h - margin
      end
      return ww - w - margin, margin
    end
    local mmX, mmY = cornerXY(mapPos, boxPx, boxPx)
    -- Let LoadLocation.lua know where the minimap landed this frame so it
    -- can stack its info box under/beside it when both share a corner.
    mod._playerPosHud_minimapGeom = { pos = mapPos, size = boxPx, margin = margin }
    local ok, err = pcall(drawMinimap, game, mapId, mmX, mmY, cx, cy)
    if not ok and not minimapWarned then
      minimapWarned = true
      mod.log:warn("minimap draw failed: %s", tostring(err))
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setScissor()
  end)

end
