#!/usr/bin/env python3
"""Read-only GLB inspection: animation/root invariants and normalized skin weights."""
import argparse,json,math,struct
from pathlib import Path

def read_glb(path):
    data=Path(path).read_bytes()
    magic,version,length=struct.unpack_from('<III',data)
    if magic!=0x46546c67 or version!=2 or length!=len(data):raise ValueError('Invalid GLB 2 header')
    pos=12;doc=None;binary=b''
    while pos<len(data):
        size,kind=struct.unpack_from('<II',data,pos);chunk=data[pos+8:pos+8+size];pos+=8+size
        if kind==0x4e4f534a:doc=json.loads(chunk)
        if kind==0x004e4942:binary=chunk
    if doc is None:raise ValueError('Missing JSON chunk')
    return doc,binary

def values(doc,binary,index):
    a=doc['accessors'][index]
    if 'sparse' in a:raise ValueError('Sparse accessor unsupported by this lightweight inspector')
    n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    fmt,size,denom={5120:('b',1,127),5121:('B',1,255),5122:('h',2,32767),5123:('H',2,65535),5125:('I',4,4294967295),5126:('f',4,1)}[a['componentType']]
    view=doc['bufferViews'][a['bufferView']];stride=view.get('byteStride',n*size)
    start=view.get('byteOffset',0)+a.get('byteOffset',0)
    for i in range(a['count']):
        row=struct.unpack_from('<'+fmt*n,binary,start+i*stride)
        if a.get('normalized'):row=tuple(max(-1,v/denom) for v in row)
        yield row

def inspect(path,root_name='root'):
    d,b=read_glb(path);nodes=d.get('nodes',[]);root_indices={i for i,n in enumerate(nodes) if n.get('name')==root_name}
    errors=[];clips=[];triangles=0;max_weight_error=0;weighted_vertices=0
    for mesh in d.get('meshes',[]):
        for primitive in mesh['primitives']:
            if 'indices' in primitive:triangles+=d['accessors'][primitive['indices']]['count']//3
            weights=primitive['attributes'].get('WEIGHTS_0')
            if weights is not None:
                for row in values(d,b,weights):
                    weighted_vertices+=1;max_weight_error=max(max_weight_error,abs(sum(row)-1))
                    if not all(math.isfinite(v) and v>=0 for v in row):errors.append('Invalid skin weight')
    for anim in d.get('animations',[]):
        times=[];root_static=True
        for channel in anim['channels']:
            sample=anim['samplers'][channel['sampler']]
            times.extend(row[0] for row in values(d,b,sample['input']))
            if channel['target'].get('node') in root_indices:
                rows=list(values(d,b,sample['output']))
                if rows and any(max(abs(a-c) for a,c in zip(rows[0],row))>1e-4 for row in rows):root_static=False
        if not root_static:errors.append('Moving root in '+anim.get('name','unnamed'))
        clips.append({'name':anim.get('name'),'duration':max(times)-min(times) if times else 0,'root_static':root_static})
    if weighted_vertices and max_weight_error>.002:errors.append('Skin weights do not sum to one')
    return {'file':str(Path(path).resolve()),'meshes':len(d.get('meshes',[])),'triangles':triangles,'nodes':[n.get('name') for n in nodes], 'skins':len(d.get('skins',[])),'weighted_vertices':weighted_vertices,'max_weight_error':max_weight_error,'animations':clips,'root_found':bool(root_indices),'errors':sorted(set(errors)),'visual_review_required':True}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('glb');parser.add_argument('--root-bone',default='root');parser.add_argument('--output')
    args=parser.parse_args();report=inspect(args.glb,args.root_bone);out=json.dumps(report,indent=2)
    if args.output:Path(args.output).write_text(out+'\n')
    print(out);raise SystemExit(1 if report['errors'] else 0)
