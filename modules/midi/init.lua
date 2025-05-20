local midi = {}
-- file is a file handler
midi.parseHeader = function(fileData)
    if string.sub(fileData, 1, 4) ~= "MThd" then
        error("Invalid MIDI file header")
    end
    if string.sub(fileData, 5, 8) ~= "\000\000\000\006" then
        error("Invalid MIDI file header length")
    end
    local header = {}
    if string.byte(fileData, 9) ~= 0 then
        error("Unsupported MIDI format")
    end
    header.formatType = string.byte(fileData, 10)
    header.numTracks = string.byte(fileData, 11) * 256 + string.byte(fileData, 12)
    if header.formatType == 0 and header.numTracks ~= 1 then
        error("Invalid MIDI file: format type 0 requires exactly one track")
    end
    if header.numTracks == 0 then
        error("Invalid MIDI file: no tracks found")
    end
    header.trackDivision = string.byte(fileData, 13) * 256 + string.byte(fileData, 14)
    return header
end
-- 可変長数量を読み取るヘルパー関数
local function readVariableLengthQuantity(data, pos)
    local value = 0
    local len = 0
    while true do
        local byte = string.byte(data, pos + len)
        value = (value * 128) + (byte % 128)  -- 修正（bit.bandがない場合は % 128 で代替）
        len = len + 1
        if byte < 128 then
            break
        end
    end
    return value, len
end

-- イベントを読み取るヘルパー関数
local function readEvent(data, pos, lastStatus)
    local startPos = pos
    local RSC = 128
    local byte1 = string.byte(data, pos)
    if byte1 == 0xFF then
        -- メタイベント
        pos = pos + 1
        local metaType = string.byte(data, pos)
        pos = pos + 1
        local len, lenLen = readVariableLengthQuantity(data, pos)
        pos = pos + lenLen
        local metaData = string.sub(data, pos, pos + len - 1)
        pos = pos + len
        return {type = "meta", metaType = metaType, data = metaData}, pos - startPos, lastStatus
    elseif byte1 == 0xF0 or byte1 == 0xF7 then
        -- システムエクスクルーシブイベント
        pos = pos + 1
        local len, lenLen = readVariableLengthQuantity(data, pos)
        pos = pos + lenLen
        local sysexData = string.sub(data, pos, pos + len - 1)
        pos = pos + len
        return {type = "sysex", data = sysexData}, pos - startPos, lastStatus
    else
        -- MIDIイベント（ランニングステータス対応）
        local status, dataStart
        if byte1 >= RSC then
            status = byte1
            dataStart = pos + 1
        else
            if not lastStatus then
                error("running status was used without a laststatus")
            end
            status = lastStatus
            dataStart = pos
        end
        local eventType = math.floor(status / 16)
        local numDataBytes = (eventType == 0xC or eventType == 0xD) and 1 or 2
        local dataBytes = {}
        for i = 1, numDataBytes do
            table.insert(dataBytes, string.byte(data, dataStart + i - 1))
        end
        pos = dataStart + numDataBytes
        return {type = "midi", status = status, data = dataBytes}, pos - startPos, status
    end
end

-- トラック解析関数
midi.parseTrack = function(fileData, startPos)
    if string.sub(fileData, startPos, startPos + 3) ~= "MTrk" then
        error("invalid MIDI track header")
    end
    local length = (string.byte(fileData, startPos + 4) * 0x1000000) +
               (string.byte(fileData, startPos + 5) * 0x10000) +
               (string.byte(fileData, startPos + 6) * 0x100) +
               string.byte(fileData, startPos + 7)
    local trackData = string.sub(fileData, startPos + 8, startPos + 8 + length - 1)
    local events = {}
    local pos = 1
    local lastStatus = nil
    while pos <= length do
        local deltaTime, deltaLen = readVariableLengthQuantity(trackData, pos)
        pos = pos + deltaLen
        local event, eventLen, newStatus = readEvent(trackData, pos, lastStatus)
        pos = pos + eventLen
        lastStatus = newStatus
        table.insert(events, {deltaTime = deltaTime, event = event})
    end
    return {events = events}, startPos + 8 + length
end

midi.parseMidi = function(file)
    local fileData = file.readAll()
    local data = {}
    data.header = midi.parseHeader(fileData)
    data.tracks = {}
    local pos = 15 -- ヘッダー（14バイト）の後
    for i = 1, data.header.numTracks do
        local track, newPos = midi.parseTrack(fileData, pos)
        table.insert(data.tracks, track)
        pos = newPos
    end
    return data
end

midi.play = function(midiData, speaker)
    -- 全てのイベントを絶対時間で収集
    local events = {}
    for _, track in ipairs(midiData.tracks) do
        local time = 0
        for _, event in ipairs(track.events) do
            time = time + event.deltaTime
            table.insert(events, {time = time, event = event.event})
        end
    end
    table.sort(events, function(a, b) return a.time < b.time end)

    -- init speaker
    local initBuf = {}
    for i = 1, 128 * 16 do
        initBuf[i] = 0
    end
    speaker.playAudio(initBuf)

    -- 再生処理
    local currentTime = 0
    local tempo = 500000 -- デフォルトテンポ（マイクロ秒/四分音符）
    local Frequency = 48000
    local instruments = {}
    local playingNotes = {}
    for i = 1,16 do
        playingNotes[i] = {}
    end
    local c = 0
    local playedTime = 0
    for _, e in ipairs(events) do
        local secPerTick = tempo / 1000000 / midiData.header.trackDivision
        local deltaTicks = e.time - currentTime
        local nowPlayedTime = playedTime
        while playedTime + 0.05 / secPerTick < nowPlayedTime + deltaTicks do
            local buffer = {}
            for i = 1,Frequency / 20 do
                buffer[i] = 0
                -- バッファ生成部分の修正
                local toRemove = {}
                for ch, track in ipairs(playingNotes) do
                    for n, note in ipairs(track) do
                        local noteEndTime = playedTime + i * 0.05 / secPerTick / Frequency
                        if note.to < noteEndTime then
                            table.insert(toRemove, {channel = ch, index = n})
                        else
                            if note.from <= noteEndTime then
                                buffer[i] = buffer[i] + ((note.frequency * (c*Frequency / 20 + i) / Frequency) % 1 - 1) * note.velocity / 16
                            end
                        end
                    end
                end
                buffer[i] = math.max(-128, math.min(127, math.floor(buffer[i])))
                -- 削除リストを処理（インデックスの大きい順から削除）
                table.sort(toRemove, function(a, b) return a.index > b.index end)
                for _, item in ipairs(toRemove) do
                    table.remove(playingNotes[item.channel], item.index)
                end
            end
            while not speaker.playAudio(buffer) do
                os.pullEvent("speaker_audio_empty")
            end
            c= c+1
            currentTime = playedTime
            playedTime = playedTime + 0.05 / secPerTick
        end

        if e.event.type == "midi" and e.event.status >= 0x90 and e.event.status < 0xA0 and e.event.data[2] > 0 then
            -- ノートオンイベント（ベロシティ > 0）
            local note = e.event.data[1]
            local velocity = e.event.data[2]
            local frequency = 440 * 2 ^ ((note - 69) / 12)
            local volume = velocity / 127
            local channel = e.event.status % 16 + 1
            local to = math.huge
            local instrument = instruments[channel]
            if channel == 10 then
                to = e.time + 0.05 / secPerTick
            end
            if volume > 0 then
                table.insert(playingNotes[channel], {note = note, frequency = frequency, velocity = velocity, volume = volume, from = e.time, to = math.huge, instrument = instrument})
            end
        elseif e.event.type == "midi" and e.event.status >= 0x80 and e.event.status < 0x90 then
            -- ノートオフイベント
            local channel = e.event.status % 16 + 1  -- チャンネルは0〜15なので+1
            local noteNumber = e.event.data[1]       -- 停止するノート番号
            
            -- 特定のノートのみを停止する
            for i, note in ipairs(playingNotes[channel]) do
                if note.note == noteNumber then
                    note.to = e.time  -- 終了時間を設定
                end
            end
        elseif e.event.type == "midi" and e.event.status >= 0xC0 and e.event.status < 0xD0 then
            local channel = e.event.status % 16 + 1
            local programChange = e.event.data[1]

            instruments[channel] = programChange
        elseif e.event.type == "meta" and e.event.metaType == 0x51 then
            -- テンポ設定イベント
            local tempoBytes = {string.byte(e.event.data, 1, 3)}
            tempo = (tempoBytes[1] * 0x10000) + (tempoBytes[2] * 0x100) + tempoBytes[3]
        end
    end
end

return midi