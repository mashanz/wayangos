/**
 * Generate 4 GLB 3D models for WayangOS hardware products
 * Uses @gltf-transform/core to build GLB files in Node.js (no browser APIs needed)
 * Run: node generate-models.mjs
 */
import { Document, NodeIO } from '@gltf-transform/core';
import fs from 'fs';
import path from 'path';

// Colors as linear RGB (approximate sRGB→linear)
const DARK = [0.008, 0.005, 0.004]; // #1a1410
const GOLD = [0.237, 0.096, 0.008]; // #c8941a
const SCREEN_COLOR = [0.352, 0.171, 0.014]; // #f0b830
const SCREEN_EMISSIVE = [0.352, 0.171, 0.014];
const GREEN_LED = [0.148, 0.280, 0.148]; // #7ec87e
const WHITE = [0.95, 0.93, 0.87];
const DARK_GREY = [0.03, 0.03, 0.03];
const RED_PIN = [0.5, 0.03, 0.03];
const ROAD_COLOR = [0.3, 0.15, 0.01];

/**
 * Create a box mesh and add it to the scene
 */
function addBox(doc, scene, parentNode, { width, height, depth, position, rotation, color, metallic = 0.6, roughness = 0.4, emissive }) {
  const w = width / 2, h = height / 2, d = depth / 2;
  
  // 8 vertices of a box, with normals for each face (we need 24 vertices for proper normals)
  const positions = [];
  const normals = [];
  const indices = [];
  
  // Front face (z+)
  const faces = [
    { n: [0,0,1], verts: [[-w,-h,d],[w,-h,d],[w,h,d],[-w,h,d]] },    // front
    { n: [0,0,-1], verts: [[-w,-h,-d],[-w,h,-d],[w,h,-d],[w,-h,-d]] }, // back
    { n: [0,1,0], verts: [[-w,h,-d],[-w,h,d],[w,h,d],[w,h,-d]] },     // top
    { n: [0,-1,0], verts: [[-w,-h,-d],[w,-h,-d],[w,-h,d],[-w,-h,d]] }, // bottom
    { n: [1,0,0], verts: [[w,-h,-d],[w,h,-d],[w,h,d],[w,-h,d]] },     // right
    { n: [-1,0,0], verts: [[-w,-h,-d],[-w,-h,d],[-w,h,d],[-w,h,-d]] } // left
  ];
  
  let vertIdx = 0;
  for (const face of faces) {
    for (const v of face.verts) {
      positions.push(...v);
      normals.push(...face.n);
    }
    indices.push(vertIdx, vertIdx+1, vertIdx+2, vertIdx, vertIdx+2, vertIdx+3);
    vertIdx += 4;
  }
  
  const mesh = doc.createMesh();
  const prim = doc.createPrimitive();
  
  const buf = doc._buffer;
  const posAccessor = doc.createAccessor().setType('VEC3').setArray(new Float32Array(positions)).setBuffer(buf);
  const normAccessor = doc.createAccessor().setType('VEC3').setArray(new Float32Array(normals)).setBuffer(buf);
  const idxAccessor = doc.createAccessor().setType('SCALAR').setArray(new Uint16Array(indices)).setBuffer(buf);
  
  const mat = doc.createMaterial()
    .setBaseColorFactor([...color, 1])
    .setMetallicFactor(metallic)
    .setRoughnessFactor(roughness);
  
  if (emissive) {
    mat.setEmissiveFactor(emissive);
  }
  
  prim.setAttribute('POSITION', posAccessor);
  prim.setAttribute('NORMAL', normAccessor);
  prim.setIndices(idxAccessor);
  prim.setMaterial(mat);
  mesh.addPrimitive(prim);
  
  const node = doc.createNode()
    .setMesh(mesh)
    .setTranslation(position || [0,0,0]);
  
  if (rotation) {
    // Convert euler angles to quaternion (simplified for single-axis rotations)
    const [rx, ry, rz] = rotation;
    const qx = [Math.sin(rx/2), 0, 0, Math.cos(rx/2)];
    const qy = [0, Math.sin(ry/2), 0, Math.cos(ry/2)];
    const qz = [0, 0, Math.sin(rz/2), Math.cos(rz/2)];
    // Combine: qz * qy * qx
    const q = multiplyQuaternions(multiplyQuaternions(qz, qy), qx);
    node.setRotation(q);
  }
  
  parentNode.addChild(node);
  return node;
}

function multiplyQuaternions(a, b) {
  return [
    a[3]*b[0] + a[0]*b[3] + a[1]*b[2] - a[2]*b[1],
    a[3]*b[1] - a[0]*b[2] + a[1]*b[3] + a[2]*b[0],
    a[3]*b[2] + a[0]*b[1] - a[1]*b[0] + a[2]*b[3],
    a[3]*b[3] - a[0]*b[0] - a[1]*b[1] - a[2]*b[2]
  ];
}

/**
 * Add a cylinder mesh (approximated with segments)
 */
function addCylinder(doc, scene, parentNode, { radiusTop, radiusBottom, height, segments = 16, position, rotation, color, metallic = 0.6, roughness = 0.4, emissive }) {
  const positions = [];
  const normals = [];
  const indices = [];
  const h2 = height / 2;
  
  // Side vertices
  for (let i = 0; i <= segments; i++) {
    const angle = (i / segments) * Math.PI * 2;
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);
    
    // Bottom vertex
    positions.push(radiusBottom * cos, -h2, radiusBottom * sin);
    const nx = cos, nz = sin;
    const len = Math.sqrt(nx*nx + nz*nz);
    normals.push(nx/len, 0, nz/len);
    
    // Top vertex
    positions.push(radiusTop * cos, h2, radiusTop * sin);
    normals.push(nx/len, 0, nz/len);
  }
  
  // Side faces
  for (let i = 0; i < segments; i++) {
    const a = i * 2;
    const b = a + 1;
    const c = a + 2;
    const d = a + 3;
    indices.push(a, c, b, b, c, d);
  }
  
  // Top cap
  const topCenter = positions.length / 3;
  positions.push(0, h2, 0);
  normals.push(0, 1, 0);
  for (let i = 0; i <= segments; i++) {
    const angle = (i / segments) * Math.PI * 2;
    positions.push(radiusTop * Math.cos(angle), h2, radiusTop * Math.sin(angle));
    normals.push(0, 1, 0);
  }
  for (let i = 0; i < segments; i++) {
    indices.push(topCenter, topCenter + 1 + i, topCenter + 2 + i);
  }
  
  // Bottom cap
  const botCenter = positions.length / 3;
  positions.push(0, -h2, 0);
  normals.push(0, -1, 0);
  for (let i = 0; i <= segments; i++) {
    const angle = (i / segments) * Math.PI * 2;
    positions.push(radiusBottom * Math.cos(angle), -h2, radiusBottom * Math.sin(angle));
    normals.push(0, -1, 0);
  }
  for (let i = 0; i < segments; i++) {
    indices.push(botCenter, botCenter + 2 + i, botCenter + 1 + i);
  }
  
  const mesh = doc.createMesh();
  const prim = doc.createPrimitive();
  
  const buf = doc._buffer;
  const posAccessor = doc.createAccessor().setType('VEC3').setArray(new Float32Array(positions)).setBuffer(buf);
  const normAccessor = doc.createAccessor().setType('VEC3').setArray(new Float32Array(normals)).setBuffer(buf);
  const idxAccessor = doc.createAccessor().setType('SCALAR').setArray(new Uint16Array(indices)).setBuffer(buf);
  
  const mat = doc.createMaterial()
    .setBaseColorFactor([...color, 1])
    .setMetallicFactor(metallic)
    .setRoughnessFactor(roughness);
  if (emissive) mat.setEmissiveFactor(emissive);
  
  prim.setAttribute('POSITION', posAccessor);
  prim.setAttribute('NORMAL', normAccessor);
  prim.setIndices(idxAccessor);
  prim.setMaterial(mat);
  mesh.addPrimitive(prim);
  
  const node = doc.createNode().setMesh(mesh).setTranslation(position || [0,0,0]);
  if (rotation) {
    const [rx, ry, rz] = rotation;
    const qx = [Math.sin(rx/2), 0, 0, Math.cos(rx/2)];
    const qy = [0, Math.sin(ry/2), 0, Math.cos(ry/2)];
    const qz = [0, 0, Math.sin(rz/2), Math.cos(rz/2)];
    node.setRotation(multiplyQuaternions(multiplyQuaternions(qz, qy), qx));
  }
  parentNode.addChild(node);
  return node;
}

function addSphere(doc, scene, parentNode, { radius, segments = 12, position, color, metallic = 0.3, roughness = 0.4, emissive }) {
  const positions = [];
  const normals = [];
  const indices = [];
  
  for (let lat = 0; lat <= segments; lat++) {
    const theta = (lat / segments) * Math.PI;
    const sinT = Math.sin(theta), cosT = Math.cos(theta);
    for (let lon = 0; lon <= segments; lon++) {
      const phi = (lon / segments) * Math.PI * 2;
      const sinP = Math.sin(phi), cosP = Math.cos(phi);
      const x = cosP * sinT, y = cosT, z = sinP * sinT;
      positions.push(radius * x, radius * y, radius * z);
      normals.push(x, y, z);
    }
  }
  
  for (let lat = 0; lat < segments; lat++) {
    for (let lon = 0; lon < segments; lon++) {
      const a = lat * (segments + 1) + lon;
      const b = a + segments + 1;
      indices.push(a, b, a + 1, b, b + 1, a + 1);
    }
  }
  
  const mesh = doc.createMesh();
  const prim = doc.createPrimitive();
  const buf = doc._buffer;
  const posAcc = doc.createAccessor().setType('VEC3').setArray(new Float32Array(positions)).setBuffer(buf);
  const normAcc = doc.createAccessor().setType('VEC3').setArray(new Float32Array(normals)).setBuffer(buf);
  const idxAcc = doc.createAccessor().setType('SCALAR').setArray(new Uint16Array(indices)).setBuffer(buf);
  
  const mat = doc.createMaterial().setBaseColorFactor([...color, 1]).setMetallicFactor(metallic).setRoughnessFactor(roughness);
  if (emissive) mat.setEmissiveFactor(emissive);
  
  prim.setAttribute('POSITION', posAcc);
  prim.setAttribute('NORMAL', normAcc);
  prim.setIndices(idxAcc);
  prim.setMaterial(mat);
  mesh.addPrimitive(prim);
  
  const node = doc.createNode().setMesh(mesh).setTranslation(position || [0,0,0]);
  parentNode.addChild(node);
  return node;
}

// ============ MODEL 1: WayangPOS ============
function createPOS(doc, scene, root) {
  // Screen body (angled ~15°)
  addBox(doc, scene, root, { width: 1.2, height: 0.8, depth: 0.06, position: [0, 0.7, 0], rotation: [-0.26, 0, 0], color: DARK });
  // Screen display
  addBox(doc, scene, root, { width: 1.05, height: 0.65, depth: 0.01, position: [0, 0.7, 0.035], rotation: [-0.26, 0, 0], color: SCREEN_COLOR, metallic: 0.1, roughness: 0.5, emissive: SCREEN_EMISSIVE });
  // Gold bezel top
  addBox(doc, scene, root, { width: 1.2, height: 0.02, depth: 0.07, position: [0, 1.1, -0.01], rotation: [-0.26, 0, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  // Stand neck
  addBox(doc, scene, root, { width: 0.08, height: 0.35, depth: 0.08, position: [0, 0.25, -0.05], color: DARK, metallic: 0.7 });
  // Stand base
  addCylinder(doc, scene, root, { radiusTop: 0.25, radiusBottom: 0.28, height: 0.04, position: [0, 0.02, -0.05], color: DARK, metallic: 0.8 });
  // SBC box
  addBox(doc, scene, root, { width: 0.2, height: 0.06, depth: 0.15, position: [0, 0.35, -0.15], color: DARK, metallic: 0.5 });
  // SBC gold accent
  addBox(doc, scene, root, { width: 0.2, height: 0.008, depth: 0.15, position: [0, 0.38, -0.15], color: GOLD, metallic: 0.8, roughness: 0.3 });
  // Thermal printer
  addBox(doc, scene, root, { width: 0.25, height: 0.2, depth: 0.2, position: [0.85, 0.1, 0], color: DARK });
  // Printer gold trim
  addBox(doc, scene, root, { width: 0.25, height: 0.01, depth: 0.2, position: [0.85, 0.2, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  // Paper slot
  addBox(doc, scene, root, { width: 0.15, height: 0.01, depth: 0.005, position: [0.85, 0.19, 0.1], color: DARK_GREY, metallic: 0.3, roughness: 0.6 });
  // Receipt paper
  addBox(doc, scene, root, { width: 0.12, height: 0.08, depth: 0.002, position: [0.85, 0.24, 0.1], rotation: [0.1, 0, 0], color: WHITE, metallic: 0, roughness: 0.9 });
}

// ============ MODEL 2: WayangDCIEM ============
function createDCIEM(doc, scene, root) {
  // 4 vertical posts
  const postPositions = [[-0.5, 1.0, -0.3], [0.5, 1.0, -0.3], [-0.5, 1.0, 0.3], [0.5, 1.0, 0.3]];
  for (const p of postPositions) {
    addBox(doc, scene, root, { width: 0.04, height: 2.0, depth: 0.04, position: p, color: DARK, metallic: 0.8, roughness: 0.2 });
  }
  // Gold accent strips on front posts
  for (const [x, y, z] of [[-0.5, 1.0, 0.32], [0.5, 1.0, 0.32]]) {
    addBox(doc, scene, root, { width: 0.045, height: 2.0, depth: 0.005, position: [x, y, z], color: GOLD, metallic: 0.8, roughness: 0.3 });
  }
  // Cross bars top/bottom
  for (const y of [0.01, 2.0]) {
    addBox(doc, scene, root, { width: 1.04, height: 0.03, depth: 0.04, position: [0, y, -0.3], color: DARK, metallic: 0.8, roughness: 0.2 });
    addBox(doc, scene, root, { width: 1.04, height: 0.03, depth: 0.04, position: [0, y, 0.3], color: DARK, metallic: 0.8, roughness: 0.2 });
    for (const x of [-0.5, 0.5]) {
      addBox(doc, scene, root, { width: 0.04, height: 0.03, depth: 0.64, position: [x, y, 0], color: DARK, metallic: 0.8, roughness: 0.2 });
    }
  }
  // Sensor nodes
  const sensorHeights = [0.4, 0.8, 1.2, 1.6];
  sensorHeights.forEach((h, i) => {
    const xOff = i % 2 === 0 ? -0.15 : 0.15;
    addBox(doc, scene, root, { width: 0.3, height: 0.1, depth: 0.25, position: [xOff, h, 0], color: DARK });
    addBox(doc, scene, root, { width: 0.3, height: 0.01, depth: 0.005, position: [xOff, h + 0.04, 0.127], color: GOLD, metallic: 0.8, roughness: 0.3 });
    addSphere(doc, scene, root, { radius: 0.015, segments: 8, position: [xOff + (i % 2 === 0 ? -0.15 : 0.15), h + 0.03, 0.13], color: GREEN_LED, emissive: GREEN_LED });
  });
  // Gateway box
  addBox(doc, scene, root, { width: 0.45, height: 0.08, depth: 0.35, position: [0, 0.12, 0], color: DARK, metallic: 0.5 });
  addBox(doc, scene, root, { width: 0.45, height: 0.008, depth: 0.35, position: [0, 0.165, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  // Gateway LEDs
  for (let i = 0; i < 3; i++) {
    addSphere(doc, scene, root, { radius: 0.012, segments: 8, position: [-0.15 + i * 0.1, 0.13, 0.18], color: GREEN_LED, emissive: GREEN_LED });
  }
}

// ============ MODEL 3: WayangGates ============
function createGates(doc, scene, root) {
  // Barrier post
  addBox(doc, scene, root, { width: 0.3, height: 1.0, depth: 0.3, position: [0, 0.5, 0], color: DARK, metallic: 0.7 });
  addBox(doc, scene, root, { width: 0.31, height: 0.02, depth: 0.31, position: [0, 0.95, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  
  // Boom arm
  addCylinder(doc, scene, root, { radiusTop: 0.03, radiusBottom: 0.03, height: 1.8, segments: 12, position: [0.9, 0.9, 0], rotation: [0, 0, Math.PI/2], color: GOLD, metallic: 0.8, roughness: 0.3 });
  // Dark stripes on arm
  for (let i = 0; i < 6; i++) {
    addCylinder(doc, scene, root, { radiusTop: 0.032, radiusBottom: 0.032, height: 0.08, segments: 12, position: [0.3 + i * 0.25, 0.9, 0], rotation: [0, 0, Math.PI/2], color: DARK });
  }
  // Arm end cap
  addSphere(doc, scene, root, { radius: 0.04, segments: 10, position: [1.8, 0.9, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  
  // Ticket kiosk
  addBox(doc, scene, root, { width: 0.4, height: 1.3, depth: 0.3, position: [-0.7, 0.65, 0], color: DARK });
  addBox(doc, scene, root, { width: 0.3, height: 0.25, depth: 0.01, position: [-0.7, 1.0, 0.155], color: SCREEN_COLOR, metallic: 0.1, roughness: 0.5, emissive: SCREEN_EMISSIVE });
  addBox(doc, scene, root, { width: 0.34, height: 0.29, depth: 0.005, position: [-0.7, 1.0, 0.15], color: GOLD, metallic: 0.8, roughness: 0.3 });
  addBox(doc, scene, root, { width: 0.15, height: 0.01, depth: 0.02, position: [-0.7, 0.7, 0.155], color: DARK_GREY, metallic: 0.5, roughness: 0.5 });
  addBox(doc, scene, root, { width: 0.4, height: 0.015, depth: 0.31, position: [-0.7, 1.3, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  
  // Camera
  addBox(doc, scene, root, { width: 0.1, height: 0.06, depth: 0.08, position: [0, 1.1, 0], color: DARK, metallic: 0.6 });
  addCylinder(doc, scene, root, { radiusTop: 0.02, radiusBottom: 0.025, height: 0.04, segments: 12, position: [0, 1.1, 0.06], rotation: [Math.PI/2, 0, 0], color: DARK_GREY, metallic: 0.9, roughness: 0.1 });
  addCylinder(doc, scene, root, { radiusTop: 0.015, radiusBottom: 0.015, height: 0.1, segments: 8, position: [0, 1.03, 0], color: DARK, metallic: 0.8 });
  
  // Ground base
  addBox(doc, scene, root, { width: 2.0, height: 0.03, depth: 0.8, position: [0.2, 0.015, 0], color: DARK, metallic: 0.3, roughness: 0.8 });
}

// ============ MODEL 4: WayangMAP ============
function createMAP(doc, scene, root) {
  // Base
  addBox(doc, scene, root, { width: 0.6, height: 0.08, depth: 0.4, position: [0, 0.04, 0], color: DARK, metallic: 0.7, roughness: 0.3 });
  addBox(doc, scene, root, { width: 0.62, height: 0.015, depth: 0.42, position: [0, 0.08, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  
  // Pedestal
  addBox(doc, scene, root, { width: 0.15, height: 0.8, depth: 0.15, position: [0, 0.48, 0], color: DARK, metallic: 0.6 });
  addBox(doc, scene, root, { width: 0.02, height: 0.8, depth: 0.005, position: [0, 0.48, 0.078], color: GOLD, metallic: 0.8, roughness: 0.3 });
  
  // Display head
  addBox(doc, scene, root, { width: 0.55, height: 0.9, depth: 0.08, position: [0, 1.38, 0], color: DARK });
  // Screen
  addBox(doc, scene, root, { width: 0.47, height: 0.75, depth: 0.01, position: [0, 1.38, 0.045], color: SCREEN_COLOR, metallic: 0.1, roughness: 0.5, emissive: SCREEN_EMISSIVE });
  
  // Gold bezel
  addBox(doc, scene, root, { width: 0.55, height: 0.02, depth: 0.085, position: [0, 1.83, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  addBox(doc, scene, root, { width: 0.55, height: 0.02, depth: 0.085, position: [0, 0.93, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  addBox(doc, scene, root, { width: 0.02, height: 0.9, depth: 0.085, position: [-0.275, 1.38, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  addBox(doc, scene, root, { width: 0.02, height: 0.9, depth: 0.085, position: [0.275, 1.38, 0], color: GOLD, metallic: 0.8, roughness: 0.3 });
  
  // Amber accent strip
  addBox(doc, scene, root, { width: 0.4, height: 0.008, depth: 0.005, position: [0, 0.9, 0.078], color: GOLD, emissive: GOLD });
  
  // Map elements on screen
  addBox(doc, scene, root, { width: 0.35, height: 0.015, depth: 0.005, position: [0, 1.35, 0.052], color: ROAD_COLOR, emissive: ROAD_COLOR });
  addBox(doc, scene, root, { width: 0.015, height: 0.4, depth: 0.005, position: [0.05, 1.4, 0.052], color: ROAD_COLOR, emissive: ROAD_COLOR });
  // Pin
  addSphere(doc, scene, root, { radius: 0.025, segments: 8, position: [0.05, 1.5, 0.055], color: RED_PIN, emissive: RED_PIN });
}

// ============ EXPORT ============
async function generateModel(name, buildFn) {
  const doc = new Document();
  const buffer = doc.createBuffer();
  doc._buffer = buffer; // Store ref for accessors
  const scene = doc.createScene();
  const root = doc.createNode(name);
  scene.addChild(root);
  
  buildFn(doc, scene, root);
  
  const io = new NodeIO();
  const glb = await io.writeBinary(doc);
  
  const outputPath = path.join('assets', 'models', name + '.glb');
  fs.writeFileSync(outputPath, glb);
  const sizeKB = (glb.byteLength / 1024).toFixed(1);
  console.log(`✓ ${outputPath} (${sizeKB} KB)`);
}

async function main() {
  console.log('Generating WayangOS 3D models...\n');
  
  // Ensure output directory exists
  fs.mkdirSync(path.join('assets', 'models'), { recursive: true });
  
  await generateModel('pos-terminal', createPOS);
  await generateModel('dciem-rack', createDCIEM);
  await generateModel('gate-system', createGates);
  await generateModel('map-kiosk', createMAP);
  
  console.log('\nDone! All models generated.');
}

main().catch(console.error);
