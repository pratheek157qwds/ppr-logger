--[[
    ppr-logger · client/death.lua
    ──────────────────────────────
    Death detection + damage tracking for combat-log detection.

    Death watcher:
    - Detects own death once (flag prevents spam)
    - Resolves killer's server id
    - Reports weapon hash to server
    - Resets when revived/respawned

    Damage tracker:
    - Detects when player takes damage from another player
    - Reports to server for combat-log window tracking
    - Only fires once per second to avoid event spam
]]

local deathReported = false
local lastDamageReport = 0
local DAMAGE_REPORT_COOLDOWN = 1000 -- ms between damage reports

-- ════════════════════════════════════════════════════════
--  DEATH DETECTION
-- ════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local isDead = IsEntityDead(ped)

        if isDead and not deathReported then
            deathReported = true

            -- Resolve killer → server id (-1 if not a player)
            local killerEntity = GetPedSourceOfDeath(ped)
            local killerServerId = -1
            local weaponHash = GetPedCauseOfDeath(ped)

            if killerEntity and killerEntity ~= 0
               and IsEntityAPed(killerEntity)
               and IsPedAPlayer(killerEntity) then
                killerServerId = GetPlayerServerId(
                    NetworkGetPlayerIndexFromPed(killerEntity)
                )
            end

            TriggerServerEvent('ppr-logger:server:playerDied',
                killerServerId,
                GetEntityCoords(ped),
                weaponHash
            )

            -- Also report death state for combat-log tracking
            TriggerServerEvent('ppr-logger:server:playerDeathState', true)

        elseif not isDead and deathReported then
            deathReported = false -- revived / respawned → re-arm
            TriggerServerEvent('ppr-logger:server:playerDeathState', false)
        end

        Wait(1000)
    end
end)

-- ════════════════════════════════════════════════════════
--  DAMAGE TRACKING (for combat-log detection)
-- ════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        local ped = PlayerPedId()

        if HasEntityBeenDamagedByAnyPed(ped) then
            local now = GetGameTimer()

            -- Cooldown to prevent event spam
            if (now - lastDamageReport) > DAMAGE_REPORT_COOLDOWN then
                lastDamageReport = now

                -- Try to find who attacked us
                local attackerServerId = -1
                for _, player in ipairs(GetActivePlayers()) do
                    local otherPed = GetPlayerPed(player)
                    if otherPed ~= ped and HasEntityBeenDamagedByEntity(ped, otherPed, true) then
                        attackerServerId = GetPlayerServerId(player)
                        break
                    end
                end

                TriggerServerEvent('ppr-logger:server:playerDamaged', attackerServerId)
            end

            ClearEntityLastDamageEntity(ped)
        end

        Wait(500)
    end
end)
