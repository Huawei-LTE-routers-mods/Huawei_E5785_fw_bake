#define _GNU_SOURCE
#include <stdlib.h>
#include <unistd.h>

int *ATP_LUA_Init(char *, int (*)(int, char*), int);
int ATP_LUA_DoString(int *, char*);
int ATP_DBInit(int);
int ATP_MSG_Init(char *);

const int MAX_SCRIPT_LEN = 252144;
char script[MAX_SCRIPT_LEN] = {0};

int read_stdin() {
    int ptr = 0;

    while(1) {
        int ret = read(0, script+ptr, MAX_SCRIPT_LEN-ptr);
        if (ret < 0) {
            return -1;
        } else if (ret == 0) {
            return ptr;
        }
        ptr += ret;
    }
}

int main() {
    ATP_DBInit(0x8);
    ATP_MSG_Init("luarun");
    int* lua_ctx = ATP_LUA_Init("luarun", 0, 0);

    if (!lua_ctx) {
        fprintf(stderr, "Failed to init lua\n");
        return 1;
    }

    int stdin_len = read_stdin();

    if (stdin_len == -1)  {
        fprintf(stderr, "Failed to read script from stdin\n");
        return 1;
    } else if (stdin_len >= MAX_SCRIPT_LEN) {
        fprintf(stderr, "The script is too big\n");
        return 1;
    }

    return ATP_LUA_DoString(lua_ctx, script);
}
