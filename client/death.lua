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
local DAMAGE_REPORT_COOLDOWN = 1000

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local isDead = IsEntityDead(ped)

        if isDead and not deathReported then
            deathReported = true

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

            TriggerServerEvent('ppr-logger:server:requestDeathWebhook',
                killerServerId,
                GetEntityCoords(ped),
                weaponHash
            )

            TriggerServerEvent('ppr-logger:server:playerDeathState', true)

        elseif not isDead and deathReported then
            deathReported = false
            TriggerServerEvent('ppr-logger:server:playerDeathState', false)
        end

        Wait(1000)
    end
end)

RegisterNetEvent('ppr-logger:client:takeDeathScreenshot', function(webhookUrl, killerServerId, coords, weaponHash)
    if GetResourceState('screenshot-basic') == 'started' then
        exports['screenshot-basic']:requestScreenshotUpload(webhookUrl, 'files[]', function(data)
            local success, resp = pcall(json.decode, data)
            local imageUrl = nil
            if success and resp and resp.attachments and resp.attachments[1] then
                imageUrl = resp.attachments[1].url or resp.attachments[1].proxy_url
            end
            TriggerServerEvent('ppr-logger:server:playerDied', killerServerId, coords, weaponHash, imageUrl)
        end)
    else
        TriggerServerEvent('ppr-logger:server:playerDied', killerServerId, coords, weaponHash, nil)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()

        if HasEntityBeenDamagedByAnyPed(ped) then
            local now = GetGameTimer()

            if (now - lastDamageReport) > DAMAGE_REPORT_COOLDOWN then
                lastDamageReport = now

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
