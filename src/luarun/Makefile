CC = armv7a-linux-androideabi17-clang

all: luarun

luarun: luarun.c
	$(CC) -W -ldl -L"./lib" -lrestcore -llua -lcfmapi -lmsgapi -O2 -s luarun.c -o luarun

