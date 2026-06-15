--[[
    ppr-logger · server/leaveped.lua
    ──────────────────────────────────
    The signature feature: ghost ped + combat-log detection.

    Flow:
    1. playerJoining    → record join time
    2. damage event     → track last-damage timestamp (for combat-log detection)
    3. playerDropped    → capture everything, send Discord embed, spawn ghost ped
    4. Statebag         → attach public-safe data to ped (NO IP — ever)
    5. SetTimeout       → auto-despawn after configured time
    6. onResourceStop   → clean up all ghost peds (no orphans)
]]

local activePeds  = {}   -- netId → ped handle (for cleanup)
local joinTimes   = {}   -- src → GetGameTimer() at join
local lastDamage  = {}   -- src → { time = ms, attackerSrc = id }
local lastDead    = {}   -- src → true if player was dead at last check

-- ════════════════════════════════════════════════════════
--  JOIN TIME TRACKING
-- ════════════════════════════════════════════════════════
AddEventHandler('playerJoining', function()
    local src = source
    joinTimes[src] = GetGameTimer()
end)

-- Also handle players already connected when the resource (re)starts
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and not joinTimes[src] then
            joinTimes[src] = GetGameTimer()
        end
    end
end)

-- ════════════════════════════════════════════════════════
--  COMBAT-LOG DETECTION: DAMAGE TRACKING
-- ════════════════════════════════════════════════════════
-- Client sends this event when they take damage from another player.
-- We track the timestamp + attacker so we can flag disconnects in combat.
RegisterNetEvent('ppr-logger:server:playerDamaged', function(attackerServerId)
    local src = source
    if not src or src <= 0 then return end

    lastDamage[src] = {
        time        = GetGameTimer(),
        attackerSrc = attackerServerId or -1,
    }
end)

-- Track if player is currently dead (reported by client)
RegisterNetEvent('ppr-logger:server:playerDeathState', function(isDead)
    local src = source
    if not src or src <= 0 then return end
    lastDead[src] = isDead or false
end)

--- Determines the disconnect type based on the reason string.
--- Returns: 'quit', 'timeout', 'kicked', 'crash', or 'unknown'
---@param reason string
---@return string type
---@return string label  human-readable label
local function ClassifyDisconnect(reason)
    if not reason then return 'unknown', 'Unknown' end
    local r = reason:lower()

    if r:find('exiting') or r:find('quit') or r:find('disconnected') then
        return 'quit', '🚪 Quit'
    elseif r:find('timed out') or r:find('timeout') or r:find('connection lost') then
        return 'timeout', '⏱️ Timed Out'
    elseif r:find('kicked') or r:find('banned') then
        return 'kicked', '🔨 Kicked/Banned'
    elseif r:find('reliable') or r:find('overflow') or r:find('fatal') then
        return 'crash', '💥 Crash'
    end

    return 'unknown', '❓ Unknown'
end

--- Checks if a disconnect looks like a combat log.
---@param src number
---@param disconnectType string
---@return boolean isCombatLog
---@return string|nil attackerName
local function IsCombatLog(src, disconnectType)
    if not Config.CombatLog.enabled then return false, nil end

    -- Check if player was dead when they left
    if Config.CombatLog.flagIfDead and lastDead[src] then
        return true, nil
    end

    -- Check if player took damage recently
    local dmg = lastDamage[src]
    if dmg then
        local elapsed = GetGameTimer() - dmg.time
        if elapsed <= Config.CombatLog.combatWindow then
            local attackerName = nil
            if dmg.attackerSrc > 0 then
                attackerName = GetPlayerName(dmg.attackerSrc)
            end
            return true, attackerName
        end
    end

    return false, nil
end

-- ════════════════════════════════════════════════════════
--  MAIN: PLAYER DROPPED & SIMULATION
-- ════════════════════════════════════════════════════════

local function TriggerPlayerDisconnect(src, reason, isSimulated)
    -- ── 1) CAPTURE ──
    -- The player's ped still exists during this event — that's the trick.
    -- We grab everything we need before it despawns.
    local playerPed = GetPlayerPed(src)
    if not playerPed or playerPed == 0 then
        -- Edge case: player never fully spawned (dropped during loading)
        if not isSimulated then
            joinTimes[src]  = nil
            lastDamage[src] = nil
            lastDead[src]   = nil
        end
        return
    end

    local coords   = GetEntityCoords(playerPed)
    local heading  = GetEntityHeading(playerPed)
    local model    = GetEntityModel(playerPed)
    local ids      = GetIdentifiersTable(src)
    local charName = GetCharacterName(src)
    local accName  = GetPlayerName(src) or 'Unknown'
    local session  = joinTimes[src]
        and FormatDuration(GetGameTimer() - joinTimes[src])
        or 'unknown'

    local disconnectType, disconnectLabel = ClassifyDisconnect(reason)
    local combatLog, attackerName = IsCombatLog(src, disconnectType)
    local wasDead = lastDead[src] or false

    -- Clean up tracking tables
    if not isSimulated then
        joinTimes[src]  = nil
        lastDamage[src] = nil
        lastDead[src]   = nil
    end

    -- ── 2) DISCORD LOG (full data, including IP — staff-only) ──
    local title = combatLog
        and (isSimulated and '⚠️ POSSIBLE COMBAT LOG [TEST]' or '⚠️ POSSIBLE COMBAT LOG')
        or (isSimulated and '📤 Player Left [TEST]' or '📤 Player Left')

    local embedColor = combatLog and 'yellow' or 'red'

    local fields = {
        { name = 'Character',   value = charName,         inline = true  },
        { name = 'Account',     value = accName,           inline = true  },
        { name = 'Session',     value = session,           inline = true  },
        { name = 'Disconnect',  value = disconnectLabel,   inline = true  },
        { name = 'Reason',      value = reason or 'unknown', inline = false },
        { name = 'Last Coords', value = ('%.1f, %.1f, %.1f'):format(coords.x, coords.y, coords.z), inline = false },
    }

    -- Combat log extra info
    if combatLog then
        local combatInfo
        if wasDead then
            combatInfo = 'Player disconnected while dead'
        else
            combatInfo = 'Player disconnected while in combat'
            if attackerName then
                combatInfo = combatInfo .. (' (last attacked by: **%s**)'):format(attackerName)
            end
        end
        fields[#fields + 1] = { name = '⚠️ Combat Log', value = combatInfo, inline = false }
    end

    -- Identifiers
    for _, idType in ipairs(Config.Identifiers) do
        if ids[idType] then
            fields[#fields + 1] = { name = idType:upper(), value = '`' .. ids[idType] .. '`', inline = false }
        end
    end

    -- IP (Discord only — spoiler-tagged for extra caution)
    if Config.LogIP and ids.ip and ids.ip ~= 'unknown' then
        fields[#fields + 1] = { name = 'IP', value = '||`' .. ids.ip .. '`||', inline = false }
    end

    -- Send to appropriate channel
    local channel = combatLog and Config.CombatLog.webhookChannel or 'leaves'
    LogInternal(channel, title, ('**%s** %s.'):format(charName, isSimulated and 'simulated disconnection' or 'disconnected'), embedColor, fields)

    -- Also send to 'leaves' if combat log uses a separate channel
    if combatLog and Config.CombatLog.webhookChannel ~= 'leaves' then
        LogInternal('leaves', title, ('**%s** %s.'):format(charName, isSimulated and 'simulated disconnection' or 'disconnected'), embedColor, fields)
    end

    -- ── 3) SPAWN GHOST PED ──
    if not Config.LeavePed.enabled then return end

    -- Server-side CreatePed (requires OneSync)
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, heading, true, true)

    -- CreatePed is async: wait until it actually exists in the world
    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(ped) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not DoesEntityExist(ped) then
        -- Model failed (e.g. addon ped from a stopped resource) → retry with fallback
        ped = CreatePed(4, Config.LeavePed.fallbackModel, coords.x, coords.y, coords.z - 1.0, heading, true, true)
        timeout = GetGameTimer() + 5000
        while not DoesEntityExist(ped) and GetGameTimer() < timeout do
            Wait(50)
        end
        if not DoesEntityExist(ped) then
            print('^1[ppr-logger]^7 Failed to spawn ghost ped — even fallback model failed')
            return
        end
    end

    -- ── 4) STATEBAG ──
    -- Attach public-safe data to the ped entity.
    -- ⚠️  NO IP ADDRESS — this replicates to ALL clients.
    local publicIds = {}
    for _, idType in ipairs(Config.Identifiers) do
        publicIds[idType] = ids[idType]
    end

    Entity(ped).state:set('leaveData', {
        charName       = charName .. (isSimulated and ' [TEST]' or ''),
        citizenId      = GetCitizenID(src),
        accName        = accName,
        reason         = (reason or 'unknown') .. (isSimulated and ' (SIMULATED)' or ''),
        session        = session,
        leftAt         = os.date('%H:%M:%S'),
        disconnectType = disconnectType,
        isCombatLog    = combatLog,
        ids            = publicIds,
    }, true) -- true = replicated to clients

    local netId = NetworkGetNetworkIdFromEntity(ped)
    activePeds[netId] = ped

    -- Send client confirmation chat message if simulated
    if isSimulated then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 0, 255, 0 },
            multiline = true,
            args = { 'PPR Logger', 'Simulated disconnect triggered! A ghost ped has been spawned at your location and logged to Discord.' }
        })
    end

    -- ── 5) DESPAWN TIMER ──
    SetTimeout(Config.LeavePed.despawnTime, function()
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
        activePeds[netId] = nil
    end)
end

AddEventHandler('playerDropped', function(reason)
    TriggerPlayerDisconnect(source, reason, false)
end)

if Config.Debug then
    RegisterCommand('testdisconnect', function(source, args, rawCommand)
        if source == 0 then
            print('^1[ppr-logger]^7 This command must be run by a player in-game.')
            return
        end
        TriggerPlayerDisconnect(source, 'Simulated Disconnect (Test Command)', true)
    end, false)
end

-- ════════════════════════════════════════════════════════
--  CLEANUP: No orphan peds on resource restart
-- ════════════════════════════════════════════════════════
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for netId, ped in pairs(activePeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    activePeds = {}
end)
