cat logo
if command -v moon; then
  ./compile.sh
  moon main.moon
else
  lua main.lua
fi
