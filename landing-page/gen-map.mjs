import { Document, NodeIO } from '@gltf-transform/core';

function createBox(doc, buf, name, w, h, d, r, g, b, addUV = false) {
  const hw = w/2, hh = h/2, hd = d/2;
  const positions = new Float32Array([
    -hw,-hh,-hd, hw,-hh,-hd, hw,hh,-hd, -hw,hh,-hd,
    hw,-hh,hd, -hw,-hh,hd, -hw,hh,hd, hw,hh,hd,
    -hw,hh,-hd, hw,hh,-hd, hw,hh,hd, -hw,hh,hd,
    -hw,-hh,hd, hw,-hh,hd, hw,-hh,-hd, -hw,-hh,-hd,
    hw,-hh,-hd, hw,-hh,hd, hw,hh,hd, hw,hh,-hd,
    -hw,-hh,hd, -hw,-hh,-hd, -hw,hh,-hd, -hw,hh,hd,
  ]);
  const normals = new Float32Array([
    0,0,-1, 0,0,-1, 0,0,-1, 0,0,-1,
    0,0,1, 0,0,1, 0,0,1, 0,0,1,
    0,1,0, 0,1,0, 0,1,0, 0,1,0,
    0,-1,0, 0,-1,0, 0,-1,0, 0,-1,0,
    1,0,0, 1,0,0, 1,0,0, 1,0,0,
    -1,0,0, -1,0,0, -1,0,0, -1,0,0,
  ]);
  const uvs = new Float32Array([
    1,0, 0,0, 0,1, 1,1,
    0,0, 1,0, 1,1, 0,1,
    0,0, 1,0, 1,1, 0,1,
    0,0, 1,0, 1,1, 0,1,
    0,0, 1,0, 1,1, 0,1,
    0,0, 1,0, 1,1, 0,1,
  ]);
  const indices = new Uint16Array([
    0,1,2, 0,2,3, 4,5,6, 4,6,7, 8,9,10, 8,10,11,
    12,13,14, 12,14,15, 16,17,18, 16,18,19, 20,21,22, 20,22,23,
  ]);
  const posA = doc.createAccessor().setType('VEC3').setArray(positions).setBuffer(buf);
  const normA = doc.createAccessor().setType('VEC3').setArray(normals).setBuffer(buf);
  const idxA = doc.createAccessor().setType('SCALAR').setArray(indices).setBuffer(buf);
  const mat = doc.createMaterial(name+'_mat').setBaseColorFactor([r,g,b,1]).setMetallicFactor(0).setRoughnessFactor(1);
  const prim = doc.createPrimitive().setAttribute('POSITION',posA).setAttribute('NORMAL',normA).setIndices(idxA).setMaterial(mat);
  if (addUV) {
    prim.setAttribute('TEXCOORD_0', doc.createAccessor().setType('VEC2').setArray(uvs).setBuffer(buf));
  }
  return doc.createMesh(name).addPrimitive(prim);
}

function addNode(scene, doc, name, mesh, pos) {
  scene.addChild(doc.createNode(name).setMesh(mesh).setTranslation(pos));
}

const BODY = [0.35, 0.33, 0.32];
const FRAME = [0.3, 0.3, 0.35];
const GOLD = [0.85, 0.65, 0.1];
const SCREEN = [0.9, 0.72, 0.15];
const LED = [0.2, 0.85, 0.25];

const io = new NodeIO();
const doc = new Document();
const buf = doc.createBuffer();
const scene = doc.createScene('MAP');

addNode(scene, doc, 'base', createBox(doc,buf,'base', 0.4, 0.05, 0.3, ...FRAME), [0, 0.025, 0]);
addNode(scene, doc, 'pillar', createBox(doc,buf,'pillar', 0.1, 1.2, 0.1, ...BODY), [0, 0.65, 0]);
addNode(scene, doc, 'head', createBox(doc,buf,'head', 0.55, 0.4, 0.04, ...BODY), [0, 1.45, 0]);

// Screen WITH UVs for screenshot
const scrMesh = createBox(doc,buf,'screen', 0.48, 0.34, 0.005, ...SCREEN, true);
scene.addChild(doc.createNode('screen').setMesh(scrMesh).setTranslation([0, 1.45, -0.023]));

addNode(scene, doc, 'accent', createBox(doc,buf,'acc', 0.55, 0.015, 0.045, ...GOLD), [0, 1.25, 0]);
addNode(scene, doc, 'topTrim', createBox(doc,buf,'tt', 0.55, 0.01, 0.045, ...GOLD), [0, 1.655, 0]);
addNode(scene, doc, 'led', createBox(doc,buf,'led', 0.015, 0.015, 0.015, ...LED), [0, 1.27, -0.023]);

await io.write('assets/models/map-kiosk.glb', doc);
console.log('MAP:', (await import('fs')).statSync('assets/models/map-kiosk.glb').size, 'bytes');
