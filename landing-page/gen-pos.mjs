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
  // UVs for each face - front face (face 0) gets full 0-1 mapping for texture
  const uvs = new Float32Array([
    // Front face - this is where the screenshot shows (flipped U to un-mirror)
    1,0, 0,0, 0,1, 1,1,
    // Back
    0,0, 1,0, 1,1, 0,1,
    // Top
    0,0, 1,0, 1,1, 0,1,
    // Bottom
    0,0, 1,0, 1,1, 0,1,
    // Right
    0,0, 1,0, 1,1, 0,1,
    // Left
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
  const prim = doc.createPrimitive()
    .setAttribute('POSITION', posA)
    .setAttribute('NORMAL', normA)
    .setIndices(idxA)
    .setMaterial(mat);
  
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

const io = new NodeIO();
const doc = new Document();
const buf = doc.createBuffer();
const scene = doc.createScene('POS');

// Base plate
addNode(scene, doc, 'base', createBox(doc,buf,'base', 0.22, 0.015, 0.16, ...FRAME), [0, 0.0075, 0]);

// Stand
addNode(scene, doc, 'stand', createBox(doc,buf,'stand', 0.05, 0.18, 0.05, ...FRAME), [0, 0.105, 0.02]);

// Monitor group — pivot at top of stand for tilting
const monPivotY = 0.195; // top of stand
const monGroup = doc.createNode('posMonitor').setTranslation([0, monPivotY, 0.02]);
const monOffY = 0.32 - monPivotY; // offset from pivot to monitor center
monGroup.addChild(doc.createNode('n_bezel').setMesh(createBox(doc,buf,'bezel', 0.38, 0.28, 0.025, ...BODY)).setTranslation([0, monOffY, -0.02]));
const scrMesh = createBox(doc,buf,'screen', 0.32, 0.22, 0.005, ...SCREEN, true);
monGroup.addChild(doc.createNode('screen').setMesh(scrMesh).setTranslation([0, monOffY, -0.034]));
monGroup.addChild(doc.createNode('n_trimT').setMesh(createBox(doc,buf,'trimT', 0.38, 0.008, 0.028, ...GOLD)).setTranslation([0, monOffY + 0.14, -0.02]));
monGroup.addChild(doc.createNode('n_trimB').setMesh(createBox(doc,buf,'trimB', 0.38, 0.008, 0.028, ...GOLD)).setTranslation([0, monOffY - 0.14, -0.02]));
scene.addChild(monGroup);

// Printer body (static)
addNode(scene, doc, 'printer', createBox(doc,buf,'printer', 0.13, 0.1, 0.15, ...BODY), [0.3, 0.05, 0]);
addNode(scene, doc, 'slot', createBox(doc,buf,'slot', 0.08, 0.005, 0.02, ...DARK), [0.3, 0.1, -0.076]);
addNode(scene, doc, 'pgold', createBox(doc,buf,'pg', 0.13, 0.006, 0.005, ...GOLD), [0.3, 0.08, -0.076]);
addNode(scene, doc, 'led1', createBox(doc,buf,'led1', 0.008, 0.008, 0.008, ...LED), [0.26, 0.095, -0.076]);
addNode(scene, doc, 'led2', createBox(doc,buf,'led2', 0.008, 0.008, 0.008, ...LED), [0.275, 0.095, -0.076]);

// Receipt paper — animated group, slides up from printer slot
const paperGroup = doc.createNode('posReceipt').setTranslation([0.3, 0.1, -0.078]);
paperGroup.addChild(doc.createNode('n_paper').setMesh(createBox(doc,buf,'paper', 0.06, 0.12, 0.002, ...WHITE)).setTranslation([0, 0.06, 0]));
scene.addChild(paperGroup);

await io.write('assets/models/pos-terminal.glb', doc);
const stats = (await import('fs')).statSync('assets/models/pos-terminal.glb');
console.log('POS:', stats.size, 'bytes');
