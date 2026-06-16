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

local dressedPeds = {}
local nearbyGhost = nil

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

local function SafeLoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function SafeLoadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasModelLoaded(model)
end

local function DressGhostPed(ped)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)

    local animCfg = Config.LeavePed.anim
    if SafeLoadAnimDict(animCfg.dict) then
        TaskPlayAnim(ped, animCfg.dict, animCfg.name,
            8.0, -8.0, -1, 1, 0, false, false, false)
    end

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

    dressedPeds[ped] = board or true
end

CreateThread(function()
    while true do
        local myCoords = GetEntityCoords(PlayerPedId())
        local closestPed = nil
        local closestDist = Config.LeavePed.drawDist

        for _, ped in ipairs(GetGamePool('CPed')) do
            local data = Entity(ped).state.leaveData

            if data then
                if not dressedPeds[ped] then
                    DressGhostPed(ped)
                end

                local dist = #(myCoords - GetEntityCoords(ped))
                if dist < closestDist then
                    closestDist = dist
                    closestPed  = ped
                end
            end
        end

        nearbyGhost = closestPed

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

local function DrawBoardText3D(coords, text, scale)
    scale = scale or 0.16
    SetTextScale(scale, scale)
    SetTextFont(2)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 240)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

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
                    if dist < 8.0 and board and board ~= true and DoesEntityExist(board) then
                        if boardScaleform and HasScaleformMovieLoaded(boardScaleform) and renderTarget then
                            local displayName = tostring(data.charName):upper()
                            local cid = data.citizenId or "UNKNOWN"
                            if cid == 'N/A' or cid == '' then cid = "UNKNOWN" end

                            BeginScaleformMovieMethod(boardScaleform, "SET_BOARD")
                            PushScaleformMovieMethodParameterString("")
                            PushScaleformMovieMethodParameterString(displayName)
                            PushScaleformMovieMethodParameterString(tostring(cid):upper())
                            PushScaleformMovieMethodParameterString("")
                            PushScaleformMovieMethodParameterInt(0)
                            PushScaleformMovieMethodParameterInt(0)
                            PushScaleformMovieMethodParameterInt(0)
                            EndScaleformMovieMethod()

                            SetTextRenderId(renderTarget)
                            DrawScaleformMovie(boardScaleform, 0.405, 0.38, 0.85, 0.85, 255, 255, 255, 255, 0)
                            SetTextRenderId(GetDefaultScriptRendertargetRenderId())
                        end
                    end

                    if ped == nearbyGhost and dist < Config.LeavePed.interactDist then
                        DrawText3D(pedCoords + vec3(0, 0, 0.90), '~b~[E]~w~ Inspect', 0.26)

                        if IsControlJustPressed(0, Config.LeavePed.interactKey) then
                            SendNUIMessage({ action = 'open', data = data })
                            SetNuiFocus(true, true)
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

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
