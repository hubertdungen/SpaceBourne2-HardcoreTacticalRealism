--[[
  Shared helpers. Safety rules used everywhere in HTR:
   * Game objects are only touched inside hook callbacks (they are alive there)
     or right after an engine lookup. No object is kept from one frame to the next;
     per-NPC state is keyed by address and holds plain numbers only.
   * Never call RegisterLoadMapPreHook/PostHook: they crash this game.
   * Hooks are only placed on Blueprint functions (native hooks called from
     Blueprint code receive garbage parameters in UE4SS 3.0 and crash).
   * Never scan all objects (FindAllOf/FindFirstOf) in code that runs during a fight:
     one scan costs ~50 ms in this game (0.3.1 did twelve per shot = 630 ms freezes).
     NPCs are found through npc.lua's position registry instead.
   * GetAllActorsOfClass with a Lua out-table corrupts the Lua state in UE4SS 3.0.1.
]]

local U = {}

-- Mod folder (UE4SS may report the path as ...\Scripts\ or ...\scripts\).
do
    local src = debug.getinfo(1, "S").source:gsub("^@", "")
    local lower = src:lower()
    local cut
    for i in lower:gmatch("()[\\/]scripts[\\/]") do cut = i end
    U.Dir = cut and src:sub(1, cut) or ".\\Mods\\HardcoreTacticalRealism\\"
end
U.LogFile = U.Dir .. "htr.log"
U.Verbose = false
U.LogHits = false

function U.log(...)
    if not U.Verbose then return end
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    local f = io.open(U.LogFile, "a")
    if f then f:write(os.date("%H:%M:%S "), table.concat(t, " "), "\n"); f:close() end
end

-- Always printed (UE4SS.log) and logged.
function U.warn(...)
    local msg = table.concat({ ... }, " ")
    print("[HTR] " .. msg .. "\n")
    local f = io.open(U.LogFile, "a")
    if f then f:write(os.date("%H:%M:%S "), "WARN ", msg, "\n"); f:close() end
end

function U.valid(o)
    if o == nil then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v
end

function U.className(o)
    if not U.valid(o) then return nil end
    local ok, n = pcall(function() return o:GetClass():GetFName():ToString() end)
    return ok and n or nil
end

function U.addr(o)
    local ok, a = pcall(function() return o:GetAddress() end)
    return ok and a or nil
end

-- Safe property read with default.
function U.get(o, prop, default)
    local ok, v = pcall(function() return o[prop] end)
    if ok and v ~= nil then return v end
    return default
end

function U.set(o, prop, value)
    return pcall(function() o[prop] = value end)
end

function U.fname(o, prop)
    local ok, s = pcall(function() return o[prop]:ToString() end)
    return ok and s or "None"
end

function U.clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

local GS
function U.gameplayStatics()
    if not U.valid(GS) then GS = StaticFindObject("/Script/Engine.Default__GameplayStatics") end
    return GS
end

-- Game time in seconds (pauses with the game). ctx: any live object.
function U.now(ctx)
    local ok, t = pcall(function() return U.gameplayStatics():GetTimeSeconds(ctx) end)
    if ok and type(t) == "number" then return t end
    return os.clock()
end

function U.location(actor)
    local ok, l = pcall(function() return actor:K2_GetActorLocation() end)
    if ok and l then return { X = l.X, Y = l.Y, Z = l.Z } end
    return nil
end

function U.dist(a, b)
    if not (a and b) then return 1e9 end
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function U.speed(actor)
    local ok, v = pcall(function() local x = actor:GetVelocity(); return math.sqrt(x.X * x.X + x.Y * x.Y + x.Z * x.Z) end)
    return ok and v or 0
end

-- Blackboard helpers for shooter NPCs.
function U.blackboard(npc)
    local ok, bb = pcall(function()
        local c = npc.Controller
        if c and c:IsValid() then return c.Blackboard end
    end)
    if ok and U.valid(bb) then return bb end
    return nil
end

function U.bbSetBool(npc, key, value)
    local bb = U.blackboard(npc)
    if not bb then return false end
    return pcall(function() bb:SetValueAsBool(FName(key), value) end)
end

function U.bbGetBool(npc, key)
    local bb = U.blackboard(npc)
    if not bb then return nil end
    local ok, v = pcall(function() return bb:GetValueAsBool(FName(key)) end)
    return ok and v or nil
end

-- The player's pawn. ctx: any live object in the world -> instant engine lookup.
-- Without ctx it scans every object (~50 ms in this game): key presses only, never in combat code.
function U.playerPawn(ctx)
    if ctx ~= nil then
        local ok, p = pcall(function() return U.gameplayStatics():GetPlayerPawn(ctx, 0) end)
        if ok and U.valid(p) then return p end
        return nil
    end
    local pcs = FindAllOf("PlayerController")
    if not pcs then return nil end
    for _, pc in ipairs(pcs) do
        if U.valid(pc) then
            local ok, p = pcall(function() return pc.Pawn end)
            if ok and U.valid(p) then return p end
        end
    end
    return nil
end

-- Which modifier is held right now: "SHIFT", "CONTROL", "ALT" or "" (none), asked of the game's
-- own input. Used to keep plain keys quiet while a modifier is held. Key presses only.
local PC
local MOD_KEYS = { { "SHIFT", "LeftShift" }, { "SHIFT", "RightShift" }, { "CONTROL", "LeftControl" },
    { "CONTROL", "RightControl" }, { "ALT", "LeftAlt" }, { "ALT", "RightAlt" } }
function U.modifierState()
    if not U.valid(PC) then PC = FindFirstOf("PlayerController") end
    if not U.valid(PC) then return "" end
    for _, m in ipairs(MOD_KEYS) do
        local ok, down = pcall(function() return PC:IsInputKeyDown({ KeyName = FName(m[2]) }) end)
        if ok and down then return m[1] end
    end
    return ""
end
function U.modifierDown() return U.modifierState() ~= "" end

-- On-screen message. Verified on screen: on foot, the HUD warning the game uses for
-- "No Target Nearby" (right side, warning icon); elsewhere (e.g. in a ship), the red
-- warning line it uses for "In Cooldown..." (top left). (SendSystemMessage, used up to
-- 0.4.0, shows nothing on foot.)
local MSG_LIB = "/Game/1Data/FunctionsMacros/Q1FunctionLibary.Default__Q1FunctionLibary_C"
function U.notify(text, ctx)
    local p = U.playerPawn(ctx)
    if U.valid(p) and pcall(function() p:TMWPerkWarning(FText(text)) end) then return true end
    local lib = StaticFindObject(MSG_LIB)
    local wc = U.valid(p) and p or ctx
    if not (U.valid(lib) and U.valid(wc)) then return false end
    return pcall(function() lib:CursorWarningWidget(FText(text), wc) end)
end

return U
