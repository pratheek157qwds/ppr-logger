--[[
    ppr-logger · server/webhook.lua
    ────────────────────────────────
    The heart of the logging system.

    Architecture:
    1. BuildEmbed()  — pure function that assembles a Discord embed table
    2. Enqueue()     — pushes a payload into a FIFO queue
    3. Worker thread — background loop that drains the queue one message
                       at a time, respecting Discord rate limits
    4. Log export    — public API for other resources

    Rate-limit handling:
    - On HTTP 429, we read the Retry-After header and wait exactly that long
    - The message is re-queued at the FRONT so nothing is lost
    - Max retries prevents infinite loops on persistent rate limits
]]

local queue = {}  -- FIFO queue of pending webhook payloads

--- Builds a Discord embed object (plain Lua table, json.encode'd later).
---
---@param title       string        embed title
---@param description string        embed description / body text
---@param color       number        decimal RGB color
---@param fields      table|nil     optional array of { name=, value=, inline= }
---@param footer      string|nil    optional custom footer text
---@return table
local function BuildEmbed(title, description, color, fields, footer)
    return {
        title       = title,
        description = description or '',
        color       = color or Config.Colors.grey,
        fields      = fields or {},
        footer      = {
            text = (footer and footer .. ' • ' or '') .. os.date('%Y-%m-%d %H:%M:%S'),
        },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'), -- ISO 8601 UTC for Discord's relative time
    }
end

--- Validates that a webhook URL looks real (not a placeholder).
---@param url string
---@return boolean
local function IsValidWebhook(url)
    if not url then return false end
    if url:find('XXXX') then return false end
    if not url:match('^https://discord%.com/api/webhooks/') and
       not url:match('^https://discordapp%.com/api/webhooks/') then
        return false
    end
    return true
end

--- Pushes a payload into the send queue.
---@param channel string  key from Config.Webhooks
---@param embed   table   embed built by BuildEmbed
local function Enqueue(channel, embed)
    local url = Config.Webhooks[channel] or Config.Webhooks['custom']

    if not IsValidWebhook(url) then
        -- Only warn once per channel to avoid log spam
        if not _warnedChannels then _warnedChannels = {} end
        if not _warnedChannels[channel] then
            print(('^3[ppr-logger]^7 No valid webhook configured for channel "%s" — messages will be dropped'):format(channel))
            _warnedChannels[channel] = true
        end
        return
    end

    queue[#queue + 1] = {
        url      = url,
        embed    = embed,
        attempts = 0,
        channel  = channel, -- for debug logging
    }
end

-- ════════════════════════════════════════════════════════
--  QUEUE WORKER
-- ════════════════════════════════════════════════════════
-- Single background thread: pops one message, sends it, waits, repeats.
-- Handles 429 by re-queuing at the FRONT so order is preserved.
CreateThread(function()
    -- Brief startup delay to let the server finish loading
    Wait(2000)

    while true do
        if #queue > 0 then
            local msg = table.remove(queue, 1)

            local payload = json.encode({
                username   = Config.BotName,
                avatar_url = Config.BotAvatar,
                embeds     = { msg.embed },
            })

            PerformHttpRequest(msg.url, function(status, _, headers)
                if status == 429 then
                    -- Rate limited: Discord tells us how long to wait via Retry-After
                    local retryAfter = 5 -- default 5s
                    if headers then
                        retryAfter = tonumber(headers['Retry-After'] or headers['retry-after']) or 5
                    end

                    msg.attempts = msg.attempts + 1
                    if msg.attempts <= Config.Queue.maxRetries then
                        table.insert(queue, 1, msg) -- put back at front
                        print(('^3[ppr-logger]^7 Rate limited on "%s", retrying in %ds (attempt %d/%d)')
                            :format(msg.channel, retryAfter, msg.attempts, Config.Queue.maxRetries))
                    else
                        print(('^1[ppr-logger]^7 Dropped message for "%s" after %d retries')
                            :format(msg.channel, Config.Queue.maxRetries))
                    end

                    Wait(retryAfter * 1000)

                elseif status ~= 200 and status ~= 204 then
                    print(('^1[ppr-logger]^7 Webhook failed for "%s" — HTTP %s')
                        :format(msg.channel, tostring(status)))
                end
            end, 'POST', payload, { ['Content-Type'] = 'application/json' })

            Wait(Config.Queue.delay)
        else
            Wait(Config.Queue.idleInterval) -- idle: check queue periodically
        end
    end
end)

-- ════════════════════════════════════════════════════════
--  PUBLIC API
-- ════════════════════════════════════════════════════════

--- Main logging function. Other resources call:
---   exports['ppr-logger']:Log('deaths', 'Player Died', 'X was killed', 'red', fields)
---
---@param channel string          webhook channel key from Config.Webhooks
---@param title   string          embed title
---@param message string          embed description
---@param color   string|number   color name from Config.Colors OR raw decimal
---@param fields  table|nil       optional array of { name=, value=, inline= }
local function Log(channel, title, message, color, fields)
    if not channel or not title then
        print('^1[ppr-logger]^7 Log() called with missing channel or title')
        return
    end

    local resolvedColor
    if type(color) == 'string' then
        resolvedColor = Config.Colors[color] or Config.Colors.grey
    elseif type(color) == 'number' then
        resolvedColor = color
    else
        resolvedColor = Config.Colors.grey
    end

    Enqueue(channel, BuildEmbed(title, message, resolvedColor, fields))
end

-- Export for other resources
exports('Log', Log)

-- Also make it callable internally by other server files of THIS resource
-- (exports can't be called within the same resource)
LogInternal = Log
