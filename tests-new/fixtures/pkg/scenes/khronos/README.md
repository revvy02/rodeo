# Khronos scene fixtures

Unmodified `glTF-Binary` assets from [Khronos glTF Sample Assets](https://github.com/KhronosGroup/glTF-Sample-Assets), pinned in `manifest.json` with source URLs and SHA-256 hashes. Each asset's upstream license is included alongside it.

These complement the small authored regression cases with externally authored textures, skinning, morphs, and animation interpolation. The shared scene test suite imports and re-exports each asset and runs the Khronos validator. Set `RODEO_SCENE_REVIEW_DIR` to retain exports for the Blender check:

```sh
RODEO_SCENE_REVIEW_DIR=/tmp/rodeo-scenes bun test --timeout 120000 tests-new/cli/pkg.test.ts -t 'scene:'
blender --background --python tests-new/utils/validate_scene_blender.py -- /tmp/rodeo-scenes
```
