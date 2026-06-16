--[[
    ppr-logger · server/events.lua
    ────────────────────────────────
    Built-in log events: join, chat, and death receiver.
    Each handler formats data and calls LogInternal (from webhook.lua).

    Security note: In the death event, the VICTIM is always `source` — 
    never trust a client-sent victim id. Clients can only reliably
    report about themselves.
]]

AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    local ids = GetIdentifiersTable(src)

    local fields = {}
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
        fields[#fields + 1] = {
            name   = '🌐 IP ADDRESS',
            value  = '||`' .. ids.ip .. '`||',
            inline = false,
        }
    end

    LogInternal('joins', '📥 Player Connecting',
        ('**%s** is connecting to the server.'):format(name), 'green', fields)
end)

AddEventHandler('chatMessage', function(src, _, message)
    if not src or src <= 0 then return end

    local safeMsg = message
    if safeMsg then
        safeMsg = safeMsg:gsub('@everyone', '`@everyone`')
        safeMsg = safeMsg:gsub('@here', '`@here`')
    end

    local name = GetPlayerName(src) or 'Unknown'
    local fields = {
        { name = '👤 Sender', value = ('**%s**'):format(name), inline = true },
        { name = '🆔 Server ID', value = ('`%d`'):format(src), inline = true }
    }

    LogInternal('chat', '💬 Chat Message',
        ('>>> %s'):format(safeMsg or ''), 'blue', fields)
end)

RegisterNetEvent('ppr-logger:server:requestDeathWebhook', function(killerServerId, deathCoords, weaponHash)
    local src = source
    local webhookUrl = Config.Webhooks['deaths']
    TriggerClientEvent('ppr-logger:client:takeDeathScreenshot', src, webhookUrl, killerServerId, deathCoords, weaponHash)
end)

RegisterNetEvent('ppr-logger:server:playerDied', function(killerServerId, deathCoords, weaponHash, imageUrl)
    local src = source

    if not deathCoords or type(deathCoords) ~= 'vector3' then
        local ped = GetPlayerPed(src)
        deathCoords = ped and GetEntityCoords(ped) or vector3(0, 0, 0)
    end

    local killerText = 'Environment / Suicide'
    if killerServerId and type(killerServerId) == 'number'
       and killerServerId > 0 and GetPlayerName(killerServerId) then
        killerText = ('**%s** (id %d)'):format(GetPlayerName(killerServerId), killerServerId)
    end

    local resolvedWeapon = GetWeaponName(weaponHash)

    local fields = {
        { name = '⚔️ Killer',  value = killerText, inline = true },
        { name = '🔫 Weapon',  value = resolvedWeapon, inline = true },
        { name = '📍 Coords',  value = ('`%.1f, %.1f, %.1f`'):format(deathCoords.x, deathCoords.y, deathCoords.z), inline = true },
    }

    LogInternal('deaths', '💀 Player Died',
        ('**%s** (id %d) has died.'):format(GetCharacterName(src), src), 'orange', fields, imageUrl)
end)
