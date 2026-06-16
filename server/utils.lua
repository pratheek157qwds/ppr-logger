--[[
    ppr-logger · server/utils.lua
    ──────────────────────────────
    Global helper functions used by every other server file.
    Loaded FIRST in the manifest so these globals exist when needed.
]]

local Weapons = {
    [`WEAPON_UNARMED`] = 'Fists 👊',
    [`WEAPON_KNIFE`] = 'Knife 🔪',
    [`WEAPON_NIGHTSTICK`] = 'Nightstick 🥖',
    [`WEAPON_HAMMER`] = 'Hammer 🔨',
    [`WEAPON_BAT`] = 'Baseball Bat 🏏',
    [`WEAPON_GOLFCLUB`] = 'Golf Club 🏌️',
    [`WEAPON_CROWBAR`] = 'Crowbar 🔧',
    [`WEAPON_PISTOL`] = 'Pistol 🔫',
    [`WEAPON_COMBATPISTOL`] = 'Combat Pistol 🔫',
    [`WEAPON_APPISTOL`] = 'AP Pistol 🔫',
    [`WEAPON_PISTOL50`] = 'Pistol .50 🔫',
    [`WEAPON_MICROSMG`] = 'Micro SMG 🔫',
    [`WEAPON_SMG`] = 'SMG 🔫',
    [`WEAPON_ASSAULTSMG`] = 'Assault SMG 🔫',
    [`WEAPON_COMBATPDW`] = 'Combat PDW 🔫',
    [`WEAPON_ASSAULTRIFLE`] = 'Assault Rifle 🔫',
    [`WEAPON_CARBINERIFLE`] = 'Carbine Rifle 🔫',
    [`WEAPON_ADVANCEDRIFLE`] = 'Advanced Rifle 🔫',
    [`WEAPON_SPECIALCARBINE`] = 'Special Carbine 🔫',
    [`WEAPON_BULLPUPRIFLE`] = 'Bullpup Rifle 🔫',
    [`WEAPON_MG`] = 'MG 🔫',
    [`WEAPON_COMBATMG`] = 'Combat MG 🔫',
    [`WEAPON_PUMPSHOTGUN`] = 'Pump Shotgun 🔫',
    [`WEAPON_SAWNOFFSHOTGUN`] = 'Sawnoff Shotgun 🔫',
    [`WEAPON_ASSAULTSHOTGUN`] = 'Assault Shotgun 🔫',
    [`WEAPON_BULLPUPSHOTGUN`] = 'Bullpup Shotgun 🔫',
    [`WEAPON_HEAVYSHOTGUN`] = 'Heavy Shotgun 🔫',
    [`WEAPON_SNIPERRIFLE`] = 'Sniper Rifle 🎯',
    [`WEAPON_HEAVYSNIPER`] = 'Heavy Sniper 🎯',
    [`WEAPON_MARKSMANRIFLE`] = 'Marksman Rifle 🎯',
    [`WEAPON_GRENADELAUNCHER`] = 'Grenade Launcher 💥',
    [`WEAPON_RPG`] = 'RPG 🚀',
    [`WEAPON_MINIGUN`] = 'Minigun 🔫',
    [`WEAPON_GRENADE`] = 'Grenade 💣',
    [`WEAPON_MOLOTOV`] = 'Molotov 🔥',
    [`WEAPON_STICKYBOMB`] = 'Sticky Bomb 💣',
    [`WEAPON_PROXIMINE`] = 'Proximity Mine 💣',
    [`WEAPON_SMOKEGRENADE`] = 'Smoke Grenade 💨',
    [`WEAPON_RUN_OVER_BY_CAR`] = 'Run over by vehicle 🚗',
    [`WEAPON_RAMMED_BY_CAR`] = 'Rammed by vehicle 🚗',
    [`WEAPON_FALL`] = 'Fall Damage 🪂',
    [`WEAPON_HIT_BY_WATER_CANNON`] = 'Water Cannon 💦',
    [`WEAPON_EXPLO`] = 'Explosion 💥',
    [`WEAPON_HELI_CRASH`] = 'Helicopter Crash 🚁',
    [`WEAPON_FIRE`] = 'Burned 🔥',
    [`WEAPON_DROWNING`] = 'Drowned 🌊',
    [`WEAPON_DROWNING_IN_VEHICLE`] = 'Drowned in Vehicle 🌊🚗',
}

function GetWeaponName(hash)
    if not hash or hash == 0 then return 'Unknown ❓' end
    if Weapons[hash] then return Weapons[hash] end
    local unsignedHash = hash < 0 and (hash + 0x100000000) or hash
    if Weapons[unsignedHash] then return Weapons[unsignedHash] end
    return ('Unknown (`0x%X`) ❓'):format(hash)
end

function GetIdentifiersTable(src)
    local ids = {}
    local numIds = GetNumPlayerIdentifiers(src)

    for i = 0, numIds - 1 do
        local raw = GetPlayerIdentifier(src, i)
        if raw then
            local idType, _ = raw:match('^([^:]+):(.+)$')
            if idType then
                ids[idType] = raw
            end
        end
    end

    local endpoint = GetPlayerEndpoint(src)
    if endpoint then
        ids.ip = endpoint:match('^([^:]+)') or endpoint
    else
        ids.ip = 'unknown'
    end

    return ids
end

function GetCharacterName(src)
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

    return GetPlayerName(src) or 'Unknown'
end

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

function GetCitizenID(src)
    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(exports['qb-core'].GetCoreObject, exports['qb-core'])
        if ok and QBCore then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player and Player.PlayerData then
                return Player.PlayerData.citizenid or 'UNKNOWN'
            end
        end
    end

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
