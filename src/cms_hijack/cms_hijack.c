#define _GNU_SOURCE
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

static int (*ATP_UTIL_ExecCmdNoHang_real)(char*) = 0;

// /*
//  * Hijacked functions from various libraries.
//  */

int ATP_UTIL_ExecCmdNoHang(char *cmd) {
    if (!cmd) {
        return 1;
    }

    if (!ATP_UTIL_ExecCmdNoHang_real) {
         ATP_UTIL_ExecCmdNoHang_real = dlsym(RTLD_NEXT, "ATP_UTIL_ExecCmdNoHang");
         if (!ATP_UTIL_ExecCmdNoHang_real) {
            return 1;
         }
    }
    // block switch commands
    if (strcmp(cmd, "busybox echo type=switch switch=on action=set > /sys/devices/spe") == 0) {
        return 1;
    } else if (strcmp(cmd, "busybox echo type=switch switch=off action=set > /sys/devices/spe") == 0) {
        return 1;
    }

    return ATP_UTIL_ExecCmdNoHang_real(cmd);
}

/*
int ATP_TRACE_PrintInfo(char *sourcefile, int line, int linep, char *name,
                     int offset, const char *message, ...) {
    va_list args;
    va_start(args, message);
    fprintf(stderr, "%d (%d): \n", sourcefile, line, linep);
    vfprintf(stderr, message, args);
    va_end(args);

    return 0;
}
*/
