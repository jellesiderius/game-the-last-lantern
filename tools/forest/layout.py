"""Offline forest layout in Godot x/z metres: one quiet route inside connected banks."""
import math
import random

GROUND_BOUNDS = (-23, 23, -84, 18)
PLAY_BOUNDS = (-18, 20, -76, 10)
STUMP = (-3.0, 3.4)
POND = (-7.0, -3.5)
EXIT = (4.0, -70.0)
PATH = [(-2, 7), (-1, 6), (.2, 2), (-1.5, -.4), (-2.8, -2.8),
        (-3, -5.5), (-1.5, -7.8), (1.6, -8.5), (4, -10), (4, -12),
        (4, -17), (3, -22), (0, -28), (-3.5, -34), (-4, -39),
        (-2, -45), (1, -50), (3.5, -55), (4, -62), EXIT, (4, -74)]
CLEARINGS = [(-2.1, 5.0, 2.7), (4, -12, 3.1), (-3.5, -35.5, 2.5), (3.5, -55, 2.6), (4, -71.5, 2.0)]
# z, west inner edge, east inner edge. Raised continuous banks are the playable boundary.
BANKS = [(10, -8, 9), (0, -14, 14), (-10, -14, 14), (-18, -14, 12),
         (-28, -7, 8), (-40, -9, 2), (-50, -5, 7), (-60, -2, 10),
         (-70, -1, 9), (-76, -1, 9)]
TERRACES = [
    {'name': 'PondBank', 'height': 1.8, 'polygon': [(-13,-12),(-3,-12),(-2.8,-8),(-5.2,-6.8),(-9.8,-6),(-13,-6.6)]},
    {'name': 'CentralMeadow', 'height': 1.05, 'polygon': [(-1.4,-2),(1,-1),(3.6,-2.4),(3.5,-5.3),(1.5,-7.2),(-.9,-6.7),(-2,-4.8)]},
    {'name': 'EastBank', 'height': 1.65, 'polygon': [(8,-8),(13,-8),(13,-3),(9.5,-3.2),(8.3,-5)]},
]
for i, (a, b) in enumerate(zip(BANKS, BANKS[1:])):
    TERRACES.extend([
        {'name': 'WestBank%02d' % i, 'height': 2.4, 'polygon': [(-23,a[0]),(a[1],a[0]),(b[1],b[0]),(-23,b[0])]},
        {'name': 'EastBank%02d' % i, 'height': 2.4, 'polygon': [(a[2],a[0]),(23,a[0]),(23,b[0]),(b[2],b[0])]},
    ])
TERRACES.extend([
    {'name': 'SouthernForest', 'height': 2.4, 'polygon': [(-23,10),(23,10),(23,18),(-23,18)]},
    {'name': 'BeyondExit', 'height': 2.4, 'polygon': [(-23,-84),(23,-84),(23,-76),(-23,-76)]},
])


def segment_distance(x, z, a, b):
    dx, dz = b[0]-a[0], b[1]-a[1]
    t = max(0, min(1, ((x-a[0])*dx+(z-a[1])*dz)/(dx*dx+dz*dz)))
    return math.hypot(x-a[0]-t*dx, z-a[1]-t*dz)


def path_distance(x, z):
    return min(segment_distance(x,z,a,b) for a,b in zip(PATH, PATH[1:]))


def path_mask(x, z):
    d = min([path_distance(x,z)-1.2] + [math.hypot(x-cx,z-cz)-r for cx,cz,r in CLEARINGS])
    d += .035*math.sin(x*5+z*3) + .025*math.sin(z*7-x*4)
    return max(0, min(1, .5-d/.25))


def pond_distance(x,z):
    return math.hypot((x-POND[0])/1.12, z-POND[1])


def point_inside(x,z,poly):
    inside = False
    for a,b in zip(poly, poly[1:]+poly[:1]):
        if (a[1]>z)!=(b[1]>z) and x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]: inside = not inside
    return inside


def height_at(x,z):
    for terrace in TERRACES:
        if point_inside(x,z,terrace['polygon']): return terrace['height']
    return 0.


def bank_edges(z):
    for a,b in zip(BANKS, BANKS[1:]):
        if b[0] <= z <= a[0]:
            t = (z-a[0])/(b[0]-a[0])
            return (a[1]+(b[1]-a[1])*t, a[2]+(b[2]-a[2])*t)
    return (-8,9) if z>10 else (-1,9)


def placements():
    rng = random.Random(91342)
    items = []
    def add(asset,x,z,scale=1,yaw=None,y=0):
        items.append(dict(asset='forest_'+asset,x=x,z=z,y=y+height_at(x,z),scale=scale,yaw=rng.uniform(0,360) if yaw is None else yaw))
    def clear(x,z,margin=2.5):
        return (path_distance(x,z)>margin and path_mask(x,z)<.01
                and math.hypot(x-STUMP[0],z-STUMP[1])>3.2 and pond_distance(x,z)>3.2)
    add('stump',*STUMP,1.3,180)
    add('terraces',0,0,1,0)
    add('hollow_log',-5.6,-5.25,1.12,15)
    add('hollow_log',3.1,1.8,1.05,-30)
    add('hollow_log',-6.4,-35,1.05,12)
    add('hollow_log',7.0,-53,1.1,-15)
    add('gate',*EXIT,1,0)
    # Just a few landmarks per glade; large stretches of plain grass remain visible.
    for x,z,asset,scale in [(.2,-3.7,'rocks',1.65),(1.4,-4.7,'flowers_blue',1.3),
                           (8,-14,'oak',1.05),(-6.4,-38,'oak',1.0),(7.1,-56,'oak',1.0)]:
        add(asset,x,z,scale)
    for x,z,yaw in [(6.8,-12,0),(2.6,-.4,30),(-4,-.3,100),(.9,-68.8,0),(7.1,-68.8,0)]:
        add('fence',x,z,.95,yaw)
    # Canopies sit on the banks; the foreground shoulder stays open at gameplay zoom.
    tree_positions = []
    for iz in range(26):
        z = -81+iz*3.75
        for ix in range(12):
            x = -21+ix*3.8+rng.uniform(-.65,.65)
            zz = z+rng.uniform(-.65,.65)
            west,east = bank_edges(zz)
            on_bank = x<west-.65 or x>east+.85 or zz>11 or zz<-77
            if not on_bank or not clear(x,zz,3.4): continue
            if rng.random()<.14: continue
            # Lower near-camera edge trees avoid covering the walkable ribbon.
            scale = rng.uniform(.85,1.15)
            add(rng.choice(['pine','pine_b','pine_c']),x,zz,scale)
            tree_positions.append((x,zz))
    # A handful of trees on the broad opening banks, away from the path.
    for x,z,asset,scale in [(-10.8,-10,'pine_b',1.05),(10,-5.5,'pine_c',.95),
                           (-10.5,2,'pine',1.0),(9,1,'oak',.9),(-7,7,'pine_c',.9)]:
        add(asset,x,z,scale);tree_positions.append((x,z))
    # Small clusters at deliberately spaced anchors, not a uniform scatter of flowers.
    for z in range(-72,9,5):
        west,east = bank_edges(z)
        for edge,sign in [(west,1),(east,-1)]:
            x = edge + sign*rng.uniform(.6,1.0)
            if not clear(x,z,2.1): continue
            add('shrub',x,z,rng.uniform(1.2,1.6))
            add('fern',x+sign*.55,z+.65,rng.uniform(1.0,1.3))
            if rng.random()<.35: add('rocks',edge-sign*.2,z-1.0,rng.uniform(.9,1.35))
    for tx,tz in tree_positions[::3]:
        add('shrub',tx+.5,tz+.5,1.3)
    for x,z in [(-4.6,5.8),(-2,1.4),(-4.5,-6),(6.5,-14),(.1,-24),
                (-5.8,-31),(-1.1,-39),(.1,-47),(5.9,-57),(2,-65)]:
        if path_mask(x,z)<.1:
            add('fern',x,z,1.2)
            add('flowers_blue' if z>-30 else 'flowers_cream',x+.4,z+.45,1.0)
    for x,z in [(-4.8,2),(-4.9,4.8),(-2,1.1)]: add('fern',x,z,1.1)
    for x,z in [(-8.8,-1.8),(-5,-3.3),(-8.7,-5)]: add('reeds',x,z,1)
    for i in range(9):
        a=i/9*math.tau;x=POND[0]+3.05*math.cos(a);z=POND[1]+2.7*math.sin(a)
        if -9.3<x<-7.7 and z<-5.1: continue
        add('rocks',x,z,rng.uniform(.75,1.15))
    for x,z in [(-8,-2),(-6.8,-4.5),(-7.5,-3.1)]: add('lily',x,z,1,y=-.19)
    return items


if __name__ == '__main__':
    print('Route metres:', round(sum(math.dist(a,b) for a,b in zip(PATH,PATH[1:])),1))
    print('Saved props:',len(placements()))
