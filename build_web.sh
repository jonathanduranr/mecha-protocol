#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Compilando Mecha Protocol para Web..."
godot --headless --export-release "Web" builds/web/index.html
echo "Compilación Web completada con éxito."
