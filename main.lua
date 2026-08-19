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
    {
      key = "minimap",
      label = "MINIMAP",
      type = "choice",
      default = "top_left",
      choices = {
        { "OFF", "off" },
        { "TL", "top_left" },
        { "TR", "top_right" },
        { "BL", "bottom_left" },
        { "BR", "bottom_right" },
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
  local MINIMAP_MODES = {
    { "off", "OFF" },
    { "top_left", "TL" },
    { "top_right", "TR" },
    { "bottom_left", "BL" },
    { "bottom_right", "BR" },
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
  local MINIMAP_BOX = 224
  local ZOOM_BASE_RADIUS = 12
  local ZOOM_STEP = 1.2
  local function radiusForZoom(z, baseRadius)
    z = tonumber(z) or 0
    if z > 10 then z = 10 end
    if z < -10 then z = -10 end
    local base = tonumber(baseRadius) or ZOOM_BASE_RADIUS
    local r = base - z * ZOOM_STEP
    if r < 3 then r = 3 end
    if r > 40 then r = 40 end
    return r
  end
  local BLOCK_PX = 32
  local TILE_PX = 8
  local CELL_PX = 16

  -- Gen2 time-of-day (MORN / DAY / NITE). Also works if Gen1 exposes world.tod.
  local currentTod = "DAY"
  local function normalizeTod(v)
    if v == nil then return nil end
    if type(v) == "number" then
      -- common engine encodings: 0=morn, 1=day, 2=nite
      if v == 0 then return "MORN" end
      if v == 1 then return "DAY" end
      if v == 2 or v == 3 then return "NITE" end
      return "DAY"
    end
    local s = tostring(v):upper()
    if s == "MORN" or s == "MORNING" or s == "DAWN" then return "MORN" end
    if s == "DAY" or s == "MIDDAY" or s == "NOON" or s == "AFTERNOON" then return "DAY" end
    if s == "NITE" or s == "NIGHT" or s == "EVENING" or s == "EVE" or s == "DARK" then
      return "NITE"
    end
    return nil
  end
  local function readTodFromSave(game)
    local save = game and game.save
    if not save then return nil end
    for _, key in ipairs({ "timeOfDay", "tod", "daytime", "time_of_day" }) do
      local n = normalizeTod(save[key])
      if n then return n end
    end
    local clock = save.clock or save.time or save.rtc
    if type(clock) == "table" then
      local n = normalizeTod(clock.tod or clock.timeOfDay or clock.period)
      if n then return n end
      local h = tonumber(clock.hour or clock.h or clock.hours)
      if h then
        -- Gen2 defaults: morn 4-9, day 10-17, nite 18-3
        if h >= 4 and h <= 9 then return "MORN" end
        if h >= 10 and h <= 17 then return "DAY" end
        return "NITE"
      end
    end
    return nil
  end
  local function getTimeOfDay(game)
    -- live world API first
    if mod.world and type(mod.world.timeOfDay) == "function" then
      local ok, v = pcall(function() return mod.world:timeOfDay() end)
      local n = ok and normalizeTod(v)
      if n then currentTod = n; return n end
    end
    if mod.world and type(mod.world.tod) == "function" then
      local ok, v = pcall(function() return mod.world:tod() end)
      local n = ok and normalizeTod(v)
      if n then currentTod = n; return n end
    end
    local ow = game and (game.overworld or game.world)
    if type(ow) == "table" then
      local n = normalizeTod(ow.tod or ow.timeOfDay or ow.daytime)
      if n then currentTod = n; return n end
    end
    local n = readTodFromSave(game)
    if n then currentTod = n; return n end
    return currentTod or "DAY"
  end
  -- Multipliers applied to base tileset palette (RGB 0..1)
  local TOD_TINT = {
    MORN = { 1.05, 0.92, 0.78 },  -- warm sunrise
    DAY  = { 1.00, 1.00, 0.96 },  -- bright midday
    NITE = { 0.45, 0.52, 0.85 },  -- cool night
  }
  local function applyTodTint(r, g, b, tod)
    local t = TOD_TINT[tod or "DAY"] or TOD_TINT.DAY
    r = math.min(1, math.max(0, r * t[1]))
    g = math.min(1, math.max(0, g * t[2]))
    b = math.min(1, math.max(0, b * t[3]))
    return r, g, b
  end

  -- Exclusive color identity per cartridge version
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
    -- heuristic: gen2 clock / johto maps imply gold
    if save and (save.clock or save.timeOfDay or save.tod) then
      return "gold"
    end
    return "red"
  end

  -- Outdoor 4-shade bases, exclusive per version (then TOD multiplies on Gold)
  -- Natural terrain 4-shade (shared R/B/Y). Gold uses GOLD_TOD_OUTDOOR.
  local NATURAL_OUTDOOR = {
    { 0.92, 0.95, 0.92 },
    { 0.45, 0.92, 0.35 },
    { 0.92, 0.28, 0.28 },
    { 0.08, 0.18, 0.10 },
  }
  local VERSION_OUTDOOR = {
    red = NATURAL_OUTDOOR,
    blue = NATURAL_OUTDOOR,
    yellow = NATURAL_OUTDOOR,
    gold = NATURAL_OUTDOOR,
  }
  local GOLD_TOD_OUTDOOR = {
    MORN = {
      { 0.99, 0.94, 0.78 },
      { 0.55, 0.78, 0.32 },
      { 0.35, 0.48, 0.22 },
      { 0.12, 0.10, 0.08 },
    },
    DAY = {
      { 0.97, 0.97, 0.90 },
      { 0.40, 0.78, 0.42 },
      { 0.20, 0.48, 0.36 },
      { 0.08, 0.10, 0.10 },
    },
    NITE = {
      { 0.55, 0.58, 0.78 },
      { 0.22, 0.32, 0.58 },
      { 0.12, 0.16, 0.35 },
      { 0.04, 0.05, 0.10 },
    },
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
  local OPTION_ROWS = {
    { id = "player_pos_hud_show_info", label = "SHOW INFO", key = "show_info", list = INFO_MODES, fallback = "both" },
    { id = "player_pos_hud_position", label = "HUD POS", key = "hud_position", list = POS_MODES, fallback = "top_right" },
    { id = "player_pos_hud_minimap", label = "MINIMAP", key = "minimap", list = MINIMAP_MODES, fallback = "top_left" },
    { id = "player_pos_hud_minimap_zoom", label = "MAP ZOOM", key = "minimap_zoom", list = MINIMAP_ZOOMS, fallback = "0" },
    { id = "player_pos_hud_markers", label = "MARKERS", key = "show_markers", list = MARKER_MODES, fallback = "all" },
  }
  mod.hooks:wrap("ui.options.rows", function(nextFn, game, rows)
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
  local npcDiagLogged = {}
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
          or npc.active == false or npc.despawned == true then
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
          else
            add({
              def = o,
              cellX = o.x,
              cellY = o.y,
              index = o.index,
              id = o.name,
              sprite = o.sprite,
              item = o.item,
              text = o.text,
              trainerClass = o.trainerClass,
              trainerParty = o.trainerParty,
              movement = o.movement,
              range = o.range,
            })
          end
        end
      end
    end
    local mapId = ow and ow.map and (ow.map.id or ow.map.mapId)
    if mapId and not npcDiagLogged[mapId] then
      npcDiagLogged[mapId] = true
      local sample = ""
      for i = 1, math.min(3, #list) do
        local o = list[i]
        sample = sample .. string.format(
          " [%d cell=%s,%s spr=%s]",
          i,
          tostring(o.cellX),
          tostring(o.cellY),
          tostring(objectSpriteId(o))
        )
      end
      mod.log:info(
        "npc-diag %s: count=%d ow=%s npcs_type=%s npcs_len=%s%s",
        tostring(mapId),
        #list,
        tostring(ow ~= nil),
        tostring(ow and type(ow.npcs)),
        tostring(ow and ow.npcs and #ow.npcs),
        sample
      )
    end
    return list
  end
  local function objectXY(obj)
    if type(obj) ~= "table" then return nil, nil end
    local ox = tonumber(obj.cellX)
    local oy = tonumber(obj.cellY)
    if ox and oy then
      return math.floor(ox), math.floor(oy)
    end
    if type(obj.def) == "table" then
      ox = tonumber(obj.def.x)
      oy = tonumber(obj.def.y)
      if ox and oy then
        return math.floor(ox), math.floor(oy)
      end
    end
    return nil, nil
  end
  local function objectIsTrainer(obj)
    if not obj then return false end
    -- Strict: only real battle trainers. Walking NPCs often have movement
    -- range ("ANY_DIR"/numbers) and must NOT be marked as enemies.
    local def = type(obj.def) == "table" and obj.def or nil
    local function hasTrainerData(t)
      if type(t) ~= "table" then return false end
      if t.trainerClass ~= nil and t.trainerClass ~= 0 and t.trainerClass ~= "" then
        return true
      end
      if t.trainerParty ~= nil then return true end
      if t.party ~= nil and type(t.party) == "table" and #t.party > 0 then
        return true
      end
      if t.isTrainer == true or t.canBattle == true or t.wantsBattle == true then
        return true
      end
      if t.trainer == true then return true end
      -- engine sometimes stores trainer id / class under these keys
      if t.trainerId ~= nil or t.trainer_id ~= nil then return true end
      if t.class ~= nil and t.party ~= nil then return true end
      return false
    end
    if hasTrainerData(obj) then return true end
    if hasTrainerData(def) then return true end
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
    local t = obj.text or obj.textId or obj.talk
    if type(t) == "string" and t ~= "" then
      return t
    end
    if type(obj.def) == "table" then
      t = obj.def.text or obj.def.textId or obj.def.talk
      if type(t) == "string" and t ~= "" then
        return t
      end
    end
    return nil
  end
  local giftTextCache = {}
  local GIFT_VERBS = {
    give_item = true,
    give_key_item = true,
    give_pokemon = true,
    give_tm = true,
    give_hm = true,
    trade = true,
    trade_pokemon = true,
    give_badge = true,
  }
  local GIFT_EVENT_DEFS = {
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
  local GIFT_BY_MAP = {}
  for _, def in ipairs(GIFT_EVENT_DEFS) do
    for _, m in ipairs(def.maps) do
      local key = tostring(m):upper():gsub("%s+", "_")
      GIFT_BY_MAP[key] = GIFT_BY_MAP[key] or {}
      GIFT_BY_MAP[key][#GIFT_BY_MAP[key] + 1] = def
    end
  end
  local KNOWN_GIFTS = {}
  for _, def in ipairs(GIFT_EVENT_DEFS) do
    for _, m in ipairs(def.maps) do
      local key = tostring(m):upper():gsub("%s+", "_")
      KNOWN_GIFTS[key] = KNOWN_GIFTS[key] or { texts = {}, events = {} }
      local g = KNOWN_GIFTS[key]
      g.events[#g.events + 1] = def.event
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
  local giftDiagLogged = {}
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
            if (v == "trade" or v == "trade_pokemon") then
              for i = 2, 4 do
                if type(row[i]) == "string" and row[i]:upper():find("EVENT", 1, true) then
                  rememberEvent(row[i])
                elseif type(row[i]) == "string" and row[i]:upper():find("GOT_", 1, true) then
                  rememberEvent(row[i])
                end
              end
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
    if not save or type(name) ~= "string" or name == "" then return false end
    local function truthy(v)
      return v == true or v == 1 or v == "1"
    end
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
  local giftMapKey, giftEventsForObject
  local function isGiftAlreadyTaken(game, obj, mapId)
    local save = game and game.save
    if not save then return false end
    local events = giftEventsForObject(obj, mapId)
    for _, ev in ipairs(events) do
      if flagOn(save, ev) then return true end
    end
    local textId = objectTextId(obj)
    local info = giftInfoForText(mapId, textId)
    if info then
      if info.event and flagOn(save, info.event) then return true end
      if type(info.events) == "table" then
        for _, ev in ipairs(info.events) do
          if flagOn(save, ev) then return true end
        end
      end
    end
    local def = obj.def or obj
    if def.giftTaken or obj.giftTaken or obj.itemGiven then
      return true
    end
    return false
  end
  giftMapKey = function(mapId)
    if not mapId then return nil end
    return tostring(mapId):upper():gsub("%s+", "_")
  end
  local function objectIsItemGiver(obj, mapId)
    if not obj or objectIsTrainer(obj) then
      return false
    end
    local spr = objectSpriteId(obj)
    local isBall = type(spr) == "string" and (
      spr:upper():find("BALL", 1, true)
      or spr:upper():find("FOSSIL", 1, true)
    )
    if isBall or obj.isHiddenItem or obj.kindHint == "item" or obj.kindHint == "hidden" then
      return false
    end
    local def = obj.def or obj
    if def.gift == true or def.giveItem == true or def.giftItem == true then
      return true, "flag"
    end
    local textId = objectTextId(obj)
    local tu = type(textId) == "string" and textId:upper() or ""
    local idx = objectIndex(obj)
    local defs = GIFT_BY_MAP[giftMapKey(mapId)]
    if defs then
      for _, gdef in ipairs(defs) do
        if type(gdef.indices) == "table" and idx ~= nil then
          for _, gi in ipairs(gdef.indices) do
            if idx == gi or tonumber(idx) == tonumber(gi) then
              return true, "idx:" .. tostring(gdef.event)
            end
          end
        end
        if tu ~= "" and type(gdef.hints) == "table" then
          for _, hint in ipairs(gdef.hints) do
            if tu:find(hint, 1, true) then
              return true, "defhint:" .. hint
            end
          end
        end
      end
    end
    if textId and giftInfoForText(mapId, textId) then
      return true, "text-exact"
    end
    local script = obj.script or obj.talkScript
        or (obj.def and (obj.def.script or obj.def.talkScript))
    if type(script) == "table" and isCommandRowList(script) then
      local ok = scriptRowsGiveGift(script)
      if ok then return true, "live-script" end
    end
    if tu ~= "" then
      for _, pat in ipairs(KNOWN_GIFT_TEXT_PATTERNS) do
        if #pat >= 4 and tu:find(pat, 1, true) then
          return true, "hint:" .. pat
        end
      end
    end
    return false
  end
  giftEventsForObject = function(obj, mapId)
    local out = {}
    local seen = {}
    local function add(ev)
      if type(ev) == "string" and ev ~= "" and not seen[ev] then
        seen[ev] = true
        out[#out + 1] = ev
      end
    end
    local textId = objectTextId(obj)
    local tu = type(textId) == "string" and textId:upper() or ""
    local idx = objectIndex(obj)
    local defs = GIFT_BY_MAP[giftMapKey(mapId)]
    if defs then
      for _, gdef in ipairs(defs) do
        local match = false
        if type(gdef.indices) == "table" and idx ~= nil then
          for _, gi in ipairs(gdef.indices) do
            if idx == gi or tonumber(idx) == tonumber(gi) then
              match = true
              break
            end
          end
        end
        if not match and tu ~= "" and type(gdef.hints) == "table" then
          for _, hint in ipairs(gdef.hints) do
            if tu:find(hint, 1, true) then match = true break end
          end
        end
        if match then
          add(gdef.event)
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
  local function logGiftDiagOnce(game, mapId)
    if not mapId or giftDiagLogged[mapId] then return end
    giftDiagLogged[mapId] = true
    local parts = {}
    for _, obj in ipairs(getMapObjects(game)) do
      if not objectIsTrainer(obj) then
        local spr = objectSpriteId(obj)
        local isBall = type(spr) == "string" and spr:upper():find("BALL", 1, true)
        if not isBall and not obj.isHiddenItem then
          local evs = giftEventsForObject(obj, mapId)
          parts[#parts + 1] = string.format(
            "{idx=%s text=%s spr=%s gift=%s ev=%s}",
            tostring(objectIndex(obj)),
            tostring(objectTextId(obj)),
            tostring(spr),
            tostring(objectIsItemGiver(obj, mapId)),
            table.concat(evs, ",")
          )
        end
      end
    end
    local flagParts = {}
    local defs = GIFT_BY_MAP[giftMapKey(mapId)]
    local save = game and game.save
    if defs and save then
      for _, gdef in ipairs(defs) do
        flagParts[#flagParts + 1] = string.format("%s=%s", gdef.event, tostring(flagOn(save, gdef.event)))
      end
    end
    mod.log:info("gift-diag %s: %s | flags: %s", tostring(mapId), table.concat(parts, " | "), table.concat(flagParts, " "))
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
  local function objectKind(obj, mapId)
    if obj.isHiddenItem or obj.kindHint == "hidden" then return "hidden" end
    if objectIsTrainer(obj) then return "trainer" end
    -- fallback: live entities sometimes only expose battle flags on the instance
    if obj.canBattle == true or obj.wantsBattle == true or obj.trainer == true then
      return "trainer"
    end
    local isGiver, reason = objectIsItemGiver(obj, mapId)
    if isGiver then
      lastGiftReason = reason
      return "gift_npc"
    end
    if isItemBallObject(obj) then return "item" end
    local spr = objectSpriteId(obj)
    if type(spr) == "string" then
      local u = spr:upper()
      if u:find("SNORLAX", 1, true) or u:find("RELAXO", 1, true)
          or u:find("BOULDER", 1, true) or u:find("ROCK", 1, true)
          or u:find("TREE", 1, true) or u:find("BUSH", 1, true)
          or u:find("CUT", 1, true) or u:find("PLANT", 1, true)
          or u:find("CABLE", 1, true) or u:find("SIGN", 1, true) then
        return "object"
      end
    end
    return "npc"
  end
  local spriteCache = {}
  -- Warm neutral (not blue) for minimap NPC sprites
  local SPRITE_PALETTE = {
    { 0.98, 0.96, 0.90 },
    { 0.92, 0.72, 0.48 },
    { 0.55, 0.38, 0.28 },
    { 0.12, 0.10, 0.10 },
  }
  local TRAINER_SPRITE_PALETTE = {
    { 0.98, 0.92, 0.90 },
    { 0.95, 0.45, 0.38 },
    { 0.65, 0.18, 0.16 },
    { 0.12, 0.06, 0.06 },
  }
  local ITEM_PALETTE = {
    { 1.00, 0.98, 0.75 },
    { 1.00, 0.82, 0.25 },
    { 0.85, 0.35, 0.20 },
    { 0.12, 0.08, 0.08 },
  }
  local OBJECT_PALETTE = {
    { 0.90, 0.95, 0.75 },
    { 0.55, 0.78, 0.35 },
    { 0.28, 0.48, 0.22 },
    { 0.08, 0.12, 0.08 },
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
    local out = love.image.newImageData(iw, ih)
    for y = 0, ih - 1 do
      for x = 0, iw - 1 do
        local r, g, b, a = data:getPixel(x, y)
        if a and a > 0 then
          local lum = r * 0.2126 + g * 0.7152 + b * 0.0722
          local shade = lum > 0.83 and 1 or (lum > 0.5 and 2 or (lum > 0.17 and 3 or 4))
          local c = palette[shade]
          out:setPixel(x, y, c[1], c[2], c[3], a)
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
  local function tryLoadImage(path, palette)
    if type(path) ~= "string" then return nil end
    local paths = { path }
    for _, prefix in ipairs({
      "", "assets/", "assets/generated/", "assets/generated/sprites/",
    }) do
      if prefix ~= "" or path ~= paths[1] then
        paths[#paths + 1] = prefix .. path
      end
    end
    -- unique
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
        local colored = recolorImageDataFromPath(p, palette)
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
  local function loadSpriteFrame(spriteId, facing)
    if not spriteId or type(spriteId) ~= "string" then
      return nil
    end
    facing = normalizeFacing(facing)
    local cacheKey = spriteId .. ":stand:" .. facing
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
    local img = tryLoadImage(def.image, SPRITE_PALETTE)
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
  local function getPokeballSprite()
    for _, id in ipairs({
      "SPRITE_POKE_BALL", "SPRITE_BALL", "SPRITE_POKEBALL", "SPRITE_ITEM_BALL",
    }) do
      local s = loadSpriteFrame(id, "down")
      if s then
        return s
      end
    end
    return nil
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
  local hiddenItemsDiagnosticLogged = false
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
    if #out == 0 and not hiddenItemsDiagnosticLogged then
      hiddenItemsDiagnosticLogged = true
      local data = game and game.data
      local field = data and data.field
      local dataKeys, fieldKeys = {}, {}
      if type(data) == "table" then
        for k in pairs(data) do dataKeys[#dataKeys + 1] = tostring(k) end
      end
      if type(field) == "table" then
        for k in pairs(field) do fieldKeys[#fieldKeys + 1] = tostring(k) end
      end
      local contentFieldKeys = {}
      if mod.content and mod.content.field and type(mod.content.field.get) == "function" then
        local ok, hi = pcall(function() return mod.content.field:get("hiddenItems") end)
        contentFieldKeys[#contentFieldKeys + 1] = "get('hiddenItems') ok=" .. tostring(ok) .. " type=" .. type(hi)
      end
      mod.log:info(
        "minimap: no hidden items for map '%s'. game.data keys=[%s] game.data.field keys=[%s] content.field=[%s]",
        tostring(mapId),
        table.concat(dataKeys, ", "),
        table.concat(fieldKeys, ", "),
        table.concat(contentFieldKeys, ", ")
      )
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
    local def = obj.def or obj
    if type(def) == "table" and def.id and save.defeatedTrainers[def.id] then
      return true
    end
    -- some saves key by trainerClass + map
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
    local save = game and game.save
    if not save or type(save.itemsTaken) ~= "table" then return false end
    if obj.id and save.itemsTaken[obj.id] then return true end
    local idx = obj.index or (obj.def and obj.def.index)
    if mapId and idx ~= nil then
      local key = string.format("%s_obj_%s", tostring(mapId), tostring(idx))
      if save.itemsTaken[key] then return true end
    end
    return false
  end
  local function isObjectHidden(game, obj, mapId)
    if obj.hidden == true or obj.visible == false or obj.removed == true
        or obj.active == false or obj.despawned == true then
      return true
    end
    local save = game and game.save
    if not save then return false end
    local def = obj.def or obj
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
    -- Defeated trainers stay visible (no battle badge later), do NOT hide them.
    if isObjectTaken(game, obj, mapId) and isItemBallObject(obj) then
      return true
    end
    return false
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
  local mapCanvasCache = {}
  local tileDiagnosticLogged = false
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
        if n >= 8 then -- expect 16, but tolerate a partial/irregular block
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
    -- Semantic Gen1 OVERWORLD-ish ids (and sensible defaults for others)
    -- Water
    if id == 0x14 or id == 0x20 or id == 0x48 or id == 0x49 or id == 0x4A
        or id == 0x4B or id == 0x4C or id == 0x4D or id == 0x4E or id == 0x4F
        or id == 0x50 or id == 0x51 or id == 0x52 or id == 0x53
        or id == 0x43 or id == 0x44 or id == 0x45 or id == 0x46 or id == 0x47 then
      return 0.25, 0.55, 0.92
    end
    -- Tall grass / grass
    if id == 0x0A or id == 0x0B or id == 0x0C or id == 0x0D
        or id == 0x02 or id == 0x03 then
      return 0.32, 0.78, 0.28
    end
    -- Trees / forest wall
    if id == 0x0F or id == 0x10 or id == 0x11 or id == 0x12 or id == 0x3E then
      return 0.12, 0.42, 0.16
    end
    -- Rock / mountain / brown earth
    if id == 0x2B or id == 0x2C or id == 0x2D or id == 0x2E
        or id == 0x31 or id == 0x32 or id == 0x33 or id == 0x34
        or id == 0x05 or id == 0x06 then
      return 0.55, 0.42, 0.28
    end
    -- Sand / path light
    if id == 0x01 or id == 0x27 or id == 0x28 or id == 0x29 then
      return 0.82, 0.75, 0.48
    end
    -- Buildings / walls gray-brown
    if id == 0x07 or id == 0x08 or id == 0x09 or id == 0x15
        or id == 0x16 or id == 0x17 or id == 0x18 or id == 0x19 then
      return 0.55, 0.52, 0.48
    end
    -- Default: soft grass / field
    local h = (id * 17) % 7
    if h <= 2 then
      return 0.40, 0.72, 0.30  -- grass
    elseif h <= 4 then
      return 0.50, 0.42, 0.28  -- dirt
    else
      return 0.62, 0.68, 0.42  -- light field
    end
  end
  local function blockTint(blockId)
    local r, g, b = blockColor(blockId)
    local mix = 0.35  -- 0 = pure tint, 1 = pure white
    return r + (1 - r) * mix, g + (1 - g) * mix, b + (1 - b) * mix
  end
  local optionsDiagnosticLogged = false
  local function logOptionsDiagnosticOnce(game)
    if optionsDiagnosticLogged then return end
    optionsDiagnosticLogged = true
    local o = game and game.save and game.save.options
    if type(o) ~= "table" then
      mod.log:info("minimap: game.save.options not a table (type=%s)", type(o))
      return
    end
    local parts = {}
    for k, v in pairs(o) do
      if k ~= "modOptions" then
        parts[#parts + 1] = string.format("%s=%s(%s)", tostring(k), tostring(v), type(v))
      end
    end
    mod.log:info("minimap: game.save.options keys=[%s]", table.concat(parts, ", "))
  end
  local function buildTerrainCanvas(mapId, tod, game)
    if tod then currentTod = tod end
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
    local function paletteForTileset(name)
      local outdoor = (
        name == "OVERWORLD"
        or name:find("JOHTO", 1, true) or name:find("KANTO", 1, true)
        or name:find("ROUTE", 1, true) or name:find("TOWN", 1, true)
        or name:find("CITY", 1, true) or name == "JOINTO"
        or name:find("PARK", 1, true) or name:find("FOREST", 1, true)
      )
      if outdoor then
        return {
          { 0.90, 0.98, 0.72 },
          { 0.42, 0.90, 0.32 },
          { 0.18, 0.58, 0.20 },
          { 0.08, 0.16, 0.08 },
        }
      end
      if name:find("POKECENTER", 1, true) or name:find("POKEMON_CENTER", 1, true)
          or name:find("MART", 1, true) or name:find("SHOP", 1, true) then
        return {
          { 0.98, 0.95, 0.95 },
          { 0.95, 0.30, 0.32 },
          { 0.72, 0.12, 0.16 },
          { 0.16, 0.06, 0.08 },
        }
      end
      if name:find("GYM", 1, true) then
        return {
          { 0.95, 0.95, 0.88 },
          { 0.55, 0.70, 0.95 },
          { 0.25, 0.35, 0.70 },
          { 0.08, 0.08, 0.18 },
        }
      end
      if name:find("HOUSE", 1, true) or name:find("GATE", 1, true)
          or name:find("INTERIOR", 1, true) or name:find("ROOF", 1, true) then
        return {
          { 0.98, 0.96, 0.90 },
          { 0.92, 0.32, 0.32 },
          { 0.55, 0.40, 0.28 },
          { 0.14, 0.08, 0.08 },
        }
      end
      if name:find("CAVE", 1, true) or name:find("ROCK", 1, true)
          or name:find("MOUNTAIN", 1, true) or name:find("TUNNEL", 1, true) then
        return {
          { 0.85, 0.82, 0.78 },
          { 0.55, 0.48, 0.42 },
          { 0.32, 0.28, 0.25 },
          { 0.08, 0.07, 0.07 },
        }
      end
      if name:find("FACILITY", 1, true) or name:find("LAB", 1, true)
          or name:find("SHIP", 1, true) or name:find("MUSEUM", 1, true)
          or name:find("GAME", 1, true) or name:find("CLUB", 1, true) then
        return {
          { 0.92, 0.95, 0.98 },
          { 0.55, 0.70, 0.85 },
          { 0.30, 0.40, 0.55 },
          { 0.08, 0.10, 0.14 },
        }
      end
      if name:find("CEMETERY", 1, true) or name:find("GRAVE", 1, true)
          or name:find("TOWER", 1, true) then
        return {
          { 0.90, 0.90, 0.95 },
          { 0.60, 0.58, 0.72 },
          { 0.35, 0.32, 0.48 },
          { 0.08, 0.07, 0.12 },
        }
      end
      return {
        { 0.96, 0.94, 0.90 },
        { 0.88, 0.35, 0.35 },
        { 0.50, 0.38, 0.28 },
        { 0.10, 0.08, 0.08 },
      }
    end
    local ACTIVE_PALETTE = paletteForTileset(tilesetNameU)
    local todForBuild = currentTod or "DAY"

    -- Outdoor color-mode palette:
    -- light = house walls / paths (beige), mid = grass, dark-mid = roofs/dirt brown, dark = outline.
    -- No ID-based water sheets (block IDs differ per map -> random blue).
    -- Bright RBY-style outdoor palettes (split so roofs can be red without painting trees red)
    local PAL_GRASS = {
      { 0.90, 0.98, 0.72 },
      { 0.42, 0.90, 0.32 },
      { 0.18, 0.58, 0.20 },
      { 0.08, 0.16, 0.08 },
    }
    local PAL_TREE = {
      { 0.55, 0.78, 0.35 },
      { 0.18, 0.48, 0.18 },
      { 0.10, 0.30, 0.12 },
      { 0.05, 0.10, 0.05 },
    }
    local PAL_BUILD = {
      { 0.95, 0.95, 0.92 },  -- light path / brick
      { 0.78, 0.72, 0.58 },  -- wall mid
      { 0.90, 0.25, 0.25 },  -- red roof
      { 0.12, 0.12, 0.14 },
    }
    local PAL_PATH = {
      { 0.95, 0.96, 0.94 },
      { 0.82, 0.86, 0.82 },
      { 0.55, 0.58, 0.55 },
      { 0.15, 0.16, 0.15 },
    }
    if gameVer == "gold" then
      local t = TOD_TINT[todForBuild] or TOD_TINT.DAY
      local function tintPal(pal)
        local out = {}
        for i = 1, 4 do
          out[i] = {
            math.min(1, pal[i][1] * (0.9 + 0.1 * t[1])),
            math.min(1, pal[i][2] * (0.9 + 0.1 * t[2])),
            math.min(1, pal[i][3] * (0.9 + 0.1 * t[3])),
          }
        end
        return out
      end
      PAL_GRASS, PAL_TREE, PAL_BUILD, PAL_PATH = tintPal(PAL_GRASS), tintPal(PAL_TREE), tintPal(PAL_BUILD), tintPal(PAL_PATH)
    end

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

    local function recolorWithPal(r, g, b, a, pal)
      if not a or a <= 0 then return r, g, b, a end
      local lum = r * 0.2126 + g * 0.7152 + b * 0.0722
      local shade = lum > 0.83 and 1 or (lum > 0.5 and 2 or (lum > 0.17 and 3 or 4))
      local c = pal[shade]
      return c[1], c[2], c[3], a
    end

    local function makeSheetFromData(data, pal)
      local iw, ih = data:getWidth(), data:getHeight()
      local out = love.image.newImageData(iw, ih)
      for y = 0, ih - 1 do
        for x = 0, iw - 1 do
          local r, g, b, a = data:getPixel(x, y)
          r, g, b, a = recolorWithPal(r, g, b, a, pal)
          out:setPixel(x, y, r, g, b, a)
        end
      end
      local okImg, colored = pcall(love.graphics.newImage, out)
      if okImg and colored then
        pcall(function() colored:setFilter("nearest", "nearest") end)
        return colored
      end
      return nil
    end

    local function imageIsMostlyGray(data)
      local iw, ih = data:getWidth(), data:getHeight()
      local samples, chroma = 0, 0
      local step = math.max(1, math.floor(math.max(iw, ih) / 32))
      for y = 0, ih - 1, step do
        for x = 0, iw - 1, step do
          local r, g, b, a = data:getPixel(x, y)
          if a and a > 0.1 then
            samples = samples + 1
            local mx = math.max(r, g, b)
            local mn = math.min(r, g, b)
            chroma = chroma + (mx - mn)
          end
        end
      end
      if samples < 1 then return true end
      return (chroma / samples) < 0.06
    end

    local function loadColoredTileset(imgPath, pal)
      pal = pal or ACTIVE_PALETTE
      if love.image and love.image.newImageData then
        local okData, data = pcall(love.image.newImageData, imgPath)
        if okData and data then
          local colored = makeSheetFromData(data, pal)
          if colored then return colored end
        end
      end
      local okImg, loaded = pcall(love.graphics.newImage, imgPath)
      if okImg and loaded then
        pcall(function() loaded:setFilter("nearest", "nearest") end)
        return loaded
      end
      return nil
    end

    local img, blockDefs, tilesPerRow
    local imgByCat = nil
    local rawTileData = nil
    if type(tsDef) == "table" then
      local imgPath = tsDef.image or findImagePath(tsDef)
      if type(imgPath) == "string" then
        if outdoorTileset and love.image and love.image.newImageData then
          local okData, data = pcall(love.image.newImageData, imgPath)
          if okData and data then
            rawTileData = data
            if not imageIsMostlyGray(data) then
              -- Engine already colorized — use true game colors
              local okImg, native = pcall(love.graphics.newImage, data)
              if okImg and native then
                pcall(function() native:setFilter("nearest", "nearest") end)
                img = native
              end
            end
            if not img then
              imgByCat = {
                grass = makeSheetFromData(data, PAL_GRASS),
                tree = makeSheetFromData(data, PAL_TREE),
                build = makeSheetFromData(data, PAL_BUILD),
                path = makeSheetFromData(data, PAL_PATH),
              }
              img = imgByCat.grass or imgByCat.path
            end
          end
        end
        if not img then
          img = loadColoredTileset(imgPath, outdoorTileset and PAL_GRASS or ACTIVE_PALETTE)
        end
      end
      if type(tsDef.blocks) == "table" then
        blockDefs = tsDef.blocks
      else
        blockDefs = findBlockDefs(tsDef)
      end
      tilesPerRow = tonumber(tsDef.tilesPerRow)
      if img and (not tilesPerRow or tilesPerRow <= 0) then
        tilesPerRow = math.max(1, math.floor(img:getWidth() / TILE_PX))
      end
    end
    local canUseTiles = img and blockDefs and tilesPerRow and tilesPerRow > 0
    if not canUseTiles and not tileDiagnosticLogged then
      tileDiagnosticLogged = true
      if tsDef then
        local fields = {}
        for k, v in pairs(tsDef) do
          fields[#fields + 1] = tostring(k) .. ":" .. type(v)
        end
        mod.log:info("minimap: tileset '%s' unusable for pixel art fields=[%s] -- flat colors",
          tostring(mapDef.tileset), table.concat(fields, ", "))
      else
        mod.log:info("minimap: no tileset for map '%s' -- flat colors", tostring(mapId))
      end
    end

    -- Border ring + connected neighbors (Gen1 only).
    -- Gold: tight map canvas, original colors, no tree ring (avoids cut-off).
    local isGold = (gameVer == "gold")
    -- Gold + RBY: show border ring (trees at map edge)
    local BORDER_BLOCKS = 10
    local TREE_WALL_BLOCK = 0x0F
    local WATER_BORDER_BLOCK = 0x43
    local function resolveBorderBlock(def)
      if not def then return TREE_WALL_BLOCK end
      if type(def.borderBlock) == "number" then
        return def.borderBlock
      end
      local ts = tostring(def.tileset or ""):upper()
      if outdoorTileset or ts == "OVERWORLD" or ts:find("JOHTO", 1, true) or ts:find("KANTO", 1, true) then
        return TREE_WALL_BLOCK
      end
      return 0
    end
    local borderId = resolveBorderBlock(mapDef)

    local function blockColorLocal(blockId)
      if blockId ~= nil and blockColor then
        local ok, r, g, b = pcall(blockColor, blockId)
        if ok and r then return r, g, b end
      end
      local base = VERSION_OUTDOOR[gameVer] or VERSION_OUTDOOR.red
      local c = base[2] or base[1]
      return c[1] * 0.7, c[2] * 0.7, c[3] * 0.7
    end

    local voidR, voidG, voidB = blockColorLocal(borderId)
    -- soft dark edge, not a solid green plate
    if outdoorTileset then
      voidR, voidG, voidB = 0.12, 0.18, 0.12
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

    local blockCatCache = {}
    local function categoryForBlock(blockId, def)
      local cached = blockCatCache[blockId]
      if cached then return cached end
      local cat = "grass"
      if type(def) == "table" and rawTileData and tilesPerRow and tilesPerRow > 0 then
        local sum, n = 0, 0
        local dark, light = 0, 0
        for i = 1, 16 do
          local tileId = def[i]
          if type(tileId) == "number" then
            local tc = tileId % tilesPerRow
            local tr = math.floor(tileId / tilesPerRow)
            local px = tc * TILE_PX + 4
            local py = tr * TILE_PX + 4
            local okp, r, g, b, a = pcall(function()
              return rawTileData:getPixel(px, py)
            end)
            if okp and a and a > 0.05 then
              local lum = r * 0.2126 + g * 0.7152 + b * 0.0722
              sum = sum + lum
              n = n + 1
              if lum < 0.28 then dark = dark + 1 end
              if lum > 0.72 then light = light + 1 end
            end
          end
        end
        if n > 0 then
          local avg = sum / n
          if dark >= 6 then
            cat = "tree"
          elseif light >= 6 and avg > 0.55 then
            cat = "path"
          elseif light >= 3 and avg > 0.45 then
            cat = "build"  -- mixed light + detail (houses, marts)
          elseif avg > 0.55 then
            cat = "path"
          else
            cat = "grass"
          end
        end
      end
      blockCatCache[blockId] = cat
      return cat
    end

    local function drawBlockAt(blockId, col, row)
      local bx, by = col * BLOCK_PX, row * BLOCK_PX
      if canUseTiles and blockDefs then
        local def = blockDefs[blockId + 1] or blockDefs[blockId]
        if type(def) == "table" then
          local sheet = img
          if imgByCat then
            local cat = categoryForBlock(blockId, def)
            sheet = imgByCat[cat] or imgByCat.grass or img
          end
          love.graphics.setColor(1, 1, 1, 1)
          for ty = 0, 3 do
            for tx = 0, 3 do
              local tileId = def[ty * 4 + tx + 1]
              local q = quadFor(tileId)
              if q and sheet then
                love.graphics.draw(sheet, q, bx + tx * TILE_PX, by + ty * TILE_PX)
              else
                local r, g, b = blockColorLocal(blockId)
                love.graphics.setColor(r, g, b, 1)
                love.graphics.rectangle(
                  "fill",
                  bx + tx * TILE_PX,
                  by + ty * TILE_PX,
                  TILE_PX,
                  TILE_PX
                )
                love.graphics.setColor(1, 1, 1, 1)
              end
            end
          end
          return
        end
      end
      local r, g, b = blockColorLocal(blockId)
      love.graphics.setColor(r, g, b, 1)
      love.graphics.rectangle("fill", bx, by, BLOCK_PX, BLOCK_PX)
      love.graphics.setColor(1, 1, 1, 1)
    end

    -- Border ring (trees / map edge) for RBY + Gold outdoor
    if borderId ~= nil and outdoorTileset then
      for row = 0, ch - 1 do
        for col = 0, cw - 1 do
          drawBlockAt(borderId, col, row)
        end
      end
    elseif borderId ~= nil and not outdoorTileset then
      for row = 0, ch - 1 do
        for col = 0, cw - 1 do
          drawBlockAt(borderId, col, row)
        end
      end
    end

    -- main map blocks (real tiles for all versions)
    local usedRealTiles = canUseTiles and true or false
    for i = 1, math.min(w * h, #mapBlocks) do
      local blockId = mapBlocks[i]
      if blockId ~= nil then
        local col = (i - 1) % w + originBX
        local row = math.floor((i - 1) / w) + originBY
        drawBlockAt(blockId, col, row)
      end
    end

    -- connected neighbor strips (Gen1 only; Gold uses plain map bounds)
    local conns = mapDef.connections
    if type(conns) == "table" and mod.content and mod.content.maps then
      local sides = {
        { key = "north", dx = 0, dy = -1 },
        { key = "south", dx = 0, dy = 1 },
        { key = "west", dx = -1, dy = 0 },
        { key = "east", dx = 1, dy = 0 },
        -- aliases
        { key = "up", dx = 0, dy = -1 },
        { key = "down", dx = 0, dy = 1 },
        { key = "left", dx = -1, dy = 0 },
        { key = "right", dx = 1, dy = 0 },
      }
      local drawnSide = {}
      for _, side in ipairs(sides) do
        local c = conns[side.key]
        if type(c) == "table" and c.map and not drawnSide[side.dx .. "," .. side.dy] then
          drawnSide[side.dx .. "," .. side.dy] = true
          local nDef = nil
          local okN, got = pcall(function()
            return mod.content.maps:get(c.map)
          end)
          if okN then nDef = got end
          if type(nDef) == "table" and type(nDef.blocks) == "table"
              and type(nDef.width) == "number" and type(nDef.height) == "number" then
            local nw, nh = nDef.width, nDef.height
            local nBlocks = nDef.blocks
            local offset = tonumber(c.offset) or 0
            -- how many blocks of the neighbor to show
            local depth = BORDER_BLOCKS
            if side.dy == -1 then
              -- neighbor is north: its bottom rows sit above our top
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
    -- originBX/BY shift player coords when drawing
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
    -- Prefer a ready image/canvas from the engine (true in-game colors)
    local img = overview.image or overview.canvas or overview.texture
    if img and type(img) == "userdata" then
      local iw, ih = 0, 0
      pcall(function()
        iw, ih = img:getWidth(), img:getHeight()
      end)
      if iw > 0 and ih > 0 then
        -- width/height in cells if provided
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
          width = math.floor(mw / 2), -- keep block units if engine gave cells
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
  local function getTerrainCanvas(mapId, game)
    local tod = getTimeOfDay(game)
    local ver = getGameVersion(game)
    local cacheKey = tostring(mapId) .. "#v:" .. tostring(ver) .. "#tod:" .. tostring(tod) .. "#g14"
    local cached = mapCanvasCache[cacheKey]
    if cached == nil then
      local built = nil
      do
        local ok, b = pcall(buildTerrainCanvas, mapId, tod, game)
        built = (ok and b) or false
      end
      cached = built or false
      mapCanvasCache[cacheKey] = cached
    end
    return cached or nil
  end
  local minimapWarned = false
  local minimapWarnedMaps = {}
  local function drawMinimap(game, mapId, mmX, mmY, cx, cy)
    logOptionsDiagnosticOnce(game)
    pcall(enrichGiftTextFromGame, game, mapId)
    pcall(logGiftDiagOnce, game, mapId)
    local zoomOpt = getOpt(game, "minimap_zoom", "0")
    local legacy = { near = 8, close = 4, medium = 0, far = -4, wide = -8, small = 4, large = -4 }
    if legacy[zoomOpt] ~= nil then
      zoomOpt = tostring(legacy[zoomOpt])
    end
    local radius = radiusForZoom(zoomOpt, ZOOM_BASE_RADIUS)
    local boxPx = MINIMAP_BOX
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
      -- canvas is built in block pixels; player coords are cells (2 cells per block)
      local originCellsX = (terrain.originBX or 0) * 2
      local originCellsY = (terrain.originBY or 0) * 2
      local playerPxX = (cx + originCellsX + 0.5) * CELL_PX
      local playerPxY = (cy + originCellsY + 0.5) * CELL_PX
      -- fill content with soft terrain color so any remaining void is not pure black
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
      for _, obj in ipairs(objs) do
        local okObj, errObj = pcall(function()
          if obj == player then
            return
          end
          local kind = objectKind(obj, mapId)
          local want = (kind == "item" or kind == "hidden") and showItems
              or (kind == "gift_npc" and (showItems or showNpc))
              or ((kind == "npc" or kind == "trainer" or kind == "object") and showNpc)
          if not want then return end
          if isObjectHidden(game, obj, mapId) then return end
          if kind == "item" and isObjectTaken(game, obj, mapId) then return end
          if kind == "gift_npc" then
            if isGiftAlreadyTaken(game, obj, mapId) then
              if not showNpc then return end
              kind = "npc"
            end
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
            spr = loadSpriteFrame(sid, facing)
          end
          if not spr then
            spr = spriteFromEntity(obj, facing)
          end
          if kind == "item" or kind == "hidden" then
            local ball = getPokeballSprite()
            if ball then spr = ball end
          end
          local defeatedTrainer = (kind == "trainer") and isTrainerDefeated(game, obj, mapId)
          local drawn = false
          if kind == "item" or kind == "hidden" then
            drawGlow(px, py, markerSize * 0.4, 1, 0.95, 0.3)
          elseif kind == "gift_npc" then
            drawGlow(px, py, markerSize * 0.55, 0.15, 0.95, 1)
          elseif kind == "trainer" and not defeatedTrainer then
            -- strong red glow so battle trainers are always obvious
            drawGlow(px, py, markerSize * 0.55, 0.95, 0.15, 0.12)
          end
          if spr then
            local tint = nil
            if kind == "trainer" and not defeatedTrainer then
              tint = { 1.0, 0.55, 0.50, 1 }
            elseif kind == "trainer" and defeatedTrainer then
              tint = { 0.85, 0.85, 0.88, 1 }
            elseif kind == "gift_npc" then
              tint = { 0.55, 0.95, 1.0, 1 }
            elseif kind == "item" or kind == "hidden" then
              tint = { 1.0, 0.95, 0.45, 1 }
            elseif kind == "object" then
              tint = { 0.70, 0.90, 0.45, 1 }
            else
              -- normal NPC: warm skin/clothes, not blue
              tint = { 1.0, 0.92, 0.75, 1 }
            end
            drawn = drawSpriteMarker(spr, px, py, markerSize, facing, tint)
          end
          if not drawn then
            if kind == "trainer" and not defeatedTrainer then
              love.graphics.setColor(0.95, 0.15, 0.12, 1)
              love.graphics.circle("fill", px, py, 4.0)
            elseif kind == "trainer" and defeatedTrainer then
              love.graphics.setColor(0.80, 0.80, 0.85, 1)
              love.graphics.circle("fill", px, py, 3)
            elseif kind == "gift_npc" then
              love.graphics.setColor(0.15, 0.9, 1, 1)
              love.graphics.circle("fill", px, py, 3.5)
              love.graphics.setColor(1, 1, 1, 1)
              love.graphics.circle("line", px, py, 3.5)
            elseif kind == "item" or kind == "hidden" then
              love.graphics.setColor(1, 0.95, 0.3, 1)
              local s = 5
              love.graphics.polygon("fill", px, py - s, px + s, py, px, py + s, px - s, py)
            elseif kind == "object" then
              love.graphics.setColor(0.6, 0.8, 0.35, 1)
              love.graphics.rectangle("fill", px - 3, py - 3, 6, 6)
            else
              love.graphics.setColor(1, 0.85, 0.45, 1)
              love.graphics.circle("fill", px, py, 3)
            end
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.setLineWidth(1.2)
            love.graphics.circle("line", px, py, 3.5)
          end
          if kind == "gift_npc" then
            love.graphics.setColor(0.15, 0.95, 1, 1)
            love.graphics.circle("fill", px + markerSize * 0.30, py - markerSize * 0.30, 2.6)
            love.graphics.setColor(0, 0, 0, 0.85)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", px + markerSize * 0.30, py - markerSize * 0.30, 2.6)
          elseif kind == "trainer" and not defeatedTrainer then
            -- battle-ready: big red "!" badge, always
            local bx, by = px + markerSize * 0.32, py - markerSize * 0.32
            love.graphics.setColor(0.95, 0.12, 0.10, 1)
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
      local ball = getPokeballSprite()
      for _, hi in ipairs(getHiddenItems(game, mapId)) do
        if not isHiddenTaken(game, mapId, hi.x, hi.y) then
          if math.abs(hi.x - cx) <= radius and math.abs(hi.y - cy) <= radius then
            local px = centerX + (hi.x - cx) * cellScale
            local py = centerY + (hi.y - cy) * cellScale
            drawGlow(px, py, markerSize * 0.4, 1, 0.3, 0.85)
            local drawn = ball and drawSpriteMarker(ball, px, py, markerSize * 0.95, "down")
            if not drawn then
              love.graphics.setColor(1, 0.5, 1, 1)
              local s = 5
              love.graphics.polygon("fill", px, py - s, px + s, py, px, py + s, px - s, py)
              love.graphics.setColor(0, 0, 0, 0.85)
              love.graphics.setLineWidth(1.2)
              love.graphics.polygon("line", px, py - s, px + s, py, px, py + s, px - s, py)
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
        playerSpr = spriteFromEntity(player, faceStr)
        if not playerSpr and player then
          local sid = objectSpriteId(player)
          if sid then playerSpr = loadSpriteFrame(sid, faceStr) end
        end
        if not playerSpr then
          for _, id in ipairs({
            "SPRITE_RED", "SPRITE_GOLD", "SPRITE_YELLOW", "SPRITE_BOY",
            "SPRITE_RED_BIKE", "SPRITE_PLAYER",
          }) do
            playerSpr = loadSpriteFrame(id, faceStr)
            if playerSpr then break end
          end
        end
      end)
      local drawn = false
      if playerSpr then
        local okD = pcall(drawSpriteMarker, playerSpr, centerX, centerY, markerSize * 1.15, faceStr)
        drawn = okD and true
      end
      if not drawn then
        love.graphics.setColor(0.25, 0.95, 0.35, 1)
        love.graphics.circle("fill", centerX, centerY, 4.5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", centerX, centerY, 4.5)
      end
    end
    love.graphics.setScissor()
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", mmX + 0.5, mmY + 0.5, boxPx - 1, boxPx - 1, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", mmX + 1.5, mmY + 1.5, boxPx - 3, boxPx - 3, 3, 3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
  end
  mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
    if nextFn then
      nextFn(game, viewport)
    end
    if not shouldDraw(game) then
      return
    end
    local mapId, cx, cy = getLocation(game)
    if not mapId then
      return
    end
    local infoMode = getOpt(game, "show_info", "both")
    local showLoc = (infoMode == "location" or infoMode == "both")
    local showPos = (infoMode == "position" or infoMode == "both")
    local wantInfo = infoMode ~= "off" and (showLoc or showPos)
    local rawMap = getOpt(game, "minimap", "top_left")
    local mapPos = normalizeMinimapPos(rawMap)
    if mapPos == nil then
      mapPos = "top_left"
    end
    if rawMap == "off" then
      mapPos = "off"
    end
    local wantMap = mapPos ~= "off"
    local hudPos = getOpt(game, "hud_position", "top_right")
    local margin = 6
    local gap = 6
    local ww, wh = love.graphics.getDimensions()
    local boxPx = MINIMAP_BOX
    local lines, pad, lineH, boxW, boxH = {}, 4, 14, 0, 0
    if wantInfo then
      if showLoc then
        lines[#lines + 1] = formatMapId(mapId)
      end
      if showPos then
        local facing = getFacing(game)
        if facing then
          lines[#lines + 1] = string.format("X:%d  Y:%d  %s", cx, cy, facing)
        else
          lines[#lines + 1] = string.format("X:%d  Y:%d", cx, cy)
        end
      end
      local font = love.graphics.getFont()
      lineH = (font and font:getHeight() or 12) + 2
      local maxW = 0
      for _, line in ipairs(lines) do
        local w = font and font:getWidth(line) or (#line * 8)
        if w > maxW then
          maxW = w
        end
      end
      boxW = maxW + pad * 2
      boxH = #lines * lineH + pad * 2
    end
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
    local function isTop(corner)
      return corner == "top_left" or corner == "top_right"
    end
    local function isLeft(corner)
      return corner == "top_left" or corner == "bottom_left"
    end
    local mmX, mmY, infoX, infoY
    local sameCorner = wantMap and wantInfo and mapPos == hudPos
    if sameCorner then
      local stackH = boxPx + gap + boxH
      local stackW = math.max(boxPx, boxW)
      local sx, sy = cornerXY(mapPos, stackW, stackH)
      if isLeft(mapPos) then
        mmX = sx
        infoX = sx
      else
        mmX = sx + stackW - boxPx
        infoX = sx + stackW - boxW
      end
      if isTop(mapPos) then
        mmY = sy
        infoY = sy + boxPx + gap
      else
        mmY = sy
        infoY = sy + boxPx + gap
      end
    else
      if wantMap then
        mmX, mmY = cornerXY(mapPos, boxPx, boxPx)
      end
      if wantInfo then
        infoX, infoY = cornerXY(hudPos, boxW, boxH)
      end
    end
    local function drawInfoAt(x, y)
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
    end
    if wantMap and mmX and mmY then
      local ok, err = pcall(drawMinimap, game, mapId, mmX, mmY, cx, cy)
      if not ok and not minimapWarned then
        minimapWarned = true
        mod.log:warn("minimap draw failed: %s", tostring(err))
      end
    end
    if wantInfo and infoX and infoY then
      drawInfoAt(infoX, infoY)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setScissor()
  end)

  -- Keep minimap in sync with Gen2 day/night changes
  pcall(function()
    mod.events:on("world.tod_changed", function(ev)
      if ev and ev.tod then
        local n = normalizeTod(ev.tod)
        if n then currentTod = n end
      end
      -- drop cached canvases so next draw rebuilds with new tint
      for k in pairs(mapCanvasCache) do
        mapCanvasCache[k] = nil
      end
    end)
  end)
  pcall(function()
    mod.events:on("map.entered", function()
      -- refresh tod when entering a map
      currentTod = getTimeOfDay(nil) or currentTod
    end)
  end)
end
