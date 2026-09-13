"""Shared offline world-space layout; x/z Godot coordinates in metres."""
import math, random
PATH=[(-2,9),(-1,6),(.2,2),(-1.5,-.4),(-2.8,-2.8),(-3.0,-5.5),(-1.5,-7.8),(1.6,-8.5),(4,-10),(4,-12),(5,-16),(5,-20)]
STUMP=(-3.0,3.4)
POND=(-7.,-3.5)
def segment_distance(x,z,a,b):
 dx=b[0]-a[0];dz=b[1]-a[1];t=max(0,min(1,((x-a[0])*dx+(z-a[1])*dz)/(dx*dx+dz*dz)))
 return math.hypot(x-a[0]-t*dx,z-a[1]-t*dz)
def path_distance(x,z):return min(segment_distance(x,z,a,b) for a,b in zip(PATH,PATH[1:]))
def path_mask(x,z):
 d=min(path_distance(x,z)-.87,math.hypot(x+2.1,z-5.0)-2.7,math.hypot(x-4,z+12)-2.6)
 d+=.07*math.sin(x*9+z*4)+.04*math.sin(z*17-x*6)
 return max(0,min(1,.5-d/.20))
def pond_distance(x,z):return math.hypot((x-POND[0])/1.12,z-POND[1])
def placements():
 rng=random.Random(91342);items=[]
 def add(asset,x,z,scale=1,yaw=None,y=0):items.append(dict(asset='forest_'+asset,x=x,z=z,y=y+height_at(x,z),scale=scale,yaw=rng.uniform(0,360) if yaw is None else yaw))
 add('stump',*STUMP,scale=1.3,yaw=180)
 add('hollow_log',-5.6,-5.25,1.12,15);add('hollow_log',3.1,1.8,1.05,-30)
 add('gate',5,-16,1,0)
 for x,z,asset,scale in [(.2,-3.7,'rocks',1.9),(1.5,-4.5,'flowers_blue',1.6),(.9,-2.3,'flowers_cream',1.5),(2.1,-2.5,'fern',1.6),(2.5,-5.5,'flowers_blue',1.3)]:add(asset,x,z,scale)
 for x,z,yaw in [(6.8,-12,0),(1.1,-12.3,0),(3,-7,50),(2.6,-.4,30),(-4,-.3,100)]:add('fence',x,z,.8,yaw)
 add('terraces',0,0,1,0)
 # Irregular spacing, with a clear walking corridor and no trunk in a landing route.
 trees=[]
 for iz in range(14):
  for ix in range(13):
   x=-21+ix*3.6+rng.uniform(-.7,.7);z=-27+iz*3.6+rng.uniform(-.7,.7)
   if math.hypot(x-4,z+12)<4.0 or math.hypot(x-5,z+16)<2.8 or (-11<x<-7 and -9<z<-4) or (-3.0<x<5.0 and -8.0<z<.7) or path_mask(x,z)>.02 or path_distance(x,z)<2.2 or math.hypot(x-STUMP[0],z-STUMP[1])<4.0 or pond_distance(x,z)<3.3:continue
   if rng.random()<.25:continue
   scale=rng.uniform(.85,1.3);add(rng.choice(['pine','pine_b','pine_c']) if rng.random()<.92 else 'oak',x,z,scale);trees.append((x,z))
 for _ in range(55):
  x=rng.uniform(-3,7);z=rng.uniform(-15,8)
  if path_mask(x,z)>.9:add('pebbles',x,z,rng.uniform(.6,1.0))
 # Hand placed frame trees make the opening and next clearing legible.
 for x,z,s in [(-6.4,5.7,1.3),(2.6,7.3,1.15),(-7.4,.5,1.1),(-10,-1.5,1.3),(10.8,-9,1.1)]:
  add('pine',x,z,s);trees.append((x,z))
 # Fuller understory around the visible trees breaks up isolated specimen silhouettes.
 for tx,tz in trees:
  if tx<-13 or tx>14 or tz<-18 or tz>11:continue
  for j in range(3):
   a=rng.random()*math.tau;r=rng.uniform(.55,1.0);x=tx+r*math.cos(a);z=tz+r*math.sin(a)
   if path_mask(x,z)>.05 or pond_distance(x,z)<2.8:continue
   add(rng.choice(['fern','shrub','shrub']),x,z,rng.uniform(1.2,2.0))
 for _ in range(1100):
  x=rng.uniform(-12,14);z=rng.uniform(-18,11);d=path_distance(x,z)
  if (-9.3<x<-7.7 and -6.7<z<-5.0) or path_mask(x,z)>.15 or pond_distance(x,z)<2.6 or math.hypot(x-STUMP[0],z-STUMP[1])<2.2:continue
  if d>4.3 and rng.random()<.7:continue
  asset=rng.choices(['fern','shrub','flowers_blue','flowers_cream','rocks','mushrooms'],[24,25,13,13,12,5])[0]
  add(asset,x,z,rng.uniform(1.1,1.9) if asset in ['fern','shrub'] else rng.uniform(.8,1.4))
 for i in range(24):
  a=i/24*math.tau;r=rng.uniform(2.5,3.4)
  add(rng.choice(['fern','flowers_cream','flowers_blue','shrub']),STUMP[0]+r*math.cos(a),STUMP[1]+r*math.sin(a),rng.uniform(.8,1.2))
 for i in range(14):
  a=i/14*math.tau;x=POND[0]+3.05*math.cos(a);z=POND[1]+2.7*math.sin(a)
  if -9.3<x<-7.7 and z<-5.1:continue
  add('rocks',x,z,rng.uniform(.7,1.5))
 for x,z in [(-8,-2),(-6.8,-4.5),(-7.5,-3.1)]:add('lily',x,z,1,y=-.19)
 for x,z in [(-8.8,-1.8),(-5,-3.3),(-8.7,-5)]:add('reeds',x,z,1)
 return items

# Broad connected ledges, not disconnected pillar props. Caps belong to the terrain.
TERRACES=[
 {'name':'PondBank','height':1.8,'polygon':[(-13,-12),(-3,-12),(-2.8,-8.0),(-5.2,-6.8),(-9.8,-6.0),(-13,-6.6)]},
 {'name':'CentralMeadow','height':1.05,'polygon':[(-1.4,-2),(1,-1),(3.6,-2.4),(3.5,-5.3),(1.5,-7.2),(-.9,-6.7),(-2,-4.8)]},
 {'name':'EastBank','height':1.65,'polygon':[(8.0,-8),(13,-8),(13,-3),(9.5,-3.2),(8.3,-5)]}
]
def point_inside(x,z,poly):
 inside=False
 for a,b in zip(poly,poly[1:]+poly[:1]):
  if (a[1]>z)!=(b[1]>z) and x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:inside=not inside
 return inside
def height_at(x,z):
 for terrace in TERRACES:
  poly=terrace['polygon']
  if point_inside(x,z,poly):
   d=min(segment_distance(x,z,a,b) for a,b in zip(poly,poly[1:]+poly[:1]))
   return terrace['height']
 return 0.
