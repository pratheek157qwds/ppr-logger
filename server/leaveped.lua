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

local activePeds  = {}
local joinTimes   = {}
local lastDamage  = {}
local lastDead    = {}

AddEventHandler('playerJoining', function()
    local src = source
    joinTimes[src] = GetGameTimer()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and not joinTimes[src] then
            joinTimes[src] = GetGameTimer()
        end
    end
end)

RegisterNetEvent('ppr-logger:server:playerDamaged', function(attackerServerId)
    local src = source
    if not src or src <= 0 then return end

    lastDamage[src] = {
        time        = GetGameTimer(),
        attackerSrc = attackerServerId or -1,
    }
end)

RegisterNetEvent('ppr-logger:server:playerDeathState', function(isDead)
    local src = source
    if not src or src <= 0 then return end
    lastDead[src] = isDead or false
end)

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

local function IsCombatLog(src, disconnectType)
    if not Config.CombatLog.enabled then return false, nil end

    if Config.CombatLog.flagIfDead and lastDead[src] then
        return true, nil
    end

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

local function TriggerPlayerDisconnect(src, reason, isSimulated)
    local playerPed = GetPlayerPed(src)
    if not playerPed or playerPed == 0 then
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

    if not isSimulated then
        joinTimes[src]  = nil
        lastDamage[src] = nil
        lastDead[src]   = nil
    end

    local title = combatLog
        and (isSimulated and '⚠️ POSSIBLE COMBAT LOG [TEST]' or '⚠️ POSSIBLE COMBAT LOG')
        or (isSimulated and '📤 Player Left [TEST]' or '📤 Player Left')

    local embedColor = combatLog and 'yellow' or 'red'

    local fields = {
        { name = '👤 Character',   value = ('**%s**'):format(charName),         inline = true  },
        { name = '🖥️ Account',     value = ('`%s`'):format(accName),           inline = true  },
        { name = '⏳ Session Time', value = ('`%s`'):format(session),           inline = true  },
        { name = '🚪 Disconnect',  value = disconnectLabel,                     inline = true  },
        { name = '📍 Last Coords', value = ('`%.1f, %.1f, %.1f`'):format(coords.x, coords.y, coords.z), inline = true },
    }

    fields[#fields + 1] = { name = '📝 Reason', value = ('`%s`'):format(reason or 'unknown'), inline = false }

    if combatLog then
        local combatInfo
        if wasDead then
            combatInfo = '💀 **Player disconnected while dead**'
        else
            combatInfo = '⚔️ **Player disconnected while in combat**'
            if attackerName then
                combatInfo = combatInfo .. ('\n💥 Last attacked by: **%s**'):format(attackerName)
            end
        end
        fields[#fields + 1] = { name = '⚠️ COMBAT LOG WARNING', value = combatInfo, inline = false }
    end

    for _, idType in ipairs(Config.Identifiers) do
        if ids[idType] then
            local emoji = '🔹'
            local val = '`' .. ids[idType] .. '`'
            if idType == 'license' then
                emoji = '🔑'
            elseif idType == 'steam' then
                emoji = '🎮'
            elseif idType == 'discord' then
                emoji = '💬'
                local discordId = ids[idType]:match("discord:(%d+)")
                if discordId then
                    val = ('<@%s> (%s)'):format(discordId, val)
                end
            elseif idType == 'fivem' then
                emoji = '⚡'
            end

            fields[#fields + 1] = {
                name   = emoji .. ' ' .. idType:upper(),
                value  = val,
                inline = false,
            }
        end
    end

    if Config.LogIP and ids.ip and ids.ip ~= 'unknown' then
        fields[#fields + 1] = { name = '🌐 IP ADDRESS', value = '||`' .. ids.ip .. '`||', inline = false }
    end

    local channel = combatLog and Config.CombatLog.webhookChannel or 'leaves'
    LogInternal(channel, title, ('**%s** %s.'):format(charName, isSimulated and 'simulated disconnection' or 'disconnected'), embedColor, fields)

    if combatLog and Config.CombatLog.webhookChannel ~= 'leaves' then
        LogInternal('leaves', title, ('**%s** %s.'):format(charName, isSimulated and 'simulated disconnection' or 'disconnected'), embedColor, fields)
    end

    if not Config.LeavePed.enabled then return end

    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, heading, true, true)

    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(ped) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not DoesEntityExist(ped) then
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
    }, true)

    local netId = NetworkGetNetworkIdFromEntity(ped)
    activePeds[netId] = ped

    if isSimulated then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 0, 255, 0 },
            multiline = true,
            args = { 'PPR Logger', 'Simulated disconnect triggered! A ghost ped has been spawned at your location and logged to Discord.' }
        })
    end

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

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for netId, ped in pairs(activePeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    activePeds = {}
end)
