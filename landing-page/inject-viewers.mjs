/**
 * Inject Three.js 3D viewers into product pages
 */
import fs from 'fs';
import path from 'path';

const pages = [
  { file: 'apps/pos.html', model: 'pos-terminal' },
  { file: 'apps/dciem.html', model: 'dciem-rack' },
  { file: 'apps/gates.html', model: 'gate-system' },
  { file: 'apps/map.html', model: 'map-kiosk' },
];

function makeViewer(modelName) {
  return `
    <!-- 3D Product Preview -->
    <section class="max-w-[800px] mx-auto px-6 pb-12">
      <div id="viewer3d" style="width:100%; height:400px; border-radius:16px; overflow:hidden; border:1px solid #2e2318; background:#0a0806;"></div>
      <p class="text-center text-w-dim text-sm mt-3"><span data-en="Drag to rotate &bull; Scroll to zoom" data-id="Geser untuk memutar &bull; Scroll untuk memperbesar">Drag to rotate &bull; Scroll to zoom</span></p>
    </section>

    <script type="module">
    import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.162/build/three.module.js';
    import { GLTFLoader } from 'https://cdn.jsdelivr.net/npm/three@0.162/examples/jsm/loaders/GLTFLoader.js';
    import { OrbitControls } from 'https://cdn.jsdelivr.net/npm/three@0.162/examples/jsm/controls/OrbitControls.js';

    const container = document.getElementById('viewer3d');
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x0a0806);
    const camera = new THREE.PerspectiveCamera(45, container.clientWidth / container.clientHeight, 0.1, 100);
    camera.position.set(0, 1.5, 3.5);

    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(container.clientWidth, container.clientHeight);
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    container.appendChild(renderer.domElement);

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.autoRotate = true;
    controls.autoRotateSpeed = 2;

    // Lighting
    scene.add(new THREE.AmbientLight(0xffffff, 0.4));
    const dirLight = new THREE.DirectionalLight(0xffffff, 0.8);
    dirLight.position.set(5, 5, 5);
    scene.add(dirLight);
    const rimLight = new THREE.DirectionalLight(0xc8941a, 0.3);
    rimLight.position.set(-3, 2, -3);
    scene.add(rimLight);

    new GLTFLoader().load('../assets/models/${modelName}.glb', (gltf) => {
      const model = gltf.scene;
      const box = new THREE.Box3().setFromObject(model);
      const center = box.getCenter(new THREE.Vector3());
      model.position.sub(center);
      scene.add(model);
    });

    window.addEventListener('resize', () => {
      camera.aspect = container.clientWidth / container.clientHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(container.clientWidth, container.clientHeight);
    });

    (function animate() {
      requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    })();
    </script>
`;
}

for (const { file, model } of pages) {
  let html = fs.readFileSync(file, 'utf8');
  
  // Check if already injected
  if (html.includes('viewer3d')) {
    console.log(`⚠ ${file} already has 3D viewer, skipping`);
    continue;
  }
  
  // Insert before <!-- Features --> section
  const marker = '    <!-- Features -->';
  if (html.includes(marker)) {
    html = html.replace(marker, makeViewer(model) + '\n' + marker);
    fs.writeFileSync(file, html);
    console.log(`✓ ${file} — injected ${model} viewer`);
  } else {
    // Try alternate: insert after hero screenshot closing div
    // Look for the pattern: </div>\n\n    <!-- ... next section
    const heroEnd = '<!-- Hero Screenshot -->';
    const heroIdx = html.indexOf(heroEnd);
    if (heroIdx !== -1) {
      // Find the closing </div> after the hero screenshot section
      const afterHero = html.indexOf('</div>', heroIdx + heroEnd.length);
      if (afterHero !== -1) {
        const insertPoint = afterHero + '</div>'.length;
        html = html.slice(0, insertPoint) + '\n' + makeViewer(model) + html.slice(insertPoint);
        fs.writeFileSync(file, html);
        console.log(`✓ ${file} — injected ${model} viewer (after hero)`);
      } else {
        console.log(`✗ ${file} — couldn't find insertion point`);
      }
    } else {
      console.log(`✗ ${file} — no hero screenshot or features marker found`);
    }
  }
}

console.log('\nDone!');
