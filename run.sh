set -e
clear

LUA_VERSION=5.4.9
LUA_SRC=vendor/lua
LUA_LIB=build/lib/liblua5.4.a

# --- fetch Lua source once ---
if [ ! -d "$LUA_SRC" ]; then
	echo "fetching lua $LUA_VERSION..."
	mkdir -p vendor
	curl -sSL "https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz" | tar xz -C vendor
	mkdir -p "$LUA_SRC"
	mv vendor/lua-$LUA_VERSION/src/*.c vendor/lua-$LUA_VERSION/src/*.h "$LUA_SRC"/
	rm -rf "vendor/lua-$LUA_VERSION"
fi

# --- build liblua once ---
if [ ! -f "$LUA_LIB" ]; then
	echo "building liblua..."
	mkdir -p build/lib build/obj/lua
	for f in "$LUA_SRC"/*.c; do
	    b=$(basename "$f" .c)
	    [ "$b" = "lua" ] && continue   # standalone interpreter, has main()
	    [ "$b" = "luac" ] && continue  # bytecode compiler, has main()
	    cc -O2 -std=gnu99 -DLUA_USE_MACOSX -c "$f" -o "build/obj/lua/$b.o"
	done
	ar rcs "$LUA_LIB" build/obj/lua/*.o
fi

# --- build the engine ---
mkdir -p build
# -disallow-do
odin build src/editor \
	-vet -strict-style -vet-tabs -warnings-as-errors \
	-collection:ome=src \
	-extra-linker-flags:"-L$(pwd)/build/lib" \
	-out:./build/editor

./build/editor
