CC = armv7a-linux-androideabi16-clang

all: cms_hijack.so

cms_hijack.so: cms_hijack.c
	$(CC) -W -shared -ldl -fPIC -O2 -s cms_hijack.c -o cms_hijack.so

