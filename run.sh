clear; clear; clear;

rm -rf build
mkdir -p build
odin build src/editor \
  -vet -strict-style -vet-tabs -warnings-as-errors \
  -collection:ome=src \
  -out:./build/editor

./build/editor

# -disallow-do
