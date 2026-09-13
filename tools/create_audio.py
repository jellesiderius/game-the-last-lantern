"""Deterministic original prototype Foley. No sampled third-party recordings."""
from pathlib import Path
import math,random,struct,wave
random.seed(932)
OUT=Path(__file__).resolve().parents[1]/'assets/audio'
for name,duration in [('swing',.17),('impact',.14),('roll',.32)]:
 rate=24000;last=0;frames=[]
 for i in range(int(rate*duration)):
  t=i/rate;u=t/duration;noise=random.uniform(-1,1);last=.75*last+.25*noise
  if name=='swing':v=(noise-last)*math.sin(math.pi*u)**1.5*.26+last*math.sin(math.pi*u)*.5
  elif name=='impact':v=(math.sin(math.tau*(145*t-130*t*t))*.4+noise*.12)*math.exp(-u*7)*min(1,u*90)
  else:v=last*math.sin(math.pi*u)*.7
  frames.append(struct.pack('<h',int(max(-1,min(1,v))*32767)))
 with wave.open(str(OUT/(name+'.wav')),'wb') as f:f.setparams((1,2,rate,0,'NONE','not compressed'));f.writeframes(b''.join(frames))
print('Created swing.wav, impact.wav, roll.wav')
