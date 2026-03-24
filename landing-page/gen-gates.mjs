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
    const uvA = doc.createAccessor().setType('VEC2').setArray(uvs).setBuffer(buf);
    prim.setAttribute('TEXCOORD_0', uvA);
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
const DARK = [0.18, 0.16, 0.15];
const WHITE = [0.75, 0.73, 0.7];
const RED = [0.8, 0.2, 0.15];

const io = new NodeIO();
const doc = new Document();
const buf = doc.createBuffer();
const scene = doc.createScene('Gates');

// Barrier housing
addNode(scene, doc, 'housing', createBox(doc,buf,'h', 0.2, 0.9, 0.25, ...BODY), [0, 0.45, 0]);
addNode(scene, doc, 'htrim', createBox(doc,buf,'ht', 0.205, 0.02, 0.255, ...GOLD), [0, 0.85, 0]);

// Boom arm group — pivot at hinge point on top of housing
// Arm rotates around Z axis at (0, 0.88, 0)
const boomGroup = doc.createNode('boomArm').setTranslation([0, 0.88, 0]);
const armMesh = createBox(doc,buf,'arm', 2.0, 0.05, 0.05, ...WHITE);
const stripeMesh = createBox(doc,buf,'stripe', 0.15, 0.052, 0.052, ...RED);
// Arm — offset from pivot (center of arm is 1.0 to the right of pivot)
boomGroup.addChild(doc.createNode('armbar').setMesh(armMesh).setTranslation([1.0, 0, 0]));
// Red stripes on arm
for (let i = 0; i < 5; i++) {
  boomGroup.addChild(doc.createNode('st'+i).setMesh(stripeMesh).setTranslation([0.3+i*0.4, 0, 0]));
}
scene.addChild(boomGroup);

// Ticket kiosk
addNode(scene, doc, 'kiosk', createBox(doc,buf,'k', 0.3, 1.2, 0.25, ...BODY), [-0.8, 0.6, 0]);

// Kiosk screen WITH UVs for screenshot
const kScreen = createBox(doc,buf,'screen', 0.2, 0.15, 0.005, ...SCREEN, true);
scene.addChild(doc.createNode('screen').setMesh(kScreen).setTranslation([-0.8, 0.9, -0.128]));

addNode(scene, doc, 'ktrim', createBox(doc,buf,'kt', 0.305, 0.02, 0.255, ...GOLD), [-0.8, 1.15, 0]);
addNode(scene, doc, 'tslot', createBox(doc,buf,'ts', 0.1, 0.01, 0.03, ...DARK), [-0.8, 0.7, -0.128]);

// Camera
addNode(scene, doc, 'cam', createBox(doc,buf,'cam', 0.08, 0.06, 0.1, ...DARK), [0, 0.96, 0]);
addNode(scene, doc, 'lens', createBox(doc,buf,'lens', 0.03, 0.03, 0.01, ...FRAME), [0, 0.96, -0.056]);

// LEDs
const led = createBox(doc,buf,'led', 0.015, 0.015, 0.015, ...LED);
addNode(scene, doc, 'l1', led, [-0.8, 1.05, -0.128]);
addNode(scene, doc, 'l2', led, [-0.75, 1.05, -0.128]);

await io.write('assets/models/gate-system.glb', doc);
console.log('Gates:', (await import('fs')).statSync('assets/models/gate-system.glb').size, 'bytes');
