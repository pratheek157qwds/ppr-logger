--[[
    ppr-logger · config.lua
    ────────────────────────
    Single source of truth for every tweakable value.
    Shared between server + client — anything marked SERVER-ONLY
    is only read server-side (but it's safe to ship; clients
    can't use webhook URLs for anything).
]]

Config = {}
Config.Debug = false

Config.Webhooks = {
    ['joins']       = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
    ['leaves']      = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
    ['chat']        = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
    ['deaths']      = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
    ['combatlog']   = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
    ['custom']      = 'https://canary.discord.com/api/webhooks/1516016994040811633/XBTKcZaeqxXwwUJiLHZEax43yMmzn_l97F_izmsSw76de9JjjsR8yaUUvfSUeCUthN7C',
}

Config.BotName   = 'PPR Logger'
Config.BotAvatar = 'https://cdn.discordapp.com/icons/1275817366537633852/a_2ef1fff386a4e456157abea3deb8d996.gif?size=1024'

Config.Colors = {
    green  = 1096065,
    red    = 16007006,
    blue   = 6514417,
    orange = 16096779,
    yellow = 16498468,
    grey   = 7041664,
    purple = 9133302,
}

Config.LogIP = true

Config.Identifiers = { 'license', 'steam', 'discord', 'fivem' }

Config.LeavePed = {
    enabled      = true,
    despawnTime  = 5 * 60 * 1000,
    interactKey  = 38,
    interactDist = 2.0,
    drawDist     = 15.0,

    fallbackModel = `mp_m_freemode_01`,

    anim = {
        dict = 'mp_character_creation@customise@male_a',
        name = 'loop',
    },

    prop = {
        model = `prop_police_id_text`,
        bone  = 58868,
        pos   = vec3(0.12, 0.24, 0.0),
        rot   = vec3(5.0, 0.0, 70.0),
    },
}

Config.CombatLog = {
    enabled          = true,
    combatWindow     = 30 * 1000,
    flagIfDead       = true,
    webhookChannel   = 'combatlog',
}

Config.Queue = {
    delay          = 750,
    maxRetries     = 3,
    idleInterval   = 500,
}
