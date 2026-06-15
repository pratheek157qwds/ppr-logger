--[[
    ppr-logger · server/utils.lua
    ──────────────────────────────
    Global helper functions used by every other server file.
    Loaded FIRST in the manifest so these globals exist when needed.
]]

--- Returns a table of the player's identifiers, keyed by type.
--- Example output: { license = 'license:abc123', steam = 'steam:1100001...', ip = '1.2.3.4' }
---
--- We iterate the native identifier list AND grab IP separately via
--- GetPlayerEndpoint (on newer builds, IP is no longer in the identifier loop).
---
---@param src number  player server id
---@return table<string, string>
function GetIdentifiersTable(src)
    local ids = {}
    local numIds = GetNumPlayerIdentifiers(src)

    for i = 0, numIds - 1 do
        local raw = GetPlayerIdentifier(src, i) -- e.g. "steam:11000010abcdef"
        if raw then
            local idType, _ = raw:match('^([^:]+):(.+)$')
            if idType then
                ids[idType] = raw
            end
        end
    end

    -- IP comes from a dedicated native on newer server builds
    local endpoint = GetPlayerEndpoint(src)
    if endpoint then
        -- Strip port if present (e.g. "1.2.3.4:30120" → "1.2.3.4")
        ids.ip = endpoint:match('^([^:]+)') or endpoint
    else
        ids.ip = 'unknown'
    end

    return ids
end

--- Resolves the roleplay character name using whatever framework is running.
--- Detection order: ESX → QBCore → standalone (FiveM account name).
---
--- Uses GetResourceState() to check if a framework is active WITHOUT
--- adding a hard dependency in the manifest. This means the script works
--- on standalone, ESX, and QBCore servers with zero config changes.
---
---@param src number  player server id
---@return string
function GetCharacterName(src)
    -- ═══ ESX ═══
    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(exports['es_extended'].getSharedObject, exports['es_extended'])
        if ok and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                local name = xPlayer.getName()
                if name and name ~= '' then return name end
            end
        end
    end

    -- ═══ QBCore ═══
    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(exports['qb-core'].GetCoreObject, exports['qb-core'])
        if ok and QBCore then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player and Player.PlayerData and Player.PlayerData.charinfo then
                local ci = Player.PlayerData.charinfo
                local first = ci.firstname or ''
                local last  = ci.lastname or ''
                if first ~= '' or last ~= '' then
                    return ('%s %s'):format(first, last):gsub('^%s+', ''):gsub('%s+$', '')
                end
            end
        end
    end

    -- ═══ Standalone fallback ═══
    return GetPlayerName(src) or 'Unknown'
end

--- Formats a duration in milliseconds as a human-readable string.
--- e.g. 5520000 → "1h 32m"
---
---@param ms number  duration in milliseconds
---@return string
function FormatDuration(ms)
    if not ms or ms < 0 then return 'unknown' end
    local totalMins = math.floor(ms / 60000)
    local hours = math.floor(totalMins / 60)
    local mins  = totalMins % 60
    if hours > 0 then
        return ('%dh %02dm'):format(hours, mins)
    else
        return ('%dm'):format(mins)
    end
end

--- Resolves the roleplay citizen ID / character identifier.
---@param src number  player server id
---@return string
function GetCitizenID(src)
    -- ═══ QBCore ═══
    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(exports['qb-core'].GetCoreObject, exports['qb-core'])
        if ok and QBCore then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player and Player.PlayerData then
                return Player.PlayerData.citizenid or 'UNKNOWN'
            end
        end
    end

    -- ═══ ESX ═══
    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(exports['es_extended'].getSharedObject, exports['es_extended'])
        if ok and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                return xPlayer.identifier or 'UNKNOWN'
            end
        end
    end

    return 'N/A'
end
