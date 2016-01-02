has_compiled=false
is_binary=false
is_forcing=false
for arg in $*; do
	case $arg in
		-binary)
			is_binary=true
			;;
		-force-compile)
			is_forcing=true
			;;
	esac
done
for file in $(find . -type f -name "*.moon"); do
	luafile="${file%.*}.lua"
	if [ ! -f "$luafile" ] || [ $(stat -c "%Y" "${file}" ) -gt $(stat -c "%Y" "$luafile") ] || $is_forcing; then
		if ! $has_compiled; then
			printf "\n"
		fi
		if $is_binary; then
			moonc -p $file | luac -o $luafile -
			echo "Built $file"
		else
			moonc -o $luafile $file
		fi
		has_compiled=true
	fi
done
if $has_compiled; then
	printf "\n"
fi
