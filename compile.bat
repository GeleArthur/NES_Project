@echo off

mkdir build 2>nul
ca65 script.s -g -o build/script.o
ld65 -o build/script.nes -C script.cfg build/script.o -m build/script.map.txt -Ln build/script.labels.txt --dbgfile build/script.nes.dbg
