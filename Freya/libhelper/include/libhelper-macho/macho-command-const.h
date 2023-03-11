//===------------------------ macho_command_consts---------------------===//
//
//                          Libhelper Mach-O Parser
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//
//  Copyright (C) 2019, Is This On?, @h3adsh0tzz
//  me@h3adsh0tzz.com.
//
//
//===------------------------------------------------------------------===//
/*
 * Copyright (c) 1999-2010 Apple Inc.  All Rights Reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef LIBHELPER_MACHO_COMMAND_CONST_H
#define LIBHELPER_MACHO_COMMAND_CONST_H

/**
 *                  === The Libhelper Project ===
 *                          Mach-O Parser
 * 
 *  Documentation relating to the macho-command-consts.h header file:
 *                                                                      
 *      This header contains a range of definitions for constants required
 *      by macho-command.h/.c. 
 * 
 *      The definitions in this file are taken from the mach-o/loader.h
 *      header that ships with macOS, so the Open Source License, under
 *      APSL, is included above.
 * 
 * 
 *  ----------------
 *  Original Author:
 *      Harry Moulton, @h3adsh0tzz  -   me@h3adsh0tzz.com.
 * 
 */



/**
 * 	Load command definitions. Mach-O's use these to map out the file structure, like
 * 	specifying where segment data, symbol tables, etc are located. These are simply 
 * 	the names, a structure definitions is later on.
 * 
 */
#define	LC_SEGMENT			0x1		/* segment of this file to be mapped */
#define	LC_SYMTAB			0x2		/* link-edit stab symbol table info */
#define	LC_SYMSEG			0x3		/* link-edit gdb symbol table info (obsolete) */

#define	LC_THREAD			0x4		/* thread */
#define	LC_UNIXTHREAD		0x5		/* unix thread (includes a stack) */
#define	LC_LOADFVMLIB		0x6		/* load a specified fixed VM shared library */
#define	LC_IDFVMLIB			0x7		/* fixed VM shared library identification */
#define	LC_IDENT			0x8		/* object identification info (obsolete) */
#define LC_FVMFILE			0x9		/* fixed VM file inclusion (internal use) */
#define LC_PREPAGE      	0xa     /* prepage command (internal use) */
#define	LC_DYSYMTAB			0xb		/* dynamic link-edit symbol table info */
#define	LC_LOAD_DYLIB		0xc		/* load a dynamically linked shared library */
#define	LC_ID_DYLIB			0xd		/* dynamically linked shared lib ident */
#define LC_LOAD_DYLINKER 	0xe		/* load a dynamic linker */
#define LC_ID_DYLINKER		0xf		/* dynamic linker identification */
#define	LC_PREBOUND_DYLIB 	0x10	/* modules prebound for a dynamically */
#define	LC_ROUTINES			0x11	/* image routines */
#define	LC_SUB_FRAMEWORK 	0x12	/* sub framework */
#define	LC_SUB_UMBRELLA 	0x13	/* sub umbrella */
#define	LC_SUB_CLIENT		0x14	/* sub client */
#define	LC_SUB_LIBRARY  	0x15	/* sub library */
#define	LC_TWOLEVEL_HINTS 	0x16	/* two-level namespace lookup hints */
#define	LC_PREBIND_CKSUM  	0x17	/* prebind checksum */

#define	LC_LOAD_WEAK_DYLIB (0x18 | 0x80000000)

#define LC_SEGMENT_64					0x19	/* 64-bit segment of this file to be mapped */
#define	LC_ROUTINES_64					0x1a	/* 64-bit image routines */
#define LC_UUID							0x1b	/* the uuid */
#define LC_RPATH       					(0x1c | 0x80000000)    /* runpath additions */
#define LC_CODE_SIGNATURE 				0x1d	/* local of code signature */
#define LC_SEGMENT_SPLIT_INFO 			0x1e 	/* local of info to split segments */
#define LC_REEXPORT_DYLIB 				(0x1f | 0x80000000) 	/* load and re-export dylib */
#define	LC_LAZY_LOAD_DYLIB 				0x20	/* delay load of dylib until first use */
#define	LC_ENCRYPTION_INFO 				0x21	/* encrypted segment information */
#define	LC_DYLD_INFO 					0x22	/* compressed dyld information */
#define	LC_DYLD_INFO_ONLY 				(0x22| 0x80000000)		/* compressed dyld information only */
#define	LC_LOAD_UPWARD_DYLIB 			(0x23 | 0x80000000) 	/* load upward dylib */
#define LC_VERSION_MIN_MACOSX 			0x24   	/* build for MacOSX min OS version */
#define LC_VERSION_MIN_IPHONEOS 		0x25 	/* build for iPhoneOS min OS version */
#define LC_FUNCTION_STARTS 				0x26 	/* compressed table of function start addresses */
#define LC_DYLD_ENVIRONMENT				0x27 	/* string for dyld to treat like environment variable */
#define LC_MAIN 						(0x28| 0x80000000) 		/* replacement for LC_UNIXTHREAD */
#define LC_DATA_IN_CODE 				0x29 	/* table of non-instructions in __text */
#define LC_SOURCE_VERSION 				0x2A 	/* source version used to build binary */
#define LC_DYLIB_CODE_SIGN_DRS 			0x2B 	/* Code signing DRs copied from linked dylibs */
#define	LC_ENCRYPTION_INFO_64 			0x2C 	/* 64-bit encrypted segment information */
#define LC_LINKER_OPTION 				0x2D 	/* linker options in MH_OBJECT files */
#define LC_LINKER_OPTIMIZATION_HINT 	0x2E 	/* optimization hints in MH_OBJECT files */
#define LC_VERSION_MIN_TVOS 			0x2F 	/* build for AppleTV min OS version */
#define LC_VERSION_MIN_WATCHOS 			0x30 	/* build for Watch min OS version */
#define LC_NOTE 						0x31 	/* arbitrary data included within a Mach-O file */
#define LC_BUILD_VERSION 				0x32 	/* build for platform min OS version */
#define LC_DYLD_EXPORTS_TRIE 			(0x33 | 0x80000000) 	/* used with linkedit_data_command, payload is trie */
#define LC_DYLD_CHAINED_FIXUPS 			(0x34 | 0x80000000) 	/* used with linkedit_data_command */


#endif /* libhelper_macho_command_const_h */