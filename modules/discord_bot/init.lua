local json = textutils.unserializeJSON
local function serialize(text) return textutils.serializeJSON(text, {unicode_strings = true}) end

local API = {}

local API_BASE = "https://discord.com/api/v10"

-- Synchronous HTTP for arbitrary methods (e.g. PUT), built on the async http.request.
-- IMPORTANT: only call this BEFORE the gateway loop is running. Its internal os.pullEvent
-- discards non-matching events, which would drop websocket/timer events of a live connection.
local function httpRequestSync(method, url, headers, body)
    if not http.request({ url = url, method = method, headers = headers, body = body }) then
        return nil, "request not queued"
    end
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "http_success" and p1 == url then
            return p2
        elseif event == "http_failure" and p1 == url then
            return nil, p2, p3
        end
    end
end


local function sendHeartbeat(bot)
    -- Build the JSON by hand so the "d" field is always present (null when we have no sequence yet).
    -- serializeJSON would drop a nil "d" entirely, which Discord rejects with a 4002 decode error.
    local d = bot.latestSequence and tostring(bot.latestSequence) or "null"
    -- ws.send returns nothing; it throws if the socket is closed, so detect failure via pcall.
    local ok, err = pcall(bot.ws.send, '{"op":1,"d":' .. d .. '}')
    if not ok then
        error("Failed to send heartbeat: " .. tostring(err))
    end
    bot.heartbeatAcked = false
end

-- Discord Gateway close codes, for diagnosing why the connection dropped.
local CLOSE_CODES = {
    [4004] = "Authentication failed (invalid token)",
    [4008] = "Rate limited",
    [4010] = "Invalid shard",
    [4011] = "Sharding required",
    [4012] = "Invalid API version",
    [4013] = "Invalid intents (bad intents value)",
    [4014] =
    "Disallowed intents (privileged intent not enabled - turn ON MESSAGE CONTENT INTENT in the Developer Portal)",
}

-- Single event loop: drives heartbeats off a timer and dispatches gateway messages.
-- This bot owns exactly one websocket, so we do NOT filter events by URL string -- the
-- previous URL-equality check could silently drop every message and close event.
local function run(bot, callback)
    bot.heartbeatAcked = true
    -- First heartbeat after interval * jitter (jitter in [0.5, 1.0)), per the Discord spec.
    bot.heartbeatTimer = os.startTimer(bot.heartbeatInterval * (0.5 + math.random() * 0.5) / 1000)
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "timer" and p1 == bot.heartbeatTimer then
            if not bot.heartbeatAcked then
                error("Heartbeat not acknowledged - zombie connection, reconnect required.")
            end
            sendHeartbeat(bot)
            bot.heartbeatTimer = os.startTimer(bot.heartbeatInterval / 1000)
        elseif event == "websocket_message" then
            local data = json(p2)

            if data.s then
                bot.latestSequence = data.s
            end

            if data.op == 0 then
                if callback(bot, data.t, data.d) then
                    return -- stop the bot if callback returns a truthy value
                end
            elseif data.op == 1 then
                -- Server asked us to heartbeat right now.
                sendHeartbeat(bot)
            elseif data.op == 7 then
                error("Reconnect requested by server.")
            elseif data.op == 9 then
                error("Invalid session. Reconnect required.")
            elseif data.op == 11 then
                bot.heartbeatAcked = true
            end
        elseif event == "websocket_closed" then
            -- websocket_closed params: (event, url, reason, code)
            local hint = p3 and CLOSE_CODES[p3]
            error("Connection closed by Discord. code=" .. tostring(p3)
                .. " reason=" .. tostring(p2)
                .. (hint and (" => " .. hint) or ""))
        elseif event == "http_failure" then
            -- Surface failures from async requests (e.g. interaction responses).
            -- http_failure params: (event, url, errMsg, handle)
            print("HTTP request failed: " .. tostring(p2))
        end
    end
end

function API.connect(token, intents)
    local bot = {
        token = token,
        intents = intents
    }
    local handle, err = http.get("https://discord.com/api/v10/gateway/bot", {
        ["Authorization"] = "Bot " .. token
    })
    if not handle then
        error("Failed to get gateway URL: " .. err)
    end
    local body = handle.readAll()
    handle.close()
    local gateway_url = json(body).url .. "/?v=10&encoding=json"

    local ws, err = http.websocket(gateway_url)
    if not ws then
        error("WebSocket connection failed: " .. err)
    end
    bot.ws = ws
    bot.url = gateway_url

    local first_msg = bot.ws.receive()
    if not first_msg then
        bot.ws.close()
        error("Connection failed before Hello")
    end

    local hello_data = json(first_msg)
    if hello_data.op ~= 10 then
        bot.ws.close()
        error("Expected Opcode 10 (Hello), but got " .. tostring(hello_data.op))
    end
    bot.heartbeatInterval = hello_data.d.heartbeat_interval

    local identifyPayload = {
        op = 2,
        d = {
            token = token,
            intents = intents,
            properties = {
                ["$os"] = "CraftOS",
                ["$browser"] = "ComputerCraft",
                ["$device"] = "Computer"
            }
        }
    }
    bot.ws.send(serialize(identifyPayload))
    bot.heartbeatAcked = true
    return bot
end

function API.start(token, intents, callback, onInitialized)
    local bot, err
    -- catch any errors in the connection and event loop to ensure the WebSocket is closed properly
    xpcall(function()
        bot = API.connect(token, intents)
        if onInitialized then
            onInitialized(bot)
        end
        run(bot, callback)
    end, function(err1)
        err = err1
    end)
    if bot and bot.ws then
        bot.ws.close()
    end
    if err then
        error("Bot stopped: " .. tostring(err))
    end
end

-- Fetch this bot's application id (needed to register slash commands).
function API.getApplicationId(token)
    local resp, err, errResp = http.get(API_BASE .. "/oauth2/applications/@me", {
        ["Authorization"] = "Bot " .. token
    })
    if not resp then
        if errResp then errResp.close() end
        error("Failed to get application id: " .. tostring(err))
    end
    local data = json(resp.readAll())
    resp.close()
    return data.id
end

-- Bulk-overwrite the guild's slash commands with `defs` (instant for the given guild).
-- defs = { { name=, description=, options= (optional) }, ... }. Call BEFORE API.start.
function API.registerGuildCommands(token, appId, guildId, defs)
    local payload = {}
    for i, def in ipairs(defs) do
        payload[i] = {
            name = def.name,
            description = def.description,
            type = 1, -- CHAT_INPUT (slash command)
            options = def.options,
        }
    end
    -- Force a JSON array even when empty, so Discord clears commands correctly.
    local body = #payload == 0 and "[]" or serialize(payload)
    local url = API_BASE .. "/applications/" .. appId .. "/guilds/" .. guildId .. "/commands"
    local resp, err, errResp = httpRequestSync("PUT", url, {
        ["Authorization"] = "Bot " .. token,
        ["Content-Type"] = "application/json",
    }, body)
    if not resp then
        local detail = errResp and errResp.readAll() or ""
        if errResp then errResp.close() end
        error("Failed to register commands: " .. tostring(err) .. " " .. detail)
    end
    resp.close()
end

-- Reply to an interaction. Async (safe to call from inside the gateway loop).
-- Must be called within 3 seconds of receiving the interaction.
function API.respond(interactionId, interactionToken, content)
    local url = API_BASE .. "/interactions/" .. interactionId .. "/" .. interactionToken .. "/callback"
    local body = serialize({ type = 4, data = { content = content } })
    http.request({
        url = url,
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        body = body,
    })
end

-- Reply to an interaction with a file attachment read from this computer's filesystem.
-- Uses multipart/form-data (Discord does not accept files as JSON). Async, so it is safe
-- to call from inside the gateway loop. Must be sent within 3 seconds of the interaction.
function API.respondWithFiles(interactionId, interactionToken, content, filePaths)
    local CRLF = "\r\n"
    local boundary = "----CCBoundary" .. tostring(os.epoch("utc"))

    local payload = { type = 4, data = {attachments = {}} }
    if content and content ~= "" then
        payload.data.content = content
    end
    for i, path in ipairs(filePaths) do
        payload.data.attachments[i] = {id = i - 1, filename = fs.getName(path) }
    end

    local body = "--" .. boundary .. CRLF
        .. 'Content-Disposition: form-data; name="payload_json"' .. CRLF
        .. "Content-Type: application/json" .. CRLF .. CRLF
        .. serialize(payload) .. CRLF


    for i, path in ipairs(filePaths) do
        local f = fs.open(path, "rb")
        if not f then
            error("Cannot open file: " .. tostring(path))
        end
        local bytes = f.readAll()
        f.close()
        local filename = fs.getName(path)

        body = body .. "--" .. boundary .. CRLF ..
            'Content-Disposition: form-data; name="files[' .. (i - 1) .. ']"; filename="' .. filename .. '"' .. CRLF
            .. "Content-Type: application/octet-stream" .. CRLF .. CRLF
            .. bytes .. CRLF
    end

    body = body .. "--" .. boundary .. "--" .. CRLF

    http.request({
        url = API_BASE .. "/interactions/" .. interactionId .. "/" .. interactionToken .. "/callback",
        method = "POST",
        headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary },
        body = body,
    })
end

return API
