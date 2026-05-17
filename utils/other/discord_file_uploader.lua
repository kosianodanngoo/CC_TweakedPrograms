local WebhookURL = "" -- URL of discord webhook

local function readFileBinary(path)
    local file = fs.open(path, "rb")
    if not file then
        return nil, "cannot open file: " .. path
    end
    local data = file.readAll()
    file.close()
    return data
end

local function buildMultipartBody(fieldName, fileName, fileData, boundary)
    local lines = {
        "--" .. boundary,
        'Content-Disposition: form-data; name="' .. fieldName .. '"; filename="' .. fileName .. '"',
        "Content-Type: application/octet-stream",
        "",
        fileData,
        "--" .. boundary .. "--",
        ""
    }
    return table.concat(lines, "\r\n")
end

local function getFileName(path)
    return path:match("[^/\\]+$") or "file"
end

local function sendFile(url, filePath)
    if not url or url == "" then
        url = WebhookURL
    end
    if not url or url == "" then
        return false, "Discord webhook URL is not set"
    end

    if not fs.exists(filePath) then
        return false, "file does not exist: " .. filePath
    end

    local fileData, err = readFileBinary(filePath)
    if not fileData then
        return false, err
    end

    local boundary = "CC_DISCORD_BOUNDARY_" .. tostring(math.random(100000, 999999))
    local body = buildMultipartBody("file", getFileName(filePath), fileData, boundary)
    local headers = {
        ["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
        ["User-Agent"] = "ComputerCraft/DiscordWebhook"
    }

    local response = http.post(url, body, headers)
    if not response then
        return false, "http.post failed"
    end

    local responseBody = response.readAll()
    response.close()

    return true, responseBody
end

sendFile(WebhookURL, "dimensional_teleporter.png")