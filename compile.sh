if which filepp; then
	CPP="filepp"
elif which cpp; then
	CPP="cpp -P"
else
	echo "No C preprocessor found"
	exit 1
fi
testfunc(){
	if ! which $1; then
		echo "$1 not found"
		exit 1
	fi
}

for func in moonc luac; do
	testfunc $func
done

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
		echo "Building $file"
		if $is_binary; then
			$CPP $file | moonc -- | luac -o $luafile -
		else
			$CPP $file | moonc -- > $luafile
		fi
		echo "Built $file"
		has_compiled=true
	fi
done
if $has_compiled; then
	printf "\n"
fi
