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

# --- check ---
check() {
	odin check src/editor \
		-vet -strict-style -vet-tabs -warnings-as-errors -disallow-do \
		-collection:ome=src
}

# --- build ---
build() {
	mkdir -p build
	odin build src/editor \
		-vet -strict-style -vet-tabs -vet-cast -warnings-as-errors -disallow-do \
		-collection:ome=src \
		-extra-linker-flags:"-L$(pwd)/build/lib" \
		-out:./build/editor

	./build/editor
}
if [ $# -eq 0 ]; then
    build
fi


while getopts "c" opt; do
    case "${opt}" in
        c)
        	check_result=$(check 2>/dev/null)
	         if [ -z "$check_result" ]; then
	             echo "Checked!"
	         fi
        ;;
    esac
done
