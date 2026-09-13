"""Small deterministic synthesized heavy strike: low body, crack and decaying air."""
import math, random, struct, wave
from pathlib import Path
rng=random.Random(83); rate=44100; duration=.32; samples=[]; smooth=0.
for i in range(round(rate*duration)):
 t=i/rate; noise=rng.uniform(-1,1);smooth=.89*smooth+.11*noise
 attack=min(1,t/.004)
 body=math.sin(2*math.pi*(105*t-90*t*t))*math.exp(-t*20)
 crack=noise*math.exp(-t*105)*.3
 air=smooth*math.exp(-t*13)*1.6
 samples.append(struct.pack('<h',round(max(-1,min(1,attack*(body*.65+crack+air)))*26000)))
with wave.open(str(Path(__file__).resolve().parents[1]/'assets/audio/heavy_burst.wav'),'wb') as f:
 f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(samples))
