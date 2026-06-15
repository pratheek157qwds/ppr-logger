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

local boardScaleform = nil
local renderTarget = nil

CreateThread(function()
    boardScaleform = RequestScaleformMovie("MUGSHOT_BOARD_01")
    while not HasScaleformMovieLoaded(boardScaleform) do
        Wait(10)
    end
end)

CreateThread(function()
    local modelHash = `prop_police_id_text`
    if not IsNamedRendertargetRegistered("ID_Text") then
        RegisterNamedRendertarget("ID_Text", false)
    end
    if not IsNamedRendertargetLinked(modelHash) then
        LinkNamedRendertarget(modelHash)
    end
    renderTarget = GetNamedRendertargetRenderId("ID_Text")
end)

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
--  HELPERS FOR MUGSHOT BOARD
-- ════════════════════════════════════════════════════════

--- Draws text on the mugshot board using custom styling.
---@param coords vector3
---@param text   string
---@param scale  number|nil
local function DrawBoardText3D(coords, text, scale)
    scale = scale or 0.16
    SetTextScale(scale, scale)
    SetTextFont(2) -- Monospace font fits the physical board style perfectly
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 240)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- ════════════════════════════════════════════════════════
--  LOOP 2: ADAPTIVE INTERACTION & RENDERING (per-frame when close)
-- ════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        local myCoords = GetEntityCoords(PlayerPedId())
        local pedsToDraw = {}

        for ped, board in pairs(dressedPeds) do
            if DoesEntityExist(ped) then
                local pedCoords = GetEntityCoords(ped)
                local dist = #(myCoords - pedCoords)
                if dist < Config.LeavePed.drawDist then
                    table.insert(pedsToDraw, {
                        ped = ped,
                        board = board,
                        coords = pedCoords,
                        dist = dist
                    })
                end
            end
        end

        if #pedsToDraw > 0 then
            for _, info in ipairs(pedsToDraw) do
                local ped = info.ped
                local board = info.board
                local pedCoords = info.coords
                local dist = info.dist
                local data = Entity(ped).state.leaveData

                if data then
                    -- ── Mugshot Board Text (drawn using Scaleform on prop_police_id_text) ──
                    if dist < 8.0 and board and board ~= true and DoesEntityExist(board) then
                        if boardScaleform and HasScaleformMovieLoaded(boardScaleform) and renderTarget then
                            local displayName = tostring(data.charName):upper()
                            local cid = data.citizenId or "UNKNOWN"
                            if cid == 'N/A' or cid == '' then cid = "UNKNOWN" end

                            -- Update scaleform data
                            BeginScaleformMovieMethod(boardScaleform, "SET_BOARD")
                            PushScaleformMovieMethodParameterString("") -- Title/Age (top)
                            PushScaleformMovieMethodParameterString(displayName) -- Name (center)
                            PushScaleformMovieMethodParameterString(tostring(cid):upper()) -- Registration/CID (bottom)
                            PushScaleformMovieMethodParameterString("") -- Header (very top)
                            PushScaleformMovieMethodParameterInt(0)
                            PushScaleformMovieMethodParameterInt(0)
                            PushScaleformMovieMethodParameterInt(0)
                            EndScaleformMovieMethod()

                            -- Draw on render target
                            SetTextRenderId(renderTarget)
                            DrawScaleformMovie(boardScaleform, 0.405, 0.38, 0.85, 0.85, 255, 255, 255, 255, 0)
                            SetTextRenderId(GetDefaultScriptRendertargetRenderId())
                        end
                    end

                    -- ── Interaction prompt (closest ghost only) ──
                    if ped == nearbyGhost and dist < Config.LeavePed.interactDist then
                        DrawText3D(pedCoords + vec3(0, 0, 0.90), '~b~[E]~w~ Inspect', 0.26)

                        if IsControlJustPressed(0, Config.LeavePed.interactKey) then
                            SendNUIMessage({ action = 'open', data = data })
                            SetNuiFocus(true, true)
                        end
                    end
                end
            end
            Wait(0) -- per-frame rendering while close
        else
            Wait(500) -- idle wait when no ghost peds nearby
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

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if boardScaleform then
        SetScaleformMovieAsNoLongerNeeded(boardScaleform)
    end
end)
