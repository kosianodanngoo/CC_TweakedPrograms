local speaker = peripheral.find("speaker")
local audio = require("/modules.audio")

print("this is sine wave")
speaker.playAudio(audio.sine(440,1))
sleep(1)

print("this is gradation sine wave")
speaker.playAudio(audio.gradationSine(220, 880, 1))
sleep(1)

print("this is sawtooth wave")
speaker.playAudio(audio.sawtooth(440,1))
sleep(1)

print("this is gradation sawtooth wave")
speaker.playAudio(audio.gradationSawtooth(220, 880, 1))
sleep(1)

print("this is triangle wave")
speaker.playAudio(audio.triangle(440,1))
sleep(1)

print("this is gradation triangle wave")
speaker.playAudio(audio.gradationTriangle(220, 880, 1))
sleep(1)

print("this is square wave")
speaker.playAudio(audio.square(440,1))
sleep(1)

print("this is gradation square wave")
speaker.playAudio(audio.gradationSquare(220, 880, 1))
sleep(1)

print("this is noize")
speaker.playAudio(audio.noize(1))
sleep(1)

print("playing long audio")
audio.playLongAudio(audio.gradationTriangle(200, 1000, 10), speaker)