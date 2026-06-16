--[[
    ppr-logger · server/utils.lua
    ──────────────────────────────
    Global helper functions used by every other server file.
    Loaded FIRST in the manifest so these globals exist when needed.
]]

local Weapons = {
    -- Melee
    [`WEAPON_UNARMED`] = 'Fists 👊',
    [`WEAPON_KNIFE`] = 'Knife 🔪',
    [`WEAPON_NIGHTSTICK`] = 'Nightstick 🥖',
    [`WEAPON_HAMMER`] = 'Hammer 🔨',
    [`WEAPON_BAT`] = 'Baseball Bat 🏏',
    [`WEAPON_GOLFCLUB`] = 'Golf Club 🏌️',
    [`WEAPON_CROWBAR`] = 'Crowbar 🔧',
    [`WEAPON_DAGGER`] = 'Dagger 🗡️',
    [`WEAPON_BOTTLE`] = 'Broken Bottle 🍾',
    [`WEAPON_FLASHLIGHT`] = 'Flashlight 🔦',
    [`WEAPON_HATCHET`] = 'Hatchet 🪓',
    [`WEAPON_KNUCKLE`] = 'Brass Knuckles 👊',
    [`WEAPON_MACHETE`] = 'Machete 🔪',
    [`WEAPON_SWITCHBLADE`] = 'Switchblade 🔪',
    [`WEAPON_WRENCH`] = 'Wrench 🔧',
    [`WEAPON_BATTLEAXE`] = 'Battle Axe 🪓',
    [`WEAPON_POOLCUE`] = 'Pool Cue 🎱',
    [`WEAPON_STONE_HATCHET`] = 'Stone Hatchet 🪓',
    [`WEAPON_CANDYCANE`] = 'Candy Cane 🍭',

    -- Handguns
    [`WEAPON_PISTOL`] = 'Pistol 🔫',
    [`WEAPON_PISTOL_MK2`] = 'Pistol Mk2 🔫',
    [`WEAPON_COMBATPISTOL`] = 'Combat Pistol 🔫',
    [`WEAPON_APPISTOL`] = 'AP Pistol 🔫',
    [`WEAPON_STUNGUN`] = 'Taser ⚡',
    [`WEAPON_STUNGUN_MP`] = 'Taser ⚡',
    [`WEAPON_PISTOL50`] = 'Pistol .50 🔫',
    [`WEAPON_SNSPISTOL`] = 'SNS Pistol 🔫',
    [`WEAPON_SNSPISTOL_MK2`] = 'SNS Pistol MK2 🔫',
    [`WEAPON_HEAVYPISTOL`] = 'Heavy Pistol 🔫',
    [`WEAPON_VINTAGEPISTOL`] = 'Vintage Pistol 🔫',
    [`WEAPON_FLAREGUN`] = 'Flare Gun 🔫',
    [`WEAPON_MARKSMANPISTOL`] = 'Marksman Pistol 🔫',
    [`WEAPON_REVOLVER`] = 'Heavy Revolver 🔫',
    [`WEAPON_REVOLVER_MK2`] = 'Heavy Revolver MK2 🔫',
    [`WEAPON_DOUBLEACTION`] = 'Double Action Revolver 🔫',
    [`WEAPON_RAYPISTOL`] = 'Up-n-Atomizer 🔫',
    [`WEAPON_CERAMICPISTOL`] = 'Ceramic Pistol 🔫',
    [`WEAPON_NAVYREVOLVER`] = 'Navy Revolver 🔫',
    [`WEAPON_GADGETPISTOL`] = 'Perico Pistol 🔫',
    [`WEAPON_PISTOLXM3`] = 'Pistol XM3 🔫',

    -- SMGs
    [`WEAPON_MICROSMG`] = 'Micro SMG 🔫',
    [`WEAPON_SMG`] = 'SMG 🔫',
    [`WEAPON_SMG_MK2`] = 'SMG MK2 🔫',
    [`WEAPON_ASSAULTSMG`] = 'Assault SMG 🔫',
    [`WEAPON_COMBATPDW`] = 'Combat PDW 🔫',
    [`WEAPON_MACHINEPISTOL`] = 'Machine Pistol 🔫',
    [`WEAPON_MINISMG`] = 'Mini SMG 🔫',
    [`WEAPON_RAYCARBINE`] = 'Unholy Hellbringer 🔫',

    -- Shotguns
    [`WEAPON_PUMPSHOTGUN`] = 'Pump Shotgun 🔫',
    [`WEAPON_PUMPSHOTGUN_MK2`] = 'Pump Shotgun MK2 🔫',
    [`WEAPON_SAWNOFFSHOTGUN`] = 'Sawnoff Shotgun 🔫',
    [`WEAPON_ASSAULTSHOTGUN`] = 'Assault Shotgun 🔫',
    [`WEAPON_BULLPUPSHOTGUN`] = 'Bullpup Shotgun 🔫',
    [`WEAPON_MUSKET`] = 'Musket 🔫',
    [`WEAPON_HEAVYSHOTGUN`] = 'Heavy Shotgun 🔫',
    [`WEAPON_DBSHOTGUN`] = 'Double-barrel Shotgun 🔫',
    [`WEAPON_AUTOSHOTGUN`] = 'Sweeper Shotgun 🔫',
    [`WEAPON_COMBATSHOTGUN`] = 'Combat Shotgun 🔫',

    -- Rifles
    [`WEAPON_ASSAULTRIFLE`] = 'Assault Rifle 🔫',
    [`WEAPON_ASSAULTRIFLE_MK2`] = 'Assault Rifle MK2 🔫',
    [`WEAPON_CARBINERIFLE`] = 'Carbine Rifle 🔫',
    [`WEAPON_CARBINERIFLE_MK2`] = 'Carbine Rifle MK2 🔫',
    [`WEAPON_ADVANCEDRIFLE`] = 'Advanced Rifle 🔫',
    [`WEAPON_SPECIALCARBINE`] = 'Special Carbine 🔫',
    [`WEAPON_SPECIALCARBINE_MK2`] = 'Special Carbine MK2 🔫',
    [`WEAPON_BULLPUPRIFLE`] = 'Bullpup Rifle 🔫',
    [`WEAPON_BULLPUPRIFLE_MK2`] = 'Bullpup Rifle MK2 🔫',
    [`WEAPON_COMPACTRIFLE`] = 'Compact Rifle 🔫',
    [`WEAPON_MILITARYRIFLE`] = 'Military Rifle 🔫',
    [`WEAPON_HEAVYRIFLE`] = 'Heavy Rifle 🔫',

    -- LMGs
    [`WEAPON_MG`] = 'MG 🔫',
    [`WEAPON_COMBATMG`] = 'Combat MG 🔫',
    [`WEAPON_COMBATMG_MK2`] = 'Combat MG MK2 🔫',
    [`WEAPON_GUSENBERG`] = 'Gusenberg Sweeper 🔫',

    -- Snipers
    [`WEAPON_SNIPERRIFLE`] = 'Sniper Rifle 🎯',
    [`WEAPON_HEAVYSNIPER`] = 'Heavy Sniper 🎯',
    [`WEAPON_HEAVYSNIPER_MK2`] = 'Heavy Sniper MK2 🎯',
    [`WEAPON_MARKSMANRIFLE`] = 'Marksman Rifle 🎯',
    [`WEAPON_MARKSMANRIFLE_MK2`] = 'Marksman Rifle MK2 🎯',

    -- Heavy
    [`WEAPON_GRENADELAUNCHER`] = 'Grenade Launcher 💥',
    [`WEAPON_RPG`] = 'RPG 🚀',
    [`WEAPON_MINIGUN`] = 'Minigun 🔫',
    [`WEAPON_FIREWORK`] = 'Firework Launcher 💥',
    [`WEAPON_RAILGUN`] = 'Railgun ⚡',
    [`WEAPON_RAILGUNXM3`] = 'Railgun XM3 ⚡',
    [`WEAPON_HOMINGLAUNCHER`] = 'Homing Launcher 🚀',
    [`WEAPON_COMPACTLAUNCHER`] = 'Compact Grenade Launcher 💥',
    [`WEAPON_RAYMINIGUN`] = 'Widowmaker 🔫',
    [`WEAPON_EMPLAUNCHER`] = 'EMP Launcher ⚡',

    -- Throwables
    [`WEAPON_GRENADE`] = 'Grenade 💣',
    [`WEAPON_BZGAS`] = 'BZ Gas 💨',
    [`WEAPON_MOLOTOV`] = 'Molotov 🔥',
    [`WEAPON_STICKYBOMB`] = 'Sticky Bomb 💣',
    [`WEAPON_PROXIMINE`] = 'Proximity Mine 💣',
    [`WEAPON_PIPEBOMB`] = 'Pipe Bomb 💣',
    [`WEAPON_SNOWBALL`] = 'Snowball ❄️',
    [`WEAPON_BALL`] = 'Baseball ⚾',
    [`WEAPON_SMOKEGRENADE`] = 'Smoke Grenade 💨',
    [`WEAPON_FLARE`] = 'Flare 🧨',

    -- Miscellaneous / Suicide
    [`WEAPON_RUN_OVER_BY_CAR`] = 'Run over by vehicle 🚗',
    [`WEAPON_RAMMED_BY_CAR`] = 'Rammed by vehicle 🚗',
    [`WEAPON_FALL`] = 'Fall Damage 🪂',
    [`WEAPON_HIT_BY_WATER_CANNON`] = 'Water Cannon 💦',
    [`WEAPON_EXPLO`] = 'Explosion 💥',
    [`WEAPON_HELI_CRASH`] = 'Helicopter Crash 🚁',
    [`WEAPON_FIRE`] = 'Burned 🔥',
    [`WEAPON_DROWNING`] = 'Drowned 🌊',
    [`WEAPON_DROWNING_IN_VEHICLE`] = 'Drowned in Vehicle 🌊🚗',
    [`WEAPON_PETROLCAN`] = 'Jerry Can ⛽',
    [`GADGET_PARACHUTE`] = 'Parachute 🪂',
    [`WEAPON_FIREEXTINGUISHER`] = 'Fire Extinguisher 🧯',
    [`WEAPON_HAZARDCAN`] = 'Hazardous Jerry Can ⛽',
    [`WEAPON_FERTILIZERCAN`] = 'Fertilizer Can ⛽',
    [`WEAPON_BARBED_WIRE`] = 'Barbed Wire 🚧',
    [`WEAPON_BLEEDING`] = 'Bleeding 🩸',
    [`WEAPON_ELECTRIC_FENCE`] = 'Electric Fence ⚡',
    [`WEAPON_EXHAUSTION`] = 'Exhaustion 💤',
    [`WEAPON_ANIMAL`] = 'Animal Mauled 🐾',
    [`WEAPON_COUGAR`] = 'Cougar Mauled 🐾',
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
