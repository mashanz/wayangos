import { Document, NodeIO } from '@gltf-transform/core';

function createBox(doc, buf, name, w, h, d, r, g, b) {
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
  const indices = new Uint16Array([
    0,1,2, 0,2,3, 4,5,6, 4,6,7, 8,9,10, 8,10,11,
    12,13,14, 12,14,15, 16,17,18, 16,18,19, 20,21,22, 20,22,23,
  ]);
  const posA = doc.createAccessor().setType('VEC3').setArray(positions).setBuffer(buf);
  const normA = doc.createAccessor().setType('VEC3').setArray(normals).setBuffer(buf);
  const idxA = doc.createAccessor().setType('SCALAR').setArray(indices).setBuffer(buf);
  const mat = doc.createMaterial(name+'_mat').setBaseColorFactor([r,g,b,1]).setMetallicFactor(0).setRoughnessFactor(1);
  const prim = doc.createPrimitive().setAttribute('POSITION',posA).setAttribute('NORMAL',normA).setIndices(idxA).setMaterial(mat);
  return doc.createMesh(name).addPrimitive(prim);
}

function addNode(scene, doc, name, mesh, pos) {
  scene.addChild(doc.createNode(name).setMesh(mesh).setTranslation(pos));
}

// HIGH CONTRAST colors — medium tones that pop on dark bg
const BODY = [0.35, 0.33, 0.32];     // Medium warm gray
const FRAME = [0.3, 0.3, 0.35];      // Steel
const GOLD = [0.85, 0.65, 0.1];      // Bright gold
const SCREEN = [0.9, 0.72, 0.15];    // Amber
const LED = [0.2, 0.85, 0.25];       // Green
const DARK = [0.18, 0.16, 0.15];     // Dark panels
const WHITE = [0.75, 0.73, 0.7];     // Off-white
const RED = [0.8, 0.2, 0.15];        // Red stripes
const RAIL = [0.28, 0.28, 0.32];     // Rail steel

const io = new NodeIO();

// ============ POS TERMINAL ============
{
  const doc = new Document(); const buf = doc.createBuffer();
  const scene = doc.createScene('POS');
  
  addNode(scene, doc, 'base', createBox(doc,buf,'base', 0.2, 0.015, 0.15, ...FRAME), [0, 0.0075, 0]);
  addNode(scene, doc, 'stand', createBox(doc,buf,'stand', 0.06, 0.15, 0.08, ...FRAME), [0, 0.09, -0.02]);
  addNode(scene, doc, 'body', createBox(doc,buf,'monBody', 0.35, 0.25, 0.025, ...BODY), [0, 0.24, -0.04]);
  addNode(scene, doc, 'screen', createBox(doc,buf,'monScr', 0.3, 0.2, 0.005, ...SCREEN), [0, 0.24, -0.055]);
  addNode(scene, doc, 'trim', createBox(doc,buf,'trim', 0.35, 0.008, 0.028, ...GOLD), [0, 0.115, -0.04]);
  addNode(scene, doc, 'trimTop', createBox(doc,buf,'trimT', 0.35, 0.008, 0.028, ...GOLD), [0, 0.365, -0.04]);
  
  // Printer
  addNode(scene, doc, 'printer', createBox(doc,buf,'printer', 0.12, 0.1, 0.15, ...BODY), [0.28, 0.05, 0]);
  addNode(scene, doc, 'slot', createBox(doc,buf,'slot', 0.08, 0.005, 0.02, ...DARK), [0.28, 0.1, -0.076]);
  addNode(scene, doc, 'pgold', createBox(doc,buf,'pg', 0.12, 0.006, 0.005, ...GOLD), [0.28, 0.08, -0.076]);
  addNode(scene, doc, 'paper', createBox(doc,buf,'paper', 0.06, 0.08, 0.002, ...WHITE), [0.28, 0.14, -0.078]);
  addNode(scene, doc, 'led', createBox(doc,buf,'led', 0.01, 0.01, 0.01, ...LED), [0.24, 0.095, -0.076]);
  
  await io.write('assets/models/pos-terminal.glb', doc);
  console.log('POS:', (await import('fs')).statSync('assets/models/pos-terminal.glb').size);
}

// ============ GATES ============
{
  const doc = new Document(); const buf = doc.createBuffer();
  const scene = doc.createScene('Gates');
  
  addNode(scene, doc, 'housing', createBox(doc,buf,'h', 0.2, 0.9, 0.25, ...BODY), [0, 0.45, 0]);
  addNode(scene, doc, 'htrim', createBox(doc,buf,'ht', 0.205, 0.02, 0.255, ...GOLD), [0, 0.85, 0]);
  addNode(scene, doc, 'arm', createBox(doc,buf,'arm', 2.0, 0.05, 0.05, ...WHITE), [1.0, 0.88, 0]);
  
  const stripe = createBox(doc,buf,'stripe', 0.15, 0.052, 0.052, ...RED);
  for (let i = 0; i < 5; i++) addNode(scene, doc, 's'+i, stripe, [0.3+i*0.4, 0.88, 0]);
  
  addNode(scene, doc, 'kiosk', createBox(doc,buf,'k', 0.3, 1.2, 0.25, ...BODY), [-0.8, 0.6, 0]);
  addNode(scene, doc, 'kscr', createBox(doc,buf,'ks', 0.2, 0.15, 0.005, ...SCREEN), [-0.8, 0.9, -0.128]);
  addNode(scene, doc, 'ktrim', createBox(doc,buf,'kt', 0.305, 0.02, 0.255, ...GOLD), [-0.8, 1.15, 0]);
  addNode(scene, doc, 'tslot', createBox(doc,buf,'ts', 0.1, 0.01, 0.03, ...DARK), [-0.8, 0.7, -0.128]);
  addNode(scene, doc, 'cam', createBox(doc,buf,'cam', 0.08, 0.06, 0.1, ...DARK), [0, 0.96, 0]);
  addNode(scene, doc, 'lens', createBox(doc,buf,'lens', 0.03, 0.03, 0.01, ...FRAME), [0, 0.96, -0.056]);
  
  const led = createBox(doc,buf,'led', 0.015, 0.015, 0.015, ...LED);
  addNode(scene, doc, 'l1', led, [-0.8, 1.05, -0.128]);
  addNode(scene, doc, 'l2', led, [-0.75, 1.05, -0.128]);
  
  await io.write('assets/models/gate-system.glb', doc);
  console.log('Gates:', (await import('fs')).statSync('assets/models/gate-system.glb').size);
}

// ============ MAP KIOSK ============
{
  const doc = new Document(); const buf = doc.createBuffer();
  const scene = doc.createScene('MAP');
  
  addNode(scene, doc, 'base', createBox(doc,buf,'base', 0.4, 0.05, 0.3, ...FRAME), [0, 0.025, 0]);
  addNode(scene, doc, 'pillar', createBox(doc,buf,'pillar', 0.1, 1.2, 0.1, ...BODY), [0, 0.65, 0]);
  addNode(scene, doc, 'head', createBox(doc,buf,'head', 0.55, 0.4, 0.04, ...BODY), [0, 1.45, 0]);
  addNode(scene, doc, 'screen', createBox(doc,buf,'scr', 0.48, 0.34, 0.005, ...SCREEN), [0, 1.45, -0.023]);
  addNode(scene, doc, 'accent', createBox(doc,buf,'acc', 0.55, 0.015, 0.045, ...GOLD), [0, 1.25, 0]);
  addNode(scene, doc, 'topTrim', createBox(doc,buf,'tt', 0.55, 0.01, 0.045, ...GOLD), [0, 1.655, 0]);
  addNode(scene, doc, 'led', createBox(doc,buf,'led', 0.015, 0.015, 0.015, ...LED), [0, 1.27, -0.023]);
  
  await io.write('assets/models/map-kiosk.glb', doc);
  console.log('MAP:', (await import('fs')).statSync('assets/models/map-kiosk.glb').size);
}

console.log('Done — medium contrast colors for dark background');
