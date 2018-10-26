#!/bin/bash

MOONC="${MOONC:-moonc}"
LUAC="${LUAC:-luac}"

is_binary=false
is_forcing=false
for arg in $*; do
  case $arg in
    --bytecode|-b)
      is_binary=true
      ;;
    --force-compile|-f)
      is_forcing=true
      ;;
    --help|-h)
      echo "Usage: ./compile.sh [OPTIONS]"
      echo "Compile MoonScript files into Lua files - binary or source"
      echo ""
      echo "  -f, --force-compile   Force recompilation of all files"
      echo "  -b, --bytecode        Files are compiled to Lua bytecode"
      echo "  -h, --help            Display this message"
      exit 0
      ;;
  esac
done

find_command() {
  while (( "$#" )); do
    which "$1" >/dev/null 2>&1 || exit $?
    echo "Using $(which $1)"
    shift
  done
}

find_command $MOONC $LUAC

for file in $(find . -type f -name "*.moon"); do
  (
  luafile="${file%.*}.lua"
  if [ ! -f "$luafile" ] || [ $(stat -c "%Y" "${file}" ) -gt $(stat -c "%Y" "$luafile") ] || "$is_forcing"; then
    if $is_binary; then
      $MOONC -p "$file" | $LUAC -o "$luafile" -
    else
      $MOONC -o "$luafile" "$file"
    fi
  fi
  ) &
done
wait
ldoc . 2>&1 | grep -v 'module()'
