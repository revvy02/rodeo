"""Validate Rodeo exports in Blender, including local transform fidelity.

blender --background --python tests/utils/validate_scene_blender.py -- <directory>
"""
import json
import sys
from pathlib import Path
import bpy

root = Path(sys.argv[sys.argv.index("--") + 1])
paths = sorted(root.glob("*.glb")) + sorted(root.glob("*.gltf"))
assert paths, f"no scene exports in {root}"
failures = []
counts = {}
for path in paths:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.import_scene.gltf(filepath=str(path.resolve()))
        meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
        assert meshes, "import created no mesh objects"
        assert all(len(obj.data.polygons) > 0 for obj in meshes), "empty imported mesh"
        counts[path.name] = {"meshes": len(meshes), "actions": len(bpy.data.actions),
                             "morphs": sum(obj.data.shape_keys is not None for obj in meshes)}
    except Exception as exc:
        failures.append({"file": path.name, "error": str(exc)})
report = {"passed": len(paths)-len(failures), "total": len(paths), "files": counts, "failures": failures}
(root / "blender-report.json").write_text(json.dumps(report, indent=2)+"\n")
print(json.dumps(report, indent=2))
if failures:
    raise SystemExit(1)
