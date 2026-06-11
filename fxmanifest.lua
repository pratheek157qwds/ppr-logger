--[[
    ╔══════════════════════════════════════════════════╗
    ║           ppr-logger · FiveM Resource            ║
    ║  Advanced Discord Logger + Ghost Ped Leave System║
    ║                                                  ║
    ║  Author : pratheek                               ║
    ║  Studio : PPR Development                        ║
    ║  Version: 1.0.0                                  ║
    ╚══════════════════════════════════════════════════╝
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'pratheek'
description 'PPR Development — Advanced Discord webhook logger with ghost-ped leave system, combat-log detection, and NUI inspection card'
version '1.0.0'
repository 'https://github.com/pratheek157qwds/ppr-logger'

-- ═══════ SHARED (loads on both server + client) ═══════
shared_script 'config.lua'

-- ═══════ SERVER ═══════
-- Load order matters: utils.lua defines globals used by subsequent files
server_scripts {
    'server/utils.lua',
    'server/webhook.lua',
    'server/leaveped.lua',
    'server/events.lua',
}

-- ═══════ CLIENT ═══════
client_scripts {
    'client/leaveped.lua',
    'client/death.lua',
}

-- ═══════ NUI ═══════
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}
