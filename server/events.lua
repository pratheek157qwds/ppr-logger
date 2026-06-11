--[[
    ppr-logger · server/events.lua
    ────────────────────────────────
    Built-in log events: join, chat, and death receiver.
    Each handler formats data and calls LogInternal (from webhook.lua).

    Security note: In the death event, the VICTIM is always `source` — 
    never trust a client-sent victim id. Clients can only reliably
    report about themselves.
]]

-- ════════════════════════════════════════════════════════
--  JOIN LOG
-- ════════════════════════════════════════════════════════
AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    local ids = GetIdentifiersTable(src)

    local fields = {}
    for _, idType in ipairs(Config.Identifiers) do
        if ids[idType] then
            fields[#fields + 1] = {
                name   = idType:upper(),
                value  = '`' .. ids[idType] .. '`',
                inline = false,
            }
        end
    end

    if Config.LogIP and ids.ip and ids.ip ~= 'unknown' then
        fields[#fields + 1] = {
            name   = 'IP',
            value  = '||`' .. ids.ip .. '`||',
            inline = false,
        }
    end

    LogInternal('joins', '📥 Player Connecting',
        ('**%s** is connecting to the server.'):format(name), 'green', fields)
end)

-- ════════════════════════════════════════════════════════
--  CHAT LOG
-- ════════════════════════════════════════════════════════
AddEventHandler('chatMessage', function(src, _, message)
    -- Ignore console / system messages (source ≤ 0)
    if not src or src <= 0 then return end

    -- Sanitize message to prevent Discord embed injection
    local safeMsg = message
    if safeMsg then
        safeMsg = safeMsg:gsub('@everyone', '`@everyone`')
        safeMsg = safeMsg:gsub('@here', '`@here`')
    end

    LogInternal('chat', '💬 Chat Message',
        ('**%s** (id %d):\n>>> %s'):format(
            GetPlayerName(src) or 'Unknown', src, safeMsg or ''
        ), 'blue')
end)

-- ════════════════════════════════════════════════════════
--  DEATH LOG (fired by client/death.lua)
-- ════════════════════════════════════════════════════════
RegisterNetEvent('ppr-logger:server:playerDied', function(killerServerId, deathCoords, weaponHash)
    local src = source -- ALWAYS use source for the victim

    -- Validate coords
    if not deathCoords or type(deathCoords) ~= 'vector3' then
        -- Client sent bad data — use ped coords as fallback
        local ped = GetPlayerPed(src)
        deathCoords = ped and GetEntityCoords(ped) or vector3(0, 0, 0)
    end

    -- Resolve killer info
    local killerText = 'Environment / Suicide'
    if killerServerId and type(killerServerId) == 'number'
       and killerServerId > 0 and GetPlayerName(killerServerId) then
        killerText = ('**%s** (id %d)'):format(GetPlayerName(killerServerId), killerServerId)
    end

    local fields = {
        { name = 'Killer',  value = killerText, inline = true },
        { name = 'Coords',  value = ('%.1f, %.1f, %.1f'):format(deathCoords.x, deathCoords.y, deathCoords.z), inline = true },
    }

    -- Weapon hash (if client sent it)
    if weaponHash and type(weaponHash) == 'number' then
        fields[#fields + 1] = { name = 'Weapon Hash', value = ('`0x%X`'):format(weaponHash), inline = true }
    end

    LogInternal('deaths', '💀 Player Died',
        ('**%s** (id %d) has died.'):format(GetCharacterName(src), src), 'orange', fields)
end)
