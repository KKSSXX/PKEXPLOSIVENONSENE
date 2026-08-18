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
    {
      key = "debug_ids",
      label = "DEBUG IDS",
      type = "choice",
      default = "off",
      choices = {
        { "OFF", "off" },
        { "ON", "on" },
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
  local ZOOM_BASE_RADIUS = 12  -- cells from center at zoom 0
  local ZOOM_STEP = 1.2        -- cells per zoom unit
  local function radiusForZoom(z)
    z = tonumber(z) or 0
    if z > 10 then z = 10 end
    if z < -10 then z = -10 end
    -- +10 => radius ~ 0 (min 3), -10 => radius ~ 24
    local r = ZOOM_BASE_RADIUS - z * ZOOM_STEP
    if r < 3 then r = 3 end
    if r > 40 then r = 40 end
    return r
  end
  local BLOCK_PX = 32
  local TILE_PX = 8
  local CELL_PX = 16
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
    local def = obj.def
    return obj.trainerClass ~= nil or obj.trainerParty ~= nil or obj.isTrainer == true
        or (type(def) == "table" and (def.trainerClass ~= nil or def.trainerParty ~= nil))
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
  local function tryLoadImage(path)
    if type(path) ~= "string" then return nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
      pcall(function() img:setFilter("nearest", "nearest") end)
      return img
    end
    for _, prefix in ipairs({
      "", "assets/", "assets/generated/", "assets/generated/sprites/",
    }) do
      local p = prefix .. path
      ok, img = pcall(love.graphics.newImage, p)
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
    local img = tryLoadImage(def.image)
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
  local function drawSpriteMarker(spr, px, py, markerSize, facing)
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
    love.graphics.setColor(1, 1, 1, 1)
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
    if def.pokemon and type(save.defeatedTrainers) == "table" then
      if idx then
        local key = string.format("%s_obj_%s", tostring(mapId), tostring(idx))
        if save.defeatedTrainers[key] or save.defeatedTrainers[obj.id] then
          return true
        end
      end
    end
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
    local id = math.floor(tonumber(blockId) or 0)
    local hue = ((id * 2654435761) % 1000) / 1000
    local sat = 0.55 + ((id * 2246822519) % 100) / 400  -- 0.55..0.80
    local val = 0.72 + ((id * 3266489917) % 100) / 500  -- 0.72..0.92
    local h6 = hue * 6
    local i = math.floor(h6)
    local f = h6 - i
    local p = val * (1 - sat)
    local q = val * (1 - f * sat)
    local t = val * (1 - (1 - f) * sat)
    local r, g, b
    if i == 0 then
      r, g, b = val, t, p
    elseif i == 1 then
      r, g, b = q, val, p
    elseif i == 2 then
      r, g, b = p, val, t
    elseif i == 3 then
      r, g, b = p, q, val
    elseif i == 4 then
      r, g, b = t, p, val
    else
      r, g, b = val, p, q
    end
    return r, g, b
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
  local function buildTerrainCanvas(mapId)
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
    local ADV_PALETTE = {
      { 0.98, 0.98, 0.88 }, -- shade 0 light
      { 0.35, 0.82, 0.42 }, -- shade 1 bright green
      { 0.18, 0.42, 0.55 }, -- shade 2 teal/blue-gray
      { 0.06, 0.08, 0.14 }, -- shade 3 near-black
    }
    local function recolorSample(r, g, b, a)
      if not a or a <= 0 then
        return r, g, b, a
      end
      local lum = r * 0.2126 + g * 0.7152 + b * 0.0722
      local shade = lum > 0.83 and 1 or (lum > 0.5 and 2 or (lum > 0.17 and 3 or 4))
      local c = ADV_PALETTE[shade]
      return c[1], c[2], c[3], a
    end
    local function loadColoredTileset(imgPath)
      if love.image and love.image.newImageData then
        local okData, data = pcall(love.image.newImageData, imgPath)
        if okData and data then
          local iw, ih = data:getWidth(), data:getHeight()
          local out = love.image.newImageData(iw, ih)
          for y = 0, ih - 1 do
            for x = 0, iw - 1 do
              local r, g, b, a = data:getPixel(x, y)
              r, g, b, a = recolorSample(r, g, b, a)
              out:setPixel(x, y, r, g, b, a)
            end
          end
          local okImg, colored = pcall(love.graphics.newImage, out)
          if okImg and colored then
            pcall(function()
              colored:setFilter("nearest", "nearest")
            end)
            return colored
          end
        end
      end
      local okImg, loaded = pcall(love.graphics.newImage, imgPath)
      if okImg and loaded then
        pcall(function()
          loaded:setFilter("nearest", "nearest")
        end)
        return loaded
      end
      return nil
    end
    local img, blockDefs, tilesPerRow
    if type(tsDef) == "table" then
      local imgPath = tsDef.image or findImagePath(tsDef)
      if type(imgPath) == "string" then
        img = loadColoredTileset(imgPath)
      end
      if type(tsDef.blocks) == "table" then
        blockDefs = tsDef.blocks
      else
        blockDefs = findBlockDefs(tsDef)
      end
      tilesPerRow = tonumber(tsDef.tilesPerRow)
      if img and (not tilesPerRow or tilesPerRow <= 0) then
        tilesPerRow = math.floor(img:getWidth() / TILE_PX)
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
    local canvas = love.graphics.newCanvas(w * BLOCK_PX, h * BLOCK_PX)
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    local usedRealTiles = false
    if canUseTiles then
      usedRealTiles = true
      local sheetW, sheetH = img:getWidth(), img:getHeight()
      local quadCache = {}
      local function quadFor(tileId)
        if type(tileId) ~= "number" then
          return nil
        end
        local q = quadCache[tileId]
        if not q then
          local col = tileId % tilesPerRow
          local row = math.floor(tileId / tilesPerRow)
          local qx, qy = col * TILE_PX, row * TILE_PX
          if qx + TILE_PX <= sheetW and qy + TILE_PX <= sheetH then
            q = love.graphics.newQuad(qx, qy, TILE_PX, TILE_PX, sheetW, sheetH)
            quadCache[tileId] = q
          else
            return nil
          end
        end
        return q
      end
      for i = 1, math.min(w * h, #mapBlocks) do
        local blockId = mapBlocks[i]
        if blockId == nil then
        else
          local def = blockDefs[blockId + 1] or blockDefs[blockId]
          if type(def) == "table" then
            love.graphics.setColor(1, 1, 1, 1)
            local col = (i - 1) % w
            local row = math.floor((i - 1) / w)
            local bx, by = col * BLOCK_PX, row * BLOCK_PX
            -- Engine layout: for ty=0..3, tx=0..3 → def[ty*4 + tx + 1]
            for ty = 0, 3 do
              for tx = 0, 3 do
                local tileId = def[ty * 4 + tx + 1]
                local q = quadFor(tileId)
                if q then
                  love.graphics.draw(img, q, bx + tx * TILE_PX, by + ty * TILE_PX)
                end
              end
            end
          end
        end
      end
    else
      for i = 1, math.min(w * h, #mapBlocks) do
        local blockId = mapBlocks[i]
        local r, g, b = blockColor(blockId)
        love.graphics.setColor(r, g, b, 1)
        local col = (i - 1) % w
        local row = math.floor((i - 1) / w)
        love.graphics.rectangle("fill", col * BLOCK_PX, row * BLOCK_PX, BLOCK_PX, BLOCK_PX)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas(prevCanvas)
    return { canvas = canvas, width = w, height = h, usedRealTiles = usedRealTiles }
  end
  local function getTerrainCanvas(mapId)
    local cacheKey = tostring(mapId) .. "#adv2"
    local cached = mapCanvasCache[cacheKey]
    if cached == nil then
      local ok, built = pcall(buildTerrainCanvas, mapId)
      cached = (ok and built) or false
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
    local radius = radiusForZoom(zoomOpt)
    local boxPx = MINIMAP_BOX
    love.graphics.setColor(0.04, 0.04, 0.07, 0.92)
    love.graphics.rectangle("fill", mmX, mmY, boxPx, boxPx, 4, 4)
    local borderPad = 2
    local contentX = mmX + borderPad
    local contentY = mmY + borderPad
    local contentPx = boxPx - borderPad * 2
    local terrain = getTerrainCanvas(mapId)
    if terrain then
      local cellsAcross = radius * 2 + 1
      local cellPxOnScreen = contentPx / cellsAcross
      local scale = cellPxOnScreen / CELL_PX
      local playerPxX = (cx + 0.5) * CELL_PX
      local playerPxY = (cy + 0.5) * CELL_PX
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.setScissor(contentX, contentY, contentPx, contentPx)
      love.graphics.draw(
        terrain.canvas,
        contentX + contentPx / 2 - playerPxX * scale,
        contentY + contentPx / 2 - playerPxY * scale,
        0, scale, scale
      )
      love.graphics.setScissor()
    end
    local cellScale = contentPx / (radius * 2 + 1)
    local centerX = contentX + contentPx / 2
    local centerY = contentY + contentPx / 2
    local markerSize = math.max(10, math.min(22, cellScale * 1.35))
    local markerMode = getOpt(game, "show_markers", "all")
    local showNpc = (markerMode == "npc" or markerMode == "all")
    local showItems = (markerMode == "items" or markerMode == "all")
    local debugIds = getOpt(game, "debug_ids", "off") == "on"
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
          local drawn = false
          if kind == "item" or kind == "hidden" then
            drawGlow(px, py, markerSize * 0.4, 1, 0.95, 0.3)
          elseif kind == "gift_npc" then
            drawGlow(px, py, markerSize * 0.55, 0.15, 0.95, 1)
          end
          if spr then
            drawn = drawSpriteMarker(spr, px, py, markerSize, facing)
          end
          if debugIds and (kind == "npc" or kind == "gift_npc" or kind == "trainer") then
            local lbl = string.format("i%s t%s", tostring(objectIndex(obj) or "?"), tostring(objectTextId(obj) or "?"))
            if kind == "gift_npc" then
              lbl = lbl .. " r:" .. tostring(lastGiftReason or "?")
            end
            local f = love.graphics.getFont()
            local lw = f and f:getWidth(lbl) or (#lbl * 6)
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.print(lbl, px - lw / 2 + 1, py + markerSize * 0.5 + 1)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(lbl, px - lw / 2, py + markerSize * 0.5)
          end
          if not drawn then
            if kind == "trainer" then
              love.graphics.setColor(0.95, 0.2, 0.2, 1)
              love.graphics.circle("fill", px, py, 3.2)
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
              love.graphics.setColor(1, 0.9, 0.2, 1)
              love.graphics.circle("fill", px, py, 3)
            end
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.setLineWidth(1.2)
            love.graphics.circle("line", px, py, 3.2)
          end
          if kind == "gift_npc" and drawn then
            love.graphics.setColor(0.15, 0.95, 1, 1)
            love.graphics.circle("fill", px + markerSize * 0.28, py - markerSize * 0.28, 2.4)
            love.graphics.setColor(0, 0, 0, 0.85)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", px + markerSize * 0.28, py - markerSize * 0.28, 2.4)
          elseif kind == "trainer" and drawn then
            local bx, by = px + markerSize * 0.28, py - markerSize * 0.28
            love.graphics.setColor(0.95, 0.15, 0.15, 1)
            love.graphics.circle("fill", bx, by, 2.4)
            love.graphics.setColor(0, 0, 0, 0.85)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", bx, by, 2.4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(1)
            love.graphics.line(bx, by - 1.1, bx, by + 0.2)
            love.graphics.points(bx, by + 1.3)
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
end