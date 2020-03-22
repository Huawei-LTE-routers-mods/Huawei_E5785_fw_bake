/* $OpenBSD: includes.h,v 1.54 2006/07/22 20:48:23 stevesk Exp $ */

/*
 * Author: Tatu Ylonen <ylo@cs.hut.fi>
 * Copyright (c) 1995 Tatu Ylonen <ylo@cs.hut.fi>, Espoo, Finland
 *                    All rights reserved
 * This file includes most of the needed system headers.
 *
 * As far as I am concerned, the code I have written for this software
 * can be used freely for any purpose.  Any derived versions of this
 * software must be clearly marked as such, and if the derived work is
 * incompatible with the protocol description in the RFC file, it must be
 * called by a name other than "ssh" or "Secure Shell".
 */

#ifndef INCLUDES_H
#define INCLUDES_H

#include "config.h"

#define _GNU_SOURCE /* activate extra prototypes for glibc */

#include <sys/types.h>
#include <sys/param.h>
#include <sys/socket.h> /* For CMSG_* */

#include <limits.h> /* For PATH_MAX, _POSIX_HOST_NAME_MAX */
#include <endian.h>
#include <utime.h>
#include <paths.h>

/*
 *-*-nto-qnx needs these headers for strcasecmp and LASTLOG_FILE respectively
 */
# include <strings.h>

#  include <utmp.h>
#  include <lastlog.h>

# include <sys/select.h>
# include <stdint.h>
#include <termios.h>
# include <sys/cdefs.h> /* For __P() */
# include <sys/stat.h> /* For S_* constants and macros */
# include <sys/sysmacros.h> /* For MIN, MAX, etc */
# include <sys/time.h> /* for timespeccmp if present */
#include <sys/mman.h> /* for MAP_ANONYMOUS */

#include <netinet/in.h>
#include <netinet/in_systm.h> /* For typedefs */


#include <errno.h>

#include "defines.h"

#include "platform.h"

#include "openbsd-compat/openbsd-compat.h"
#include "openbsd-compat/bsd-nextstep.h"
#include "entropy.h"

#endif /* INCLUDES_H */
