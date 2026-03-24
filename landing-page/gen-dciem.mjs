import { Document, NodeIO } from '@gltf-transform/core';

function createBox(doc, buf, name, w, h, d, r, g, b, addUV = false) {
  const hw=w/2, hh=h/2, hd=d/2;
  const positions = new Float32Array([
    -hw,-hh,-hd, hw,-hh,-hd, hw,hh,-hd, -hw,hh,-hd,
    hw,-hh,hd, -hw,-hh,hd, -hw,hh,hd, hw,hh,hd,
    -hw,hh,-hd, hw,hh,-hd, hw,hh,hd, -hw,hh,hd,
    -hw,-hh,hd, hw,-hh,hd, hw,-hh,-hd, -hw,-hh,-hd,
    hw,-hh,-hd, hw,-hh,hd, hw,hh,hd, hw,hh,-hd,
    -hw,-hh,hd, -hw,-hh,-hd, -hw,hh,-hd, -hw,hh,hd,
  ]);
  const normals = new Float32Array([
    0,0,-1, 0,0,-1, 0,0,-1, 0,0,-1,  0,0,1, 0,0,1, 0,0,1, 0,0,1,
    0,1,0, 0,1,0, 0,1,0, 0,1,0,  0,-1,0, 0,-1,0, 0,-1,0, 0,-1,0,
    1,0,0, 1,0,0, 1,0,0, 1,0,0,  -1,0,0, -1,0,0, -1,0,0, -1,0,0,
  ]);
  const uvs = new Float32Array([
    1,0, 0,0, 0,1, 1,1,  0,0, 1,0, 1,1, 0,1,
    0,0, 1,0, 1,1, 0,1,  0,0, 1,0, 1,1, 0,1,
    0,0, 1,0, 1,1, 0,1,  0,0, 1,0, 1,1, 0,1,
  ]);
  const indices = new Uint16Array([
    0,1,2,0,2,3, 4,5,6,4,6,7, 8,9,10,8,10,11,
    12,13,14,12,14,15, 16,17,18,16,18,19, 20,21,22,20,22,23,
  ]);
  const posA = doc.createAccessor().setType('VEC3').setArray(positions).setBuffer(buf);
  const normA = doc.createAccessor().setType('VEC3').setArray(normals).setBuffer(buf);
  const idxA = doc.createAccessor().setType('SCALAR').setArray(indices).setBuffer(buf);
  const mat = doc.createMaterial(name+'_m').setBaseColorFactor([r,g,b,1]).setMetallicFactor(0).setRoughnessFactor(1);
  const prim = doc.createPrimitive().setAttribute('POSITION',posA).setAttribute('NORMAL',normA).setIndices(idxA).setMaterial(mat);
  if(addUV) prim.setAttribute('TEXCOORD_0', doc.createAccessor().setType('VEC2').setArray(uvs).setBuffer(buf));
  return doc.createMesh(name).addPrimitive(prim);
}

let nodeId = 0;
function add(scene, doc, mesh, pos) {
  scene.addChild(doc.createNode('n'+(nodeId++)).setMesh(mesh).setTranslation(pos));
}

const io = new NodeIO();
const doc = new Document();
const buf = doc.createBuffer();
const scene = doc.createScene('DCIEM');

// Rack dimensions
const RW=0.6, RD=0.8, RH=2.0, POST=0.05, U=0.044;
const DW=0.482, DD=0.45; // 19" device width, depth
const BASE=0.07; // caster height

// Colors
const STEEL=[0.15,0.15,0.17];
const RAIL_C=[0.2,0.2,0.22];
const MOUNT=[0.12,0.12,0.14];
const CASTER=[0.1,0.1,0.1];
const FOOT=[0.18,0.18,0.18];

// Server colors
const DELL_1U=[0.12,0.12,0.14];   // Dell R630 - dark charcoal
const DELL_2U=[0.14,0.14,0.16];   // Dell R760 - slightly lighter
const DELL_BEZEL=[0.08,0.08,0.1]; // Front bezel
const DELL_HANDLE=[0.25,0.25,0.28]; // Pull handles
const DRIVE_BAY=[0.1,0.1,0.12];   // Drive bay slots

const PSU_C=[0.13,0.13,0.15];     // 4U PSU
const PSU_FAN=[0.08,0.08,0.1];    // PSU fan grille

const SW_C=[0.15,0.18,0.22];      // Mikrotik switch blue-ish
const SW_PORT=[0.06,0.06,0.08];   // Port holes
const PORT_LED=[0.15,0.85,0.2];   // Port activity LED

const PDU_C=[0.1,0.1,0.12];       // PDU strip
const CABLE_P=[0.05,0.05,0.06];   // Power cable (black)
const CABLE_N=[0.1,0.15,0.5];     // Network cable (blue)
const CABLE_NY=[0.6,0.55,0.1];    // Network cable (yellow)
const OUTLET=[0.2,0.2,0.22];      // PDU outlet

const GOLD=[0.85,0.65,0.1];
const SCREEN_C=[0.9,0.72,0.15];
const LED_G=[0.2,0.85,0.25];
const LED_B=[0.2,0.4,0.85];

const RAILKIT=[0.18,0.18,0.2];

// Shared meshes
const postM = createBox(doc,buf,'post',POST,RH,POST,...STEEL);
const mountM = createBox(doc,buf,'mnt',0.025,RH-0.1,0.008,...MOUNT);
const sideBraceM = createBox(doc,buf,'sb',POST,0.015,RD-POST*2,...RAIL_C);
const thinRailM = createBox(doc,buf,'tr',RW-POST*2,0.012,POST*0.5,...RAIL_C);
const casterM = createBox(doc,buf,'cst',0.04,0.05,0.04,...CASTER);
const footM = createBox(doc,buf,'ft',0.06,0.02,0.06,...FOOT);

// 1U Dell R630
const r630body = createBox(doc,buf,'r630',DW,U*0.9,DD,...DELL_1U);
const r630bezel = createBox(doc,buf,'r630bz',DW,U*0.9,0.008,...DELL_BEZEL);
const r630handle = createBox(doc,buf,'r630h',0.04,U*0.6,0.005,...DELL_HANDLE);
const r630drive = createBox(doc,buf,'r630d',0.025,U*0.5,0.005,...DRIVE_BAY);
const r630led = createBox(doc,buf,'r630l',0.006,0.006,0.006,...LED_G);
const r630pwled = createBox(doc,buf,'r630pl',0.008,0.008,0.008,...LED_B);

// 2U Dell R760
const r760body = createBox(doc,buf,'r760',DW,U*1.9,DD,...DELL_2U);
const r760bezel = createBox(doc,buf,'r760bz',DW,U*1.9,0.008,...DELL_BEZEL);
const r760handle = createBox(doc,buf,'r760h',0.04,U*1.4,0.005,...DELL_HANDLE);
const r760drive = createBox(doc,buf,'r760d',0.03,U*1.2,0.005,...DRIVE_BAY);

// 1U Switch (Mikrotik CRS326-24G)
const swBody = createBox(doc,buf,'sw',DW,U*0.9,DD*0.6,...SW_C);
const swPort = createBox(doc,buf,'swp',0.014,0.012,0.005,...SW_PORT);
const swLed = createBox(doc,buf,'swl',0.004,0.004,0.004,...PORT_LED);

// 4U PSU
const psuBody = createBox(doc,buf,'psu',DW,U*3.8,DD,...PSU_C);
const psuFan = createBox(doc,buf,'pfan',0.06,0.06,0.005,...PSU_FAN);
const psuLed = createBox(doc,buf,'pled',0.01,0.01,0.008,...LED_G);

// Rail kits
const rkM = createBox(doc,buf,'rk',0.025,U+0.006,DD,...RAILKIT);

// PDU (vertical, on back post)
const pduM = createBox(doc,buf,'pdu',0.06,RH*0.8,0.05,...PDU_C);
const outletM = createBox(doc,buf,'out',0.03,0.02,0.008,...OUTLET);

// Cables
const pcableM = createBox(doc,buf,'pc',0.008,0.008,0.15,...CABLE_P);
const ncableM = createBox(doc,buf,'nc',0.005,0.005,0.12,...CABLE_N);
const ncableYM = createBox(doc,buf,'ncy',0.005,0.005,0.12,...CABLE_NY);

// Sensor node (our WayangDCIEM device) — GOLD body to stand out from servers
const sensorM = createBox(doc,buf,'sens',DW,U*0.9,DD*0.5,...[0.65,0.5,0.1]);
const sensorFace = createBox(doc,buf,'sface',DW,U*0.9,0.008,...GOLD);
const goldM = createBox(doc,buf,'gold',DW,0.006,0.004,...GOLD);
const sensorLabel = createBox(doc,buf,'slbl',0.06,0.015,0.004,...[0.9,0.75,0.15]);
const scrM = createBox(doc,buf,'screen',0.08,0.022,0.004,...SCREEN_C,true);

// KVM sliding tray — pulled out, monitor open
const kvmTrayM = createBox(doc,buf,'kvmt',DW,0.012,DD*0.8,...RAIL_C);       // Slide-out tray
const kvmSlideL = createBox(doc,buf,'kvsl',0.02,0.015,DD*0.9,...MOUNT);     // Left slide rail
const kvmSlideR = createBox(doc,buf,'kvsr',0.02,0.015,DD*0.9,...MOUNT);     // Right slide rail
const kvmKbBody = createBox(doc,buf,'kvkb',DW*0.85,0.01,0.18,...[0.1,0.1,0.12]);  // Keyboard
const kvmKbKeys = createBox(doc,buf,'kvkk',DW*0.75,0.005,0.14,...[0.15,0.15,0.18]); // Keycap area
const kvmTouchpad = createBox(doc,buf,'kvtp',0.08,0.005,0.06,...[0.12,0.12,0.14]);  // Touchpad
const kvmMonFrame = createBox(doc,buf,'kvmf',DW*0.9,0.22,0.012,...[0.1,0.1,0.12]);  // Monitor frame
const kvmScreen = createBox(doc,buf,'kvmscreen',DW*0.82,0.18,0.005,...SCREEN_C,true);  // Screen w/ UVs — name must match viewer check
const kvmHinge = createBox(doc,buf,'kvmh',DW*0.3,0.015,0.02,...MOUNT);      // Hinge

const frontZ = -RD/2 + POST + 0.005; // front face Z for bezels
const devZ = -RD/2 + POST + DD/2 + 0.01; // center Z for device bodies
const backZ = RD/2 - POST - 0.03; // back Z for PDU/cables

const NUM_RACKS = 4;
const GAP = 0.03;
const totalW = NUM_RACKS * RW + (NUM_RACKS - 1) * GAP;
const startX = -totalW / 2 + RW / 2;

// Rack layouts: each item = [startU, type]
// type: '1u'=R630, '2u'=R760, 'sw'=switch, 'psu'=4U PSU, 'sensor'=our device, 'kvm'=KVM tray
const layouts = [
  // Rack 0 (controller rack) — KVM at U6
  [[1,'psu'],[5,'sw'],[6,'kvm'],[7,'1u'],[8,'2u'],[10,'1u'],[11,'2u'],[13,'1u'],[14,'2u'],[16,'1u'],[17,'2u'],[19,'1u'],[20,'sensor'],[22,'1u'],[23,'2u'],[25,'1u'],[26,'2u'],[28,'1u'],[29,'2u'],[31,'1u'],[32,'2u'],[34,'1u'],[35,'2u'],[37,'1u'],[38,'2u'],[40,'1u'],[41,'1u']],
  // Rack 1
  [[1,'psu'],[5,'sw'],[7,'2u'],[9,'2u'],[11,'2u'],[13,'1u'],[14,'2u'],[16,'sensor'],[17,'2u'],[19,'2u'],[21,'1u'],[22,'2u'],[24,'2u'],[26,'2u'],[28,'1u'],[29,'2u'],[31,'2u'],[33,'1u'],[34,'2u'],[36,'2u'],[38,'2u'],[40,'1u'],[41,'1u']],
  // Rack 2
  [[1,'psu'],[5,'sw'],[7,'1u'],[8,'1u'],[9,'2u'],[11,'1u'],[12,'2u'],[14,'2u'],[16,'1u'],[17,'2u'],[19,'2u'],[21,'sensor'],[22,'2u'],[24,'1u'],[25,'2u'],[27,'2u'],[29,'1u'],[30,'2u'],[32,'2u'],[34,'1u'],[35,'2u'],[37,'2u'],[39,'1u'],[40,'2u']],
  // Rack 3
  [[1,'psu'],[5,'sw'],[7,'2u'],[9,'1u'],[10,'2u'],[12,'2u'],[14,'1u'],[15,'2u'],[17,'1u'],[18,'2u'],[20,'2u'],[22,'1u'],[23,'2u'],[25,'sensor'],[26,'2u'],[28,'2u'],[30,'1u'],[31,'2u'],[33,'2u'],[35,'1u'],[36,'2u'],[38,'1u'],[39,'2u'],[41,'1u']],
];

for (let i = 0; i < NUM_RACKS; i++) {
  const x = startX + i * (RW + GAP);
  
  // Posts
  for (const [cx,cz] of [[-1,-1],[1,-1],[-1,1],[1,1]]) {
    add(scene,doc,postM,[x+cx*(RW/2-POST/2), RH/2+BASE, cz*(RD/2-POST/2)]);
  }
  
  // Mounting rails (front pair)
  for (const cx of [-DW/2-0.012, DW/2+0.012]) {
    add(scene,doc,mountM,[x+cx, RH/2+BASE, -RD/2+POST+0.01]);
  }
  
  // Side braces (at U7, U21, U35 + top + bottom)
  for (const uPos of [0, 7, 21, 35, 42]) {
    const by = uPos*U + BASE + (uPos===0?0.01:uPos===42?-0.01:0);
    for (const cx of [-RW/2+POST/2, RW/2-POST/2]) {
      add(scene,doc,sideBraceM,[x+cx, by, 0]);
    }
  }
  // Thin top/bottom front-back rails
  for (const cz of [-RD/2+POST/2, RD/2-POST/2]) {
    add(scene,doc,thinRailM,[x, RH+BASE-0.006, cz]);
    add(scene,doc,thinRailM,[x, BASE+0.006, cz]);
  }
  
  // Casters
  for (const [cx,cz] of [[-1,-1],[1,-1],[-1,1],[1,1]]) {
    add(scene,doc,casterM,[x+cx*(RW/2-POST/2), 0.025, cz*(RD/2-POST/2)]);
    add(scene,doc,footM,[x+cx*(RW/2-POST/2), 0.06, cz*(RD/2-POST/2)]);
  }
  
  // PDU on back-right post
  add(scene,doc,pduM,[x+RW/2-POST-0.04, RH*0.45+BASE, backZ]);
  // PDU outlets (every 2U)
  for (let u=2; u<40; u+=2) {
    add(scene,doc,outletM,[x+RW/2-POST-0.04, u*U+BASE, backZ-0.03]);
  }
  
  // Devices
  for (const [startU, type] of layouts[i]) {
    const baseY = startU * U + BASE;
    
    if (type === '1u') {
      const cy = baseY + U*0.45;
      add(scene,doc,r630body,[x, cy, devZ]);
      add(scene,doc,r630bezel,[x, cy, frontZ]);
      add(scene,doc,rkM,[x-DW/2-0.013, cy, devZ]);
      add(scene,doc,rkM,[x+DW/2+0.013, cy, devZ]);
      // Handles
      add(scene,doc,r630handle,[x-DW/2+0.025, cy, frontZ-0.003]);
      add(scene,doc,r630handle,[x+DW/2-0.025, cy, frontZ-0.003]);
      // Drive bays (8 small)
      for(let d=0;d<8;d++) add(scene,doc,r630drive,[x-0.12+d*0.032, cy, frontZ-0.005]);
      // LEDs
      add(scene,doc,r630led,[x-DW/2+0.01, cy+U*0.3, frontZ-0.005]);
      add(scene,doc,r630pwled,[x-DW/2+0.01, cy-U*0.1, frontZ-0.005]);
      // Power cable to PDU
      add(scene,doc,pcableM,[x+RW/4, cy, devZ+DD/2+0.08]);
      // Network cable
      add(scene,doc,(i%2===0?ncableM:ncableYM),[x-RW/4, cy, devZ+DD/2+0.06]);
    }
    
    if (type === '2u') {
      const cy = baseY + U*0.95;
      add(scene,doc,r760body,[x, cy, devZ]);
      add(scene,doc,r760bezel,[x, cy, frontZ]);
      add(scene,doc,rkM,[x-DW/2-0.013, cy, devZ]);
      add(scene,doc,rkM,[x+DW/2+0.013, cy, devZ]);
      // Handles
      add(scene,doc,r760handle,[x-DW/2+0.025, cy, frontZ-0.003]);
      add(scene,doc,r760handle,[x+DW/2-0.025, cy, frontZ-0.003]);
      // Drive bays (12 wider)
      for(let d=0;d<12;d++) add(scene,doc,r760drive,[x-0.18+d*0.032, cy, frontZ-0.005]);
      // LEDs
      add(scene,doc,r630led,[x-DW/2+0.01, cy+U*0.6, frontZ-0.005]);
      add(scene,doc,r630pwled,[x-DW/2+0.01, cy+U*0.2, frontZ-0.005]);
      // Cables
      add(scene,doc,pcableM,[x+RW/4, cy, devZ+DD/2+0.08]);
      add(scene,doc,(i%2===0?ncableYM:ncableM),[x-RW/4, cy, devZ+DD/2+0.06]);
    }
    
    if (type === 'sw') {
      const cy = baseY + U*0.45;
      add(scene,doc,swBody,[x, cy, devZ-0.08]);
      add(scene,doc,rkM,[x-DW/2-0.013, cy, devZ-0.08]);
      add(scene,doc,rkM,[x+DW/2+0.013, cy, devZ-0.08]);
      // 24 ports
      for(let p=0;p<24;p++) {
        add(scene,doc,swPort,[x-0.17+p*0.0148, cy, frontZ-0.003]);
        if(p%3===0) add(scene,doc,swLed,[x-0.17+p*0.0148, cy+U*0.3, frontZ-0.003]);
      }
      // SFP ports (2)
      add(scene,doc,swPort,[x+0.19, cy, frontZ-0.003]);
      add(scene,doc,swPort,[x+0.21, cy, frontZ-0.003]);
    }
    
    if (type === 'psu') {
      const cy = baseY + U*1.9;
      add(scene,doc,psuBody,[x, cy, devZ]);
      add(scene,doc,rkM,[x-DW/2-0.013, cy, devZ]);
      add(scene,doc,rkM,[x+DW/2+0.013, cy, devZ]);
      // Front fans (3)
      for(let f=0;f<3;f++) add(scene,doc,psuFan,[x-0.1+f*0.1, cy, frontZ-0.003]);
      // LEDs
      add(scene,doc,psuLed,[x-DW/2+0.015, cy+U*1.5, frontZ-0.003]);
      add(scene,doc,psuLed,[x-DW/2+0.015, cy+U*1.2, frontZ-0.003]);
    }
    
    if (type === 'kvm') {
      const cy = baseY + U*0.45;
      const pullOut = 0.35; // how far tray slides out from rack
      const trayZ = frontZ - pullOut;
      // Slide rails (stay inside rack, extend forward)
      add(scene,doc,kvmSlideL,[x-DW/2+0.01, cy, trayZ+DD*0.25]);
      add(scene,doc,kvmSlideR,[x+DW/2-0.01, cy, trayZ+DD*0.25]);
      // Tray
      add(scene,doc,kvmTrayM,[x, cy-0.005, trayZ]);
      // Keyboard on tray
      add(scene,doc,kvmKbBody,[x, cy+0.005, trayZ+0.02]);
      add(scene,doc,kvmKbKeys,[x, cy+0.009, trayZ+0.01]);
      // Touchpad (below keyboard)
      add(scene,doc,kvmTouchpad,[x, cy+0.005, trayZ-0.11]);
      // Hinge at back of keyboard
      add(scene,doc,kvmHinge,[x, cy+0.018, trayZ+0.12]);
      // Monitor — tilted open (raised behind keyboard)
      const monY = cy + 0.14;
      const monZ = trayZ + 0.13;
      add(scene,doc,kvmMonFrame,[x, monY, monZ]);
      // Screen with DCIEM dashboard screenshot — named 'kvmscreen' 
      const kvmScrNode = doc.createNode('kvmscreen').setMesh(kvmScreen).setTranslation([x, monY, monZ-0.009]);
      scene.addChild(kvmScrNode);
      // Rail kits
      add(scene,doc,rkM,[x-DW/2-0.013, cy, devZ]);
      add(scene,doc,rkM,[x+DW/2+0.013, cy, devZ]);
    }
    
    if (type === 'sensor') {
      const cy = baseY + U*0.45;
      add(scene,doc,sensorM,[x, cy, devZ-0.05]);
      add(scene,doc,sensorFace,[x, cy, frontZ-0.003]); // Gold front panel
      add(scene,doc,rkM,[x-DW/2-0.013, cy, devZ-0.05]);
      add(scene,doc,rkM,[x+DW/2+0.013, cy, devZ-0.05]);
      add(scene,doc,goldM,[x, cy+U*0.4, frontZ-0.008]);
      add(scene,doc,sensorLabel,[x-0.1, cy, frontZ-0.008]); // "DCIEM" label area
      for(let j=0;j<5;j++) add(scene,doc,r630led,[x+0.06+j*0.015, cy, frontZ-0.008]); // More LEDs
      // Controller screen on rack 0 sensor
      if(i===0) {
        scene.addChild(doc.createNode('screen').setMesh(scrM).setTranslation([x+0.15, cy, frontZ-0.008]));
      }
    }
  }
}

await io.write('assets/models/dciem-rack.glb', doc);
const s = (await import('fs')).statSync('assets/models/dciem-rack.glb');
console.log('DCIEM:', s.size, 'bytes');
