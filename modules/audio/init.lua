local audio = {}

local Frequency = 48000

local range = function(min, max, number)
    return math.max(math.min(number, max), min)
end

audio.playLongAudio = function(audioData, speaker)
    for i = 1, math.ceil(#audioData / (128 * 1024)) do
        local buffer = {}
        local dataStart = (i-1) * 128 * 1024 + 1
        local dataEnd = math.min(i * 128 * 1024, #audioData)
        for i = 1, dataEnd - dataStart do
            buffer[i] = audioData[dataStart + i]
        end
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end
    os.pullEvent("speaker_audio_empty")
end

audio.makeSound = function(time, disableSafely, waveMaker)
    local buffer = {}
    for i = 1, math.floor(time * Frequency) do
        buffer[i] = waveMaker(i, math.floor(time * Frequency))
        if not disableSafely then
            buffer[i] = range(-128, 127, buffer[i])
        end
    end
    return buffer
end

audio.sine = function(hz, time, volume, disableSafely)
    local time = time or 1
    local volume = volume or 1
    return audio.makeSound(time, disableSafely,
    function(i, max)
        return math.floor(math.sin(i * (2 * math.pi * hz / Frequency) % (math.pi * 2)) * 127 * volume)
    end)
end

audio.gradationSine = function(hz1, hz2, time, volume, disableSafely)
    local time = time or 1
    local volume = volume or 1
    return audio.makeSound(time, disableSafely,
    function(i, max)
        local hz = (hz1 * (math.floor(time * Frequency) - i) / math.floor(time * Frequency)) + (hz2 * i / math.floor(time * Frequency))
        return math.floor(math.sin(i * (2 * math.pi * hz / Frequency) % (math.pi * 2)) * 127 * volume)
    end)
end

audio.sawtooth = function(hz, time, volume, disableSafely)
    local time = time or 1
    local volume = volume or 1
    return audio.makeSound(time, disableSafely,
    function(i, max)
        return math.floor((i * hz / Frequency) % 1 * 127 * volume)
    end)
end

audio.gradationSawtooth = function(hz1, hz2, time, volume, disableSafely)
    local time = time or 1
    local volume = volume or 1
    return audio.makeSound(time, disableSafely,
    function(i, max)
        local hz = (hz1 * (math.floor(time * Frequency) - i) / math.floor(time * Frequency)) + (hz2 * i / math.floor(time * Frequency))
        return math.floor((i * hz / Frequency) % 1 * 127 * volume)
    end)
end

audio.triangle = function(hz, time, volume, disableSafely)
    local time = time or 1
    local volume = volume or 1
    return audio.makeSound(time, disableSafely,
    function(i, max)
        return math.floor(math.abs((i * hz / Frequency) % 1 - 0.5) * 2 * 127 * volume)
    end)
end

audio.gradationTriangle = function(hz1, hz2, time, volume, disableSafely)
    local time = time or 1
    local volume = volume or 1
    return audio.makeSound(time, disableSafely,
    function(i, max)
        local hz = (hz1 * (math.floor(time * Frequency) - i) / math.floor(time * Frequency)) + (hz2 * i / math.floor(time * Frequency))
        return math.floor(math.abs((i * hz / Frequency) % 1 - 0.5) * 2 * 127 * volume)
    end)
end

audio.square = function(hz, time, volume, disableSafely)
    local time = time or 1
    local volume = volume or 1
    return audio.makeSound(time, disableSafely,
    function(i, max)
        return math.floor(math.floor(math.abs((i * hz / Frequency) % 1 + 0.5)) * 127 * volume)
    end)
end

audio.gradationSquare = function(hz1, hz2, time, volume, disableSafely)
    local time = time or 1
    local volume = volume or 1
    return audio.makeSound(time, disableSafely,
    function(i, max)
        local hz = (hz1 * (math.floor(time * Frequency) - i) / math.floor(time * Frequency)) + (hz2 * i / math.floor(time * Frequency))
        return math.floor(math.floor(math.abs((i * hz / Frequency) % 1 + 0.5)) * 127 * volume)
    end)
end

audio.noize = function(time, volume, disableSafely)
    local time = time or 1
    local volume = volume or 1
    return audio.makeSound(time, disableSafely,
    function(i, max)
        return math.floor(math.random() * 127 * volume)
    end)
end

return audio