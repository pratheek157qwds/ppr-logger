--[[
    ppr-logger · client/leaveped.lua
    ──────────────────────────────────
    Everything visual for the ghost ped system.

    Architecture (two-loop optimization for 0.00ms idle):
    ─────────────────────────────────────────────────────
    Loop 1 (slow, 1s):  Scans GetGamePool('CPed') for peds with the
                         leaveData statebag. Dresses undressed peds
                         (freeze, anim, prop). Finds closest ghost.

    Loop 2 (adaptive):  Only does per-frame work when a ghost is nearby.
                         Draws 3D text, handles E-press interaction.
                         Falls back to 250-500ms when nothing is close.

    This pattern is the standard FiveM perf technique.
    Idle cost ≈ 0.00ms. Only spikes near a ghost ped.
]]

local dressedPeds = {}  -- ped handle → board object handle
local nearbyGhost = nil -- closest ghost ped (set by scanner, read by interaction loop)

-- ════════════════════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════════════════════

--- Draws floating 3D text at world coordinates.
--- Classic FiveM helper — used for name tags and prompts.
---@param coords vector3
---@param text   string
---@param scale  number|nil  text scale (default 0.30)
local function DrawText3D(coords, text, scale)
    scale = scale or 0.30
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

--- Loads an anim dict with timeout protection.
---@param dict string
---@return boolean loaded
local function SafeLoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

--- Loads a model with timeout protection.
---@param model number|string
---@return boolean loaded
local function SafeLoadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasModelLoaded(model)
end

--- Freezes the ped, plays mugshot-lineup anim, attaches the ID board.
--- Runs ONCE per ped, locally on each client.
---@param ped number  entity handle
local function DressGhostPed(ped)
    -- Freeze & protect
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true) -- ped ignores gunshots, cars, etc.
    SetPedCanRagdoll(ped, false)

    -- Animation
    local animCfg = Config.LeavePed.anim
    if SafeLoadAnimDict(animCfg.dict) then
        TaskPlayAnim(ped, animCfg.dict, animCfg.name,
            8.0, -8.0, -1, 1, 0, false, false, false)
    end

    -- Mugshot board prop
    local propCfg = Config.LeavePed.prop
    local board = nil

    if SafeLoadModel(propCfg.model) then
        local pc = GetEntityCoords(ped)
        board = CreateObject(propCfg.model, pc.x, pc.y, pc.z, false, false, false)

        if board and board ~= 0 then
            local p, r = propCfg.pos, propCfg.rot
            AttachEntityToEntity(board, ped, GetPedBoneIndex(ped, propCfg.bone),
                p.x, p.y, p.z,
                r.x, r.y, r.z,
                true, true, false, true, 1, true)
        end

        SetModelAsNoLongerNeeded(propCfg.model)
    end

    dressedPeds[ped] = board or true -- store board handle (or true if no board)
end

-- ════════════════════════════════════════════════════════
--  LOOP 1: SLOW SCANNER (every 1 second)
-- ════════════════════════════════════════════════════════
-- Scans for ghost peds, dresses new ones, finds closest.
CreateThread(function()
    while true do
        local myCoords = GetEntityCoords(PlayerPedId())
        local closestPed = nil
        local closestDist = Config.LeavePed.drawDist

        for _, ped in ipairs(GetGamePool('CPed')) do
            local data = Entity(ped).state.leaveData

            if data then
                -- Dress if not yet dressed
                if not dressedPeds[ped] then
                    DressGhostPed(ped)
                end

                -- Track closest ghost
                local dist = #(myCoords - GetEntityCoords(ped))
                if dist < closestDist then
                    closestDist = dist
                    closestPed  = ped
                end
            end
        end

        nearbyGhost = closestPed

        -- Clean up boards for peds that no longer exist (despawned by server)
        for ped, board in pairs(dressedPeds) do
            if not DoesEntityExist(ped) then
                if type(board) ~= 'boolean' and DoesEntityExist(board) then
                    DeleteEntity(board)
                end
                dressedPeds[ped] = nil
            end
        end

        Wait(1000)
    end
end)

-- ════════════════════════════════════════════════════════
--  LOOP 2: ADAPTIVE INTERACTION (per-frame when close)
-- ════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        if nearbyGhost and DoesEntityExist(nearbyGhost) then
            local data = Entity(nearbyGhost).state.leaveData
            local pedCoords = GetEntityCoords(nearbyGhost)
            local myCoords  = GetEntityCoords(PlayerPedId())
            local dist = #(myCoords - pedCoords)

            if data and dist < Config.LeavePed.drawDist then
                -- ── Name tag (always visible within draw distance) ──
                local tagColor = data.isCombatLog and '~y~' or '~r~'
                local tagSuffix = data.isCombatLog and ' ~y~[COMBAT LOG]' or ''
                DrawText3D(
                    pedCoords + vec3(0, 0, 1.15),
                    ('%s%s~w~ left the server (%s)%s'):format(
                        tagColor, data.charName, data.leftAt, tagSuffix
                    ),
                    0.30
                )

                -- ── Interaction prompt (close range) ──
                if dist < Config.LeavePed.interactDist then
                    DrawText3D(pedCoords + vec3(0, 0, 0.90), '~b~[E]~w~ Inspect', 0.26)

                    if IsControlJustPressed(0, Config.LeavePed.interactKey) then
                        SendNUIMessage({ action = 'open', data = data })
                        SetNuiFocus(true, true)
                    end
                end

                Wait(0) -- per-frame rendering while in range
            else
                Wait(250) -- nearby but just outside draw distance
            end
        else
            Wait(500) -- no ghost ped anywhere near — nearly free
        end
    end
end)

-- ════════════════════════════════════════════════════════
--  NUI CALLBACK: Card closed
-- ════════════════════════════════════════════════════════
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)
