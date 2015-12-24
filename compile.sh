has_compiled=false
for file in $(find . -type f -name "*.moon"); do
	luafile="${file%.*}.lua"
	if [ ! -f "$luafile" ] || [ $(stat -c "%Y" "${file}" ) -gt $(stat -c "%Y" "$luafile") ]; then
		if ! $has_compiled; then
			printf "\n"
		fi
		moonc $file
		luac -o $luafile $luafile
		has_compiled=true
	fi
done
if $has_compiled; then
	printf "\n"
fi
