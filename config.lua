--[[
    ppr-logger · config.lua
    ────────────────────────
    Single source of truth for every tweakable value.
    Shared between server + client — anything marked SERVER-ONLY
    is only read server-side (but it's safe to ship; clients
    can't use webhook URLs for anything).
]]

Config = {}
Config.Debug = true -- Set to true to enable test commands (e.g. /testdisconnect)


-- ════════════════════════════════════════════════════════
--  WEBHOOKS (SERVER-ONLY — clients never call these)
-- ════════════════════════════════════════════════════════
-- Map a channel name → Discord webhook URL.
-- Replace the placeholder URLs before use.
Config.Webhooks = {
    ['joins']       = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
    ['leaves']      = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
    ['chat']        = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
    ['deaths']      = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
    ['combatlog']   = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
    ['custom']      = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C', -- fallback for exports
}

-- Bot appearance in Discord
Config.BotName   = 'PPR Logger'
Config.BotAvatar = 'https://i.imgur.com/your_logo.png'

-- Discord embed colors (decimal RGB)
Config.Colors = {
    green  = 5763119,   -- #57F287  (Discord green)
    red    = 15548997,  -- #ED4245  (Discord red)
    blue   = 5793266,   -- #5865F2  (Discord blurple)
    orange = 15105570,  -- #E67E22
    yellow = 16776960,  -- #FFFF00
    grey   = 9807270,   -- #95A5A6
    purple = 10181046,  -- #9B59B6
}

-- ════════════════════════════════════════════════════════
--  PRIVACY / IDENTIFIERS
-- ════════════════════════════════════════════════════════

--- Log the player's IP in Discord leave/join embeds?
--- ⚠️  IP is NEVER sent to clients regardless of this setting.
---     It only appears in the Discord embed (staff-only channels).
Config.LogIP = true

--- Which identifiers to capture and display.
--- These are shown both in Discord and in the NUI inspection card.
Config.Identifiers = { 'license', 'steam', 'discord', 'fivem' }

-- ════════════════════════════════════════════════════════
--  GHOST PED SYSTEM
-- ════════════════════════════════════════════════════════
Config.LeavePed = {
    enabled      = true,
    despawnTime  = 5 * 60 * 1000,  -- how long the ped stays (ms) — 5 minutes
    interactKey  = 38,             -- E key (control index)
    interactDist = 2.0,            -- meters: show "Press E" prompt
    drawDist     = 15.0,           -- meters: show floating 3D name tag

    --- Fallback ped model if the player's actual model can't be spawned
    --- (e.g. addon ped from a stopped resource)
    fallbackModel = `mp_m_freemode_01`,

    --- Mugshot lineup animation
    anim = {
        dict = 'mp_character_creation@customise@male_a',
        name = 'loop',
    },

    --- Police ID board prop (attached to left forearm/hand)
    prop = {
        model = `prop_police_id_text`,
        bone  = 58868,
        pos   = vec3(0.12, 0.24, 0.0),
        rot   = vec3(5.0, 0.0, 70.0),
    },
}

-- ════════════════════════════════════════════════════════
--  COMBAT-LOG DETECTION
-- ════════════════════════════════════════════════════════
Config.CombatLog = {
    enabled          = true,
    --- If a player disconnects within this many ms of taking damage,
    --- it counts as a possible combat log.
    combatWindow     = 30 * 1000,  -- 30 seconds
    --- Also flag if they disconnect while dead (ragdolled before respawn)
    flagIfDead       = true,
    --- Separate webhook channel (falls back to 'leaves' if not configured)
    webhookChannel   = 'combatlog',
}

-- ════════════════════════════════════════════════════════
--  QUEUE / RATE LIMITER
-- ════════════════════════════════════════════════════════
Config.Queue = {
    delay          = 750,    -- ms between webhook sends (~80 msgs/min max)
    maxRetries     = 3,      -- max 429 retries before dropping a message
    idleInterval   = 500,    -- ms to wait when queue is empty
}
