import glob

old_lights = """    // Lighting
    scene.add(new THREE.AmbientLight(0xffffff, 0.7));
    const dirLight = new THREE.DirectionalLight(0xffffff, 0.8);
    dirLight.position.set(5, 5, 5);
    dirLight.castShadow = true;
    scene.add(dirLight);
    const rimLight = new THREE.DirectionalLight(0xc8941a, 0.3);
    rimLight.position.set(-3, 2, -3);
    scene.add(rimLight);"""

new_lights = """    // Lighting — 4-point studio rig, bright, visible reflections
    scene.add(new THREE.AmbientLight(0xffffff, 1.2));
    const keyLight = new THREE.DirectionalLight(0xffffff, 1.0);
    keyLight.position.set(3, 5, 4);
    scene.add(keyLight);
    const fillLight = new THREE.DirectionalLight(0xffffff, 0.6);
    fillLight.position.set(-3, 4, 3);
    scene.add(fillLight);
    const backLight = new THREE.DirectionalLight(0xffffff, 0.5);
    backLight.position.set(0, 3, -4);
    scene.add(backLight);
    const accentLight = new THREE.PointLight(0xc8941a, 0.4, 10);
    accentLight.position.set(0, -1, 2);
    scene.add(accentLight);"""

for fname in ['apps/pos.html', 'apps/dciem.html', 'apps/gates.html', 'apps/map.html']:
    with open(fname, 'r', encoding='utf-8') as fh:
        content = fh.read()
    
    if old_lights in content:
        content = content.replace(old_lights, new_lights)
        
        # Better tone mapping
        content = content.replace(
            "renderer.toneMapping = THREE.ACESFilmicToneMapping;",
            "renderer.toneMapping = THREE.ACESFilmicToneMapping;\n    renderer.toneMappingExposure = 1.3;"
        )
        
        # Lighter ground with slight metalness for reflections
        content = content.replace(
            'new THREE.MeshStandardMaterial({ color: 0xd0d0d0, roughness: 0.8 })',
            'new THREE.MeshStandardMaterial({ color: 0xe0e0e0, roughness: 0.4, metalness: 0.15 })'
        )
        
        with open(fname, 'w', encoding='utf-8') as fh:
            fh.write(content)
        print(f"Fixed {fname}")
    else:
        print(f"SKIP {fname} - pattern not found")
