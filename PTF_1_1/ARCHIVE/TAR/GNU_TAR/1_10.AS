#! /bin/sh
# This is a shell archive.  Remove anything before this line, then unpack
# it by saving it into a file and typing "sh file".  To overwrite existing
# files, type "sh file -c".  You can also feed this as standard input via
# unshar, or by typing "sh <file", e.g..  If this archive is complete, you
# will see the following message at the end:
#		"End of shell archive."
# Contents:  tar.c create.c extract.c buffer.c getoldopt.c update.c
#   gnu.c mangle.c version.c list.c names.c diffarch.c port.c
#   wildmat.c getopt.c getopt1.c regex.c getdate.y rtape_lib.c README
#   COPYING ChangeLog Makefile tar.texinfo tar.h port.h open3.h rmt.h
#   msd_dir.h msd_dir.c rtape_server.c rtape_lib.c getdate.y getopt.h
#   regex.h level-0 level-1 backup-specs testpad.c
# Wrapped by mib@geech.gnu.ai.mit.edu on Mon Jul  1 14:25:45 1991
PATH=/bin:/usr/bin:/usr/ucb ; export PATH
if test -f 'tar.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'tar.c'\"
else
echo shar: Extracting \"'tar.c'\" \(31481 characters\)
sed "s/^X//" >'tar.c' <<'END_OF_FILE'
X/* Tar -- a tape archiver.
X
X	Copyright (C) 1988 Free Software Foundation
X
XGNU tar is distributed in the hope that it will be useful, but WITHOUT ANY
XWARRANTY.  No author or distributor accepts responsibility to anyone
Xfor the consequences of using it or for whether it serves any
Xparticular purpose or works at all, unless he says so in writing.
XRefer to the GNU tar General Public License for full details.
X
XEveryone is granted permission to copy, modify and redistribute GNU tar,
Xbut only under the conditions described in the GNU tar General Public
XLicense.  A copy of this license is supposed to have been given to you
Xalong with GNU tar so you can know your rights and responsibilities.  It
Xshould be in a file named COPYING.  Among other things, the copyright
Xnotice and this notice must be preserved on all copies.
X
XIn other words, go ahead and share GNU tar, but don't try to stop
Xanyone else from sharing it farther.  Help stamp out software hoarding!
X*/
X
X/*
X * A tar (tape archiver) program.
X *
X * Written by John Gilmore, ihnp4!hoptoad!gnu, starting 25 Aug 85.
X *
X * @(#)tar.c 1.34 11/6/87 - gnu
X */
X
X#include <stdio.h>
X#include <sys/types.h>		/* Needed for typedefs in tar.h */
X#include <sys/stat.h>		/* JF */
X#include "getopt.h"
X#include "regex.h"
X
X#ifdef USG
X#define rindex strrchr
X#endif
X
X#ifdef BSD42
X#include <sys/dir.h>
X#else
X#ifdef __MSDOS__
X#include "msd_dir.h"
X#else
X#ifdef USG
X#ifdef NDIR
X#include <ndir.h>
X#else
X#include <dirent.h>
X#endif
X#ifndef DIRECT
X#define direct dirent
X#endif
X#define DP_NAMELEN(x) strlen((x)->d_name)
X#else
X/*
X * FIXME: On other systems there is no standard place for the header file
X * for the portable directory access routines.  Change the #include line
X * below to bring it in from wherever it is.
X */
X#include "ndir.h"
X#endif
X#endif
X#endif
X
X#ifndef DP_NAMELEN
X#define DP_NAMELEN(x)	(x)->d_namlen
X#endif
X
Xextern char 	*malloc();
Xextern char 	*getenv();
Xextern char	*strncpy();
Xextern char	*index();
Xextern char	*strcpy();	/* JF */
Xextern char	*strcat();	/* JF */
X
Xextern char	*optarg;	/* Pointer to argument */
Xextern int	optind;		/* Global argv index from getopt */
X
Xextern char 	*ck_malloc();
Xextern char 	*ck_realloc();
X/*
X * The following causes "tar.h" to produce definitions of all the
X * global variables, rather than just "extern" declarations of them.
X */
X#define TAR_EXTERN /**/
X#include "tar.h"
X
X/*
X * We should use a conversion routine that does reasonable error
X * checking -- atoi doesn't.  For now, punt.  FIXME.
X */
X#define intconv	atoi
Xextern int	getoldopt();
Xextern void	read_and();
Xextern void	list_archive();
Xextern void	extract_archive();
Xextern void	diff_archive();
Xextern void	create_archive();
Xextern void	update_archive();
Xextern void	junk_archive();
X
X/* JF */
Xextern time_t	get_date();
X
Xtime_t new_time;
X
Xstatic FILE	*namef;		/* File to read names from */
Xstatic char	**n_argv;	/* Argv used by name routines */
Xstatic int	n_argc;		/* Argc used by name routines */
Xstatic char	**n_ind;	/* Store an array of names */
Xstatic int	n_indalloc;	/* How big is the array? */
Xstatic int	n_indused;	/* How many entries does it have? */
Xstatic int	n_indscan;	/* How many of the entries have we scanned? */
X
X
Xextern FILE *msg_file;
X
Xvoid	describe();
Xvoid	options();
X
X#ifndef S_IFLNK
X#define lstat stat
X#endif
X
X#ifndef DEFBLOCKING
X#define DEFBLOCKING 20
X#endif
X
X#ifndef DEF_AR_FILE
X#define DEF_AR_FILE "tar.out"
X#endif
X
X/* For long options that unconditionally set a single flag, we have getopt
X   do it.  For the others, we share the code for the equivalent short
X   named option, the name of which is stored in the otherwise-unused `val'
X   field of the `struct option'; for long options that have no equivalent
X   short option, we use nongraphic characters as pseudo short option
X   characters, starting (for no particular reason) with character 10. */
X
Xstruct option long_options[] =
X{
X	{"create",		0,	0,			'c'},
X	{"append",		0,	0,			'r'},
X	{"extract",		0,	0,			'x'},
X	{"get",			0,	0,			'x'},
X	{"list",		0,	0,			't'},
X	{"update",		0,	0,			'u'},
X	{"catenate",		0,	0,			'A'},
X	{"concatenate",		0,	0,			'A'},
X	{"compare",		0,	0,			'd'},
X	{"diff",		0,	0,			'd'},
X	{"delete",		0,	0,			14},
X	{"help",		0,	0,			12},
X
X	{"directory",		1,	0,			'C'},
X	{"record-number",	0,	&f_sayblock,		1},
X	{"files-from",		1,	0,			'T'},
X	{"label",		1,	0,			'V'},
X	{"exclude-from",	1,	0,			'X'},
X	{"exclude",		1,	0,			15},
X	{"file",		1,	0,			'f'},
X	{"block-size",		1,	0,			'b'},
X	{"version",		0,	0,			11},
X	{"verbose", 		0,	0,			'v'},
X	{"totals",		0,	&f_totals,		1},
X	  
X	{"read-full-blocks",	0,	&f_reblock,		1},
X	{"starting-file",	1,	0,			'K'},
X	{"to-stdout",		0,	&f_exstdout,		1},
X	{"ignore-zeros",	0,	&f_ignorez,		1},
X	{"keep-old-files",	0,	0,			'k'},
X	{"uncompress",		0,	&f_compress,		1},
X	{"same-permissions",	0,	&f_use_protection,	1},
X	{"preserve-permissions",0,	&f_use_protection,	1},
X	{"modification-time",	0,	&f_modified,		1},
X	{"preserve",		0,	0,			10},
X	{"same-order",		0,	&f_sorted_names,	1},
X	{"same-owner",		0,	&f_do_chown,		1},
X	{"preserve-order",	0,	&f_sorted_names,	1},
X
X	{"newer",		1,	0,			'N'},
X	{"after-date",		1,	0,			'N'},
X	{"newer-mtime",		1,	0,			13},
X	{"incremental",		0,	0,			'G'},
X	{"listed-incremental",	1,	0,			'g'},
X	{"multi-volume",	0,	&f_multivol,		1},
X	{"info-script",		1,	&f_run_script_at_end,	1},
X	{"absolute-paths",	0,	&f_absolute_paths,	1},
X	{"interactive",		0,	&f_confirm,		1},
X	{"confirmation",	0,	&f_confirm,		1},
X
X	{"verify",		0,	&f_verify,		1},
X	{"dereference",		0,	&f_follow_links,	1},
X	{"one-file-system",	0,	&f_local_filesys, 	1},
X	{"old-archive",		0,	0,			'o'},
X	{"portability",		0,	0,			'o'},
X	{"compress",		0,	&f_compress,		1},
X	{"compress-block",	0,	&f_compress,		2},
X	{"sparse",		0,	&f_sparse_files,	1},
X	{"tape-length",		1,	0,			'L'},
X
X	{0, 0, 0, 0}
X};
X
X/*
X * Main routine for tar.
X */
Xmain(argc, argv)
X	int	argc;
X	char	**argv;
X{
X	extern char version_string[];
X
X	tar = argv[0];		/* JF: was "tar" Set program name */
X	errors = 0;
X
X	options(argc, argv);
X
X	if(!n_argv)
X		name_init(argc, argv);
X
X	switch(cmd_mode) {
X	case CMD_CAT:
X	case CMD_UPDATE:
X	case CMD_APPEND:
X		update_archive();
X		break;
X	case CMD_DELETE:
X		junk_archive();
X		break;
X	case CMD_CREATE:
X		create_archive();
X		if (f_totals)
X			fprintf (stderr, "Total bytes written: %d\n", tot_written);
X		break;
X	case CMD_EXTRACT:
X		if (f_volhdr) {
X			char *err;
X			label_pattern = (struct re_pattern_buffer *)
X			  ck_malloc (sizeof *label_pattern);
X		 	err = re_compile_pattern (f_volhdr, strlen (f_volhdr),
X						  label_pattern);
X			if (err) {
X				fprintf (stderr,"Bad regular expression: %s\n",
X					 err);
X				errors++;
X				break;
X			}
X		   
X		}		  
X		extr_init();
X		read_and(extract_archive);
X		break;
X	case CMD_LIST:
X		if (f_volhdr) {
X			char *err;
X			label_pattern = (struct re_pattern_buffer *)
X			  ck_malloc (sizeof *label_pattern);
X		 	err = re_compile_pattern (f_volhdr, strlen (f_volhdr),
X						  label_pattern);
X			if (err) {
X				fprintf (stderr,"Bad regular expression: %s\n",
X					 err);
X				errors++;
X				break;
X			}
X		}		  
X		read_and(list_archive);
X#if 0
X		if (!errors)
X			errors = different;
X#endif
X		break;
X	case CMD_DIFF:
X		diff_init();
X		read_and(diff_archive);
X		break;
X	case CMD_VERSION:
X		fprintf(stderr,"%s\n",version_string);
X		break;
X	case CMD_NONE:
X		msg("you must specify exactly one of the r, c, t, x, or d options\n");
X 		fprintf(stderr,"For more information, type ``%s +help''.\n",tar);
X		exit(EX_ARGSBAD);
X	}
X	exit(errors);
X	/* NOTREACHED */
X}
X
X
X/*
X * Parse the options for tar.
X */
Xvoid
Xoptions(argc, argv)
X	int	argc;
X	char	**argv;
X{
X	register int	c;		/* Option letter */
X	int		ind = -1;
X
X	/* Set default option values */
X	blocking = DEFBLOCKING;		/* From Makefile */
X	ar_file = getenv("TAPE");	/* From environment, or */
X	if (ar_file == 0)
X		ar_file = DEF_AR_FILE;	/* From Makefile */
X
X	/* Parse options */
X	while ((c = getoldopt(argc, argv,
X			      "-01234567Ab:BcC:df:F:g:GhikK:lL:mMN:oOpPrRsStT:uvV:wWxX:zZ",
X			      long_options, &ind)) != EOF) {
X		switch (c) {
X		case 0:		/* long options that set a single flag */
X		  	break;
X		case 1:
X			/* File name or non-parsed option */
X			name_add(optarg);
X			break;
X		case 'C':
X			name_add("-C");
X			name_add(optarg);
X			break;
X		case 10:	/* preserve */
X			f_use_protection = f_sorted_names = 1;
X			break;
X		case 11:
X			if(cmd_mode!=CMD_NONE)
X				goto badopt;
X			cmd_mode=CMD_VERSION;
X			break;
X		case 12:	/* help */
X			fprintf(stderr,"This is GNU tar, the tape archiving program.\n");
X			describe();
X			exit(1);
X		case 13:
X			f_new_files++;
X			goto get_newer;
X
X		case 14:			/* Delete in the archive */
X			if(cmd_mode!=CMD_NONE)
X				goto badopt;
X			cmd_mode=CMD_DELETE;
X			break;
X
X		case 15:
X			f_exclude++;
X			add_exclude(optarg);
X			break;
X
X		case 'g':			/* We are making a GNU dump; save
X						   directories at the beginning of
X						   the archive, and include in each
X						   directory its contents */
X			if(f_oldarch)
X				goto badopt;
X			f_gnudump++;
X			gnu_dumpfile=optarg;
X			break;
X
X
X		case '0':
X		case '1':
X		case '2':
X		case '3':
X		case '4':
X		case '5':
X		case '6':
X		case '7':
X			{
X				/* JF this'll have to be modified for other
X				   systems, of course! */
X				int d,add;
X				static char buf[50];
X
X				d=getoldopt(argc,argv,"lmh");
X#ifdef MAYBEDEF
X				sprintf(buf,"/dev/rmt/%d%c",c,d);
X#else
X#ifndef LOW_NUM
X#define LOW_NUM 0
X#define MID_NUM 8
X#define HGH_NUM 16
X#endif
X				if(d=='l') add=LOW_NUM;
X				else if(d=='m') add=MID_NUM;
X				else if(d=='h') add=HGH_NUM;
X				else goto badopt;
X
X				sprintf(buf,"/dev/rmt%d",add+c-'0');
X#endif
X				ar_file=buf;
X			}
X			break;
X
X		case 'A':			/* Arguments are tar files,
X						   just cat them onto the end
X						   of the archive.  */
X			if(cmd_mode!=CMD_NONE)
X				goto badopt;
X			cmd_mode=CMD_CAT;
X			break;
X
X		case 'b':			/* Set blocking factor */
X			blocking = intconv(optarg);
X			break;
X
X		case 'B':			/* Try to reblock input */
X			f_reblock++;		/* For reading 4.2BSD pipes */
X			break;
X
X		case 'c':			/* Create an archive */
X			if(cmd_mode!=CMD_NONE)
X				goto badopt;
X			cmd_mode=CMD_CREATE;
X			break;
X
X/*		case 'C':
X			if(chdir(optarg)<0)
X				msg_perror("Can't change directory to %d",optarg);
X			break; */
X
X		case 'd':			/* Find difference tape/disk */
X			if(cmd_mode!=CMD_NONE)
X				goto badopt;
X			cmd_mode=CMD_DIFF;
X			break;
X
X		case 'f':			/* Use ar_file for the archive */
X			ar_file = optarg;
X			break;
X
X		case 'F':
X			/* Since -F is only useful with -M , make it implied */
X			f_run_script_at_end++;  /* run this script at the end */
X			info_script = optarg;	/* of each tape */
X			f_multivol++;
X			break;
X
X		case 'G':			/* We are making a GNU dump; save
X						   directories at the beginning of
X						   the archive, and include in each
X						   directory its contents */
X			if(f_oldarch)
X				goto badopt;
X			f_gnudump++;
X			gnu_dumpfile=0;
X			break;
X
X		case 'h':
X			f_follow_links++;	/* follow symbolic links */
X			break;
X
X		case 'i':
X			f_ignorez++;		/* Ignore zero records (eofs) */
X			/*
X			 * This can't be the default, because Unix tar
X			 * writes two records of zeros, then pads out the
X			 * block with garbage.
X			 */
X			break;
X
X		case 'k':			/* Don't overwrite files */
X#ifdef NO_OPEN3
X			msg("can't do -k option on this system");
X			exit(EX_ARGSBAD);
X#else
X			f_keep++;
X#endif
X			break;
X
X		case 'K':
X			f_startfile++;
X			addname(optarg);
X			break;
X
X		case 'l':			/* When dumping directories, don't
X						   dump files/subdirectories that are
X						   on other filesystems. */
X			f_local_filesys++;
X			break;
X
X		case 'L':
X			tape_length = intconv (optarg);
X			f_multivol++;
X			break;
X		case 'm':
X			f_modified++;
X			break;
X
X		case 'M':			/* Make Multivolume archive:
X						   When we can't write any more
X						   into the archive, re-open it,
X						   and continue writing */
X			f_multivol++;
X			break;
X
X		case 'N':			/* Only write files newer than X */
X		get_newer:
X			f_new_files++;
X			new_time=get_date(optarg,(struct timeb *)0);
X			break;
X
X		case 'o':			/* Generate old archive */
X			if(f_gnudump /* || f_dironly */)
X				goto badopt;
X			f_oldarch++;
X			break;
X
X		case 'O':
X			f_exstdout++;
X			break;
X
X		case 'p':
X			f_use_protection++;
X			break;
X
X		case 'P':
X			f_absolute_paths++;
X			break;
X
X		case 'r':			/* Append files to the archive */
X			if(cmd_mode!=CMD_NONE)
X				goto badopt;
X			cmd_mode=CMD_APPEND;
X			break;
X
X		case 'R':
X			f_sayblock++;		/* Print block #s for debug */
X			break;			/* of bad tar archives */
X
X		case 's':
X			f_sorted_names++;	/* Names to extr are sorted */
X			break;
X
X		case 'S':			/* deal with sparse files */
X			f_sparse_files++;
X			break;
X		case 't':
X			if(cmd_mode!=CMD_NONE)
X				goto badopt;
X			cmd_mode=CMD_LIST;
X			f_verbose++;		/* "t" output == "cv" or "xv" */
X			break;
X
X		case 'T':
X			name_file = optarg;
X			f_namefile++;
X			break;
X
X		case 'u':			/* Append files to the archive that
X						   aren't there, or are newer than the
X						   copy in the archive */
X			if(cmd_mode!=CMD_NONE)
X				goto badopt;
X			cmd_mode=CMD_UPDATE;
X			break;
X
X		case 'v':
X			f_verbose++;
X			break;
X
X		case 'V':
X			f_volhdr=optarg;
X			break;
X
X		case 'w':
X			f_confirm++;
X			break;
X
X		case 'W':
X			f_verify++;
X			break;
X
X		case 'x':			/* Extract files from the archive */
X			if(cmd_mode!=CMD_NONE)
X				goto badopt;
X			cmd_mode=CMD_EXTRACT;
X			break;
X
X		case 'X':
X			f_exclude++;
X			add_exclude_file(optarg);
X			break;
X
X		case 'z':		/* Easy to type */
X		case 'Z':		/* Like the filename extension .Z */
X			f_compress++;
X			break;
X
X		case '?':
X		badopt:
X			msg("Unknown option.  Use '%s +help' for a complete list of options.", tar);
X			exit(EX_ARGSBAD);
X
X		}
X	}
X
X	blocksize = blocking * RECORDSIZE;
X}
X
X
X/*
X * Print as much help as the user's gonna get.
X *
X * We have to sprinkle in the KLUDGE lines because too many compilers
X * cannot handle character strings longer than about 512 bytes.  Yuk!
X * In particular, MSDOS and Xenix MSC and PDP-11 V7 Unix have this
X * problem.
X */
Xvoid
Xdescribe()
X{
X	msg("choose one of the following:");
X	fputs("\
X-A, +catenate,\n\
X    +concatenate	append tar files to an archive\n\
X-c, +create		create a new archive\n\
X-d, +diff,\n\
X    +compare		find differences between archive and file system\n\
X+delete			delete from the archive (not for use on mag tapes!)\n\
X-r, +append		append files to the end of an archive\n\
X-t, +list		list the contents of an archive\n\
X-u, +update		only append files that are newer than copy in archive\n\
X-x, +extract,\n\
X    +get		extract files from an archive\n",stderr);
X
X	fprintf(stderr, "\
XOther options:\n\
X-b, +block-size N	block size of Nx512 bytes (default N=%d)\n", DEFBLOCKING);
X	fputs ("\
X-B, +read-full-blocks	reblock as we read (for reading 4.2BSD pipes)\n\
X-C, +directory DIR	change to directory DIR\n\
X", stderr); /* KLUDGE */ fprintf(stderr, "\
X-f, +file [HOSTNAME:]F	use archive file or device F (default %s)\n",
X				 DEF_AR_FILE); fputs("\
X-F, +info-script F	run script at end of each tape (implies -M)\n\
X-G, +incremental	create/list/extract old GNU-format incremental backup\n\
X-g, +listed-incremental F create/list/extract new GNU-format incremental backup\n\
X-h, +dereference	don't dump symlinks; dump the files they point to\n\
X-i, +ignore-zeros	ignore blocks of zeros in archive (normally mean EOF)\n\
X-k, +keep-old-files	keep existing files; don't overwrite them from archive\n\
X-K, +starting-file FILE	begin at FILE in the archive\n\
X-l, +one-file-system	stay in local file system when creating an archive\n\
X-L, +tape-length LENGTH change tapes after writing LENGTH\n\
X", stderr); /* KLUDGE */ fputs("\
X-m, +modification-time	don't extract file modified time\n\
X-M, +multi-volume	create/list/extract multi-volume archive\n\
X-N, +after-date DATE,\n\
X    +newer DATE		only store files newer than DATE\n\
X-o, +old-archive,\n\
X    +portability	write a V7 format archive, rather than ANSI format\n\
X-O, +to-stdout		extract files to standard output\n\
X-p, +same-permissions,\n\
X    +preserve-permissions extract all protection information\n\
X-P, +absolute-paths	don't strip leading `/'s from file names\n\
X+preserve		like -p -s\n\
X", stderr); /* KLUDGE */ fputs("\
X-R, +record-number	show record number within archive with each message\n\
X-s, +same-order,\n\
X    +preserve-order	list of names to extract is sorted to match archive\n\
X+same-order		create extracted files with the same ownership \n\
X-S, +sparse		handle sparse files efficiently\n\
X-T, +files-from F	get names to extract or create from file F\n\
X+totals			print total bytes written with +create\n\
X-v, +verbose		verbosely list files processed\n\
X-V, +label NAME		create archive with volume name NAME\n\
X+version		print tar program version number\n\
X-w, +interactive,\n\
X    +confirmation	ask for confirmation for every action\n\
X", stderr); /* KLUDGE */ fputs("\
X-W, +verify		attempt to verify the archive after writing it\n\
X-X, +exclude FILE	exclude file FILE\n\
X+exclude-from FILE	exclude files listed in FILE\n\
X-z, -Z, +compress,\n\
X    +uncompress      	filter the archive through compress\n\
X-[0-7][lmh]		specify drive and density\n\
X", stderr);
X}
X
Xname_add(name)
Xchar *name;
X{
X	if(n_indalloc==n_indused) {
X		n_indalloc+=10;
X		n_ind=(char **)(n_indused ? ck_realloc(n_ind,n_indalloc*sizeof(char *)) : ck_malloc(n_indalloc*sizeof(char *)));
X	}
X	n_ind[n_indused++]=name;
X}
X		
X/*
X * Set up to gather file names for tar.
X *
X * They can either come from stdin or from argv.
X */
Xname_init(argc, argv)
X	int	argc;
X	char	**argv;
X{
X
X	if (f_namefile) {
X		if (optind < argc) {
X			msg("too many args with -T option");
X			exit(EX_ARGSBAD);
X		}
X		if (!strcmp(name_file, "-")) {
X			namef = stdin;
X		} else {
X			namef = fopen(name_file, "r");
X			if (namef == NULL) {
X				msg_perror("can't open file %s",name_file);
X				exit(EX_BADFILE);
X			}
X		}
X	} else {
X		/* Get file names from argv, after options. */
X		n_argc = argc;
X		n_argv = argv;
X	}
X}
X
X/*
X * Get the next name from argv or the name file.
X *
X * Result is in static storage and can't be relied upon across two calls.
X */
X
X/* C is non-zero if we should deal with -C */
Xchar *
Xname_next(c)
X{
X	static char	*buffer;	/* Holding pattern */
X	static buffer_siz;
X	register char	*p;
X	register char	*q = 0;
X	register char	*q2 = 0;
X	extern char *un_quote_string();
X
X	if(buffer_siz==0) {
X		buffer=ck_malloc(NAMSIZ+2);
X		buffer_siz=NAMSIZ;
X	}
X tryagain:
X	if (namef == NULL) {
X		if(n_indscan<n_indused)
X			p=n_ind[n_indscan++];
X		else if (optind < n_argc)		
X			/* Names come from argv, after options */
X			p=n_argv[optind++];
X		else {
X			if(q)
X				msg("Missing filename after -C");
X			return NULL;
X		}
X
X		/* JF trivial support for -C option.  I don't know if
X		   chdir'ing at this point is dangerous or not.
X		   It seems to work, which is all I ask. */
X		if(c && !q && p[0]=='-' && p[1]=='C' && p[2]=='\0') {
X			q=p;
X			goto tryagain;
X		}
X		if(q) {
X			if(chdir(p)<0)
X				msg_perror("Can't chdir to %s",p);
X			q=0;
X			goto tryagain;
X		}
X		/* End of JF quick -C hack */
X
X		if(f_exclude && check_exclude(p))
X			goto tryagain;
X		return un_quote_string(p);
X	}
X	while(p = fgets(buffer, buffer_siz+1 /*nl*/, namef)) {
X		q = p+strlen(p)-1;		/* Find the newline */
X		if (q <= p)			/* Ignore empty lines */
X			continue;
X		while(q==p+buffer_siz && *q!='\n') {
X			buffer=ck_realloc(buffer,buffer_siz+NAMSIZ+2);
X			p=buffer;
X			q=buffer+buffer_siz;
X			buffer_siz+=NAMSIZ;
X			fgets(q+1,NAMSIZ,namef);
X			q=p+strlen(p)-1;
X		}
X		*q-- = '\0';			/* Zap the newline */
X		while (q > p && *q == '/')	/* Zap trailing /s */
X			*q-- = '\0';
X		if (c && !q2 && p[0] == '-' && p[1] == 'C' && p[2] == '\0') {
X			q2 = p;
X			goto tryagain;
X		}
X		if (q2) {
X			if (chdir (p) < 0)
X				msg_perror ("Can't chdir to %s", p);
X			q2 = 0;
X			goto tryagain;
X		}
X		if(f_exclude && check_exclude(p))
X			goto tryagain;
X		return un_quote_string(p);
X	}
X	return NULL;
X}
X
X
X/*
X * Close the name file, if any.
X */
Xname_close()
X{
X
X	if (namef != NULL && namef != stdin) fclose(namef);
X}
X
X
X/*
X * Gather names in a list for scanning.
X * Could hash them later if we really care.
X *
X * If the names are already sorted to match the archive, we just
X * read them one by one.  name_gather reads the first one, and it
X * is called by name_match as appropriate to read the next ones.
X * At EOF, the last name read is just left in the buffer.
X * This option lets users of small machines extract an arbitrary
X * number of files by doing "tar t" and editing down the list of files.
X */
Xname_gather()
X{
X	register char *p;
X	static struct name *namebuf;	/* One-name buffer */
X	static namelen;
X	static char *chdir_name;
X
X	if (f_sorted_names) {
X		if(!namelen) {
X			namelen=NAMSIZ;
X			namebuf=(struct name *)ck_malloc(sizeof(struct name)+NAMSIZ);
X		}
X		p = name_next(0);
X		if (p) {
X			if(*p=='-' && p[1]=='C' && p[2]=='\0') {
X				chdir_name=name_next(0);
X				p=name_next(0);
X				if(!p) {
X					msg("Missing file name after -C");
X					exit(EX_ARGSBAD);
X				}
X				namebuf->change_dir=chdir_name;
X			}
X			namebuf->length = strlen(p);
X			if (namebuf->length >= namelen) {
X				namebuf=(struct name *)ck_realloc(namebuf,sizeof(struct name)+namebuf->length);
X				namelen=namebuf->length;
X			}
X			strncpy(namebuf->name, p, namebuf->length);
X			namebuf->name[ namebuf->length ] = 0;
X			namebuf->next = (struct name *)NULL;
X			namebuf->found = 0;
X			namelist = namebuf;
X			namelast = namelist;
X		}
X		return;
X	}
X
X	/* Non sorted names -- read them all in */
X	while (p = name_next(0))
X		addname(p);
X}
X
X/*
X * Add a name to the namelist.
X */
Xaddname(name)
X	char	*name;			/* pointer to name */
X{
X	register int	i;		/* Length of string */
X	register struct name	*p;	/* Current struct pointer */
X	static char *chdir_name;
X	char *new_name();
X#define MAXPATHLEN 1024
X
X	if(name[0]=='-' && name[1]=='C' && name[2]=='\0') {
X		chdir_name=name_next(0);
X		name=name_next(0);
X		if(!chdir_name) {
X			msg("Missing file name after -C");
X			exit(EX_ARGSBAD);
X		}
X		if(chdir_name[0]!='/') {
X			char path[MAXPATHLEN];
X#if defined(MSDOS) || defined(USG)
X			int getcwd();
X
X			if(!getcwd(path,MAXPATHLEN))
X				msg("Couldn't get current directory.");
X				exit(EX_SYSTEM);
X#else
X			char *getwd();
X
X			if(!getwd(path)) {
X				msg("Couldn't get current directory: %s",path);
X				exit(EX_SYSTEM);
X			}
X#endif
X			chdir_name=new_name(path,chdir_name);
X		}
X	}
X
X	if (name)
X	  {
X	    i = strlen(name);
X	    /*NOSTRICT*/
X	    p = (struct name *)malloc((unsigned)(sizeof(struct name) + i));
X	  }
X	else
X	  p = (struct name *)malloc ((unsigned)(sizeof (struct name)));
X	if (!p) {
X	  if (name)
X	    msg("cannot allocate mem for name '%s'.",name);
X	  else
X	    msg("cannot allocate mem for chdir record.");
X	  exit(EX_SYSTEM);
X	}
X	p->next = (struct name *)NULL;
X	if (name)
X	  {
X	    p->fake = 0;
X	    p->length = i;
X	    strncpy(p->name, name, i);
X	    p->name[i] = '\0';	/* Null term */
X	  }
X	else
X	  p->fake = 1;
X	p->found = 0;
X	p->regexp = 0;		/* Assume not a regular expression */
X	p->firstch = 1;		/* Assume first char is literal */
X	p->change_dir=chdir_name;
X	p->dir_contents = 0;	/* JF */
X	if (name)
X	  {
X	    if (index(name, '*') || index(name, '[') || index(name, '?')) {
X	      p->regexp = 1;	/* No, it's a regexp */
X	      if (name[0] == '*' || name[0] == '[' || name[0] == '?')
X		p->firstch = 0;		/* Not even 1st char literal */
X	    }
X	  }
X
X	if (namelast) namelast->next = p;
X	namelast = p;
X	if (!namelist) namelist = p;
X}
X/*
X * Match a name from an archive, p, with a name from the namelist.
X */
Xname_match(p)
X	register char *p;
X{
X	register struct name	*nlp;
X	register int		len;
X
Xagain:
X	if (0 == (nlp = namelist))	/* Empty namelist is easy */
X		return 1;
X	if (nlp->fake)
X	  {
X	    if (nlp->change_dir && chdir (nlp->change_dir))
X	      msg_perror ("Can't change to directory %d", nlp->change_dir);
X	    namelist = 0;
X	    return 1;
X	  }
X	len = strlen(p);
X	for (; nlp != 0; nlp = nlp->next) {
X		/* If first chars don't match, quick skip */
X		if (nlp->firstch && nlp->name[0] != p[0])
X			continue;
X
X		/* Regular expressions */
X		if (nlp->regexp) {
X			if (wildmat(p, nlp->name)) {
X				nlp->found = 1;	/* Remember it matched */
X				if(f_startfile) {
X					free((void *)namelist);
X					namelist=0;
X				}
X				if(nlp->change_dir && chdir(nlp->change_dir))
X					msg_perror("Can't change to directory %s",nlp->change_dir);
X				return 1;	/* We got a match */
X			}
X			continue;
X		}
X
X		/* Plain Old Strings */
X		if (nlp->length <= len		/* Archive len >= specified */
X		 && (p[nlp->length] == '\0' || p[nlp->length] == '/')
X						/* Full match on file/dirname */
X		 && strncmp(p, nlp->name, nlp->length) == 0) /* Name compare */
X		{
X			nlp->found = 1;		/* Remember it matched */
X			if(f_startfile) {
X				free((void *)namelist);
X				namelist = 0;
X			}
X			if(nlp->change_dir && chdir(nlp->change_dir))
X				msg_perror("Can't change to directory %s",nlp->change_dir);
X			return 1;		/* We got a match */
X		}
X	}
X
X	/*
X	 * Filename from archive not found in namelist.
X	 * If we have the whole namelist here, just return 0.
X	 * Otherwise, read the next name in and compare it.
X	 * If this was the last name, namelist->found will remain on.
X	 * If not, we loop to compare the newly read name.
X	 */
X	if (f_sorted_names && namelist->found) {
X		name_gather();		/* Read one more */
X		if (!namelist->found) goto again;
X	}
X	return 0;
X}
X
X
X/*
X * Print the names of things in the namelist that were not matched.
X */
Xnames_notfound()
X{
X	register struct name	*nlp,*next;
X	register char		*p;
X
X	for (nlp = namelist; nlp != 0; nlp = next) {
X		next=nlp->next;
X		if (!nlp->found)
X			msg("%s not found in archive",nlp->name);
X
X		/*
X		 * We could free() the list, but the process is about
X		 * to die anyway, so save some CPU time.  Amigas and
X		 * other similarly broken software will need to waste
X		 * the time, though.
X		 */
X#ifndef unix
X		if (!f_sorted_names)
X			free(nlp);
X#endif
X	}
X	namelist = (struct name *)NULL;
X	namelast = (struct name *)NULL;
X
X	if (f_sorted_names) {
X		while (0 != (p = name_next(1)))
X			msg("%s not found in archive", p);
X	}
X}
X
X/* These next routines were created by JF */
X
Xname_expand()
X{
X;
X}
X
X/* This is like name_match(), except that it returns a pointer to the name
X   it matched, and doesn't set ->found  The caller will have to do that
X   if it wants to.  Oh, and if the namelist is empty, it returns 0, unlike
X   name_match(), which returns TRUE */
X
Xstruct name *
Xname_scan(p)
Xregister char *p;
X{
X	register struct name	*nlp;
X	register int		len;
X
Xagain:
X	if (0 == (nlp = namelist))	/* Empty namelist is easy */
X		return 0;
X	len = strlen(p);
X	for (; nlp != 0; nlp = nlp->next) {
X		/* If first chars don't match, quick skip */
X		if (nlp->firstch && nlp->name[0] != p[0])
X			continue;
X
X		/* Regular expressions */
X		if (nlp->regexp) {
X			if (wildmat(p, nlp->name))
X				return nlp;	/* We got a match */
X			continue;
X		}
X
X		/* Plain Old Strings */
X		if (nlp->length <= len		/* Archive len >= specified */
X		 && (p[nlp->length] == '\0' || p[nlp->length] == '/')
X						/* Full match on file/dirname */
X		 && strncmp(p, nlp->name, nlp->length) == 0) /* Name compare */
X			return nlp;		/* We got a match */
X	}
X
X	/*
X	 * Filename from archive not found in namelist.
X	 * If we have the whole namelist here, just return 0.
X	 * Otherwise, read the next name in and compare it.
X	 * If this was the last name, namelist->found will remain on.
X	 * If not, we loop to compare the newly read name.
X	 */
X	if (f_sorted_names && namelist->found) {
X		name_gather();		/* Read one more */
X		if (!namelist->found) goto again;
X	}
X	return (struct name *) 0;
X}
X
X/* This returns a name from the namelist which doesn't have ->found set.
X   It sets ->found before returning, so successive calls will find and return
X   all the non-found names in the namelist */
X
Xstruct name *gnu_list_name;
X
Xchar *
Xname_from_list()
X{
X	if(!gnu_list_name)
X		gnu_list_name = namelist;
X	while(gnu_list_name && gnu_list_name->found)
X		gnu_list_name=gnu_list_name->next;
X	if(gnu_list_name) {
X		gnu_list_name->found++;
X		if(gnu_list_name->change_dir)
X			if(chdir(gnu_list_name->change_dir)<0)
X				msg_perror("can't chdir to %s",gnu_list_name->change_dir);
X		return gnu_list_name->name;
X	}
X	return (char *)0;
X}
X
Xblank_name_list()
X{
X	struct name *n;
X
X	gnu_list_name = 0;
X	for(n=namelist;n;n=n->next)
X		n->found = 0;
X}
X
Xchar *
Xnew_name(path,name)
Xchar *path,*name;
X{
X	char *path_buf;
X
X	path_buf=(char *)malloc(strlen(path)+strlen(name)+2);
X	if(path_buf==0) {
X		msg("Can't allocate memory for name '%s/%s",path,name);
X		exit(EX_SYSTEM);
X	}
X	(void) sprintf(path_buf,"%s/%s",path,name);
X	return path_buf;
X}
X
X/* returns non-zero if the luser typed 'y' or 'Y', zero otherwise. */
X
Xint
Xconfirm(action,file)
Xchar *action, *file;
X{
X	int	c,nl;
X	static FILE *confirm_file = 0;
X	extern FILE *msg_file;
X	extern char TTY_NAME[];
X
X	fprintf(msg_file,"%s %s?", action, file);
X	fflush(msg_file);
X	if(!confirm_file) {
X		confirm_file = (archive == 0) ? fopen(TTY_NAME, "r") : stdin;
X		if(!confirm_file) {
X			msg("Can't read confirmation from user");
X			exit(EX_SYSTEM);
X		}
X	}
X	c=getc(confirm_file);
X	for(nl = c; nl != '\n' && nl != EOF; nl = getc(confirm_file))
X		;
X	return (c=='y' || c=='Y');
X}
X
Xchar *x_buffer = 0;
Xint size_x_buffer;
Xint free_x_buffer;
X
Xchar **exclude = 0;
Xint size_exclude = 0;
Xint free_exclude = 0;
X
Xchar **re_exclude = 0;
Xint size_re_exclude = 0;
Xint free_re_exclude = 0;
X
Xadd_exclude(name)
Xchar *name;
X{
X	char *rname;
X	char **tmp_ptr;
X	int size_buf;
X
X	un_quote_string(name);
X	size_buf = strlen(name);
X
X	if(x_buffer==0) {
X		x_buffer = (char *)ck_malloc(size_buf+1024);
X		free_x_buffer=1024;
X	} else if(free_x_buffer<=size_buf) {
X		char *old_x_buffer;
X		char **tmp_ptr;
X
X		old_x_buffer = x_buffer;
X		x_buffer = (char *)ck_realloc(x_buffer,size_x_buffer+1024);
X		free_x_buffer = 1024;
X		for(tmp_ptr=exclude;tmp_ptr<exclude+size_exclude;tmp_ptr++)
X			*tmp_ptr= x_buffer + ((*tmp_ptr) - old_x_buffer);
X		for(tmp_ptr=re_exclude;tmp_ptr<re_exclude+size_re_exclude;tmp_ptr++)
X			*tmp_ptr= x_buffer + ((*tmp_ptr) - old_x_buffer);
X	}
X
X	if(is_regex(name)) {
X		if(free_re_exclude==0) {
X			re_exclude= (char **)(re_exclude ? ck_realloc(re_exclude,(size_re_exclude+32)*sizeof(char *)) : ck_malloc(sizeof(char *)*32));
X			free_re_exclude+=32;
X		}
X		re_exclude[size_re_exclude]=x_buffer+size_x_buffer;
X		size_re_exclude++;
X		free_re_exclude--;
X	} else {
X		if(free_exclude==0) {
X			exclude=(char **)(exclude ? ck_realloc(exclude,(size_exclude+32)*sizeof(char *)) : ck_malloc(sizeof(char *)*32));
X			free_exclude+=32;
X		}
X		exclude[size_exclude]=x_buffer+size_x_buffer;
X		size_exclude++;
X		free_exclude--;
X	}
X	strcpy(x_buffer+size_x_buffer,name);
X	size_x_buffer+=size_buf+1;
X	free_x_buffer-=size_buf+1;
X}
X
Xadd_exclude_file(file)
Xchar *file;
X{
X	FILE *fp;
X	char buf[1024];
X	extern char *rindex();
X
X	if(strcmp(file, "-"))
X		fp=fopen(file,"r");
X	else
X		/* Let's hope the person knows what they're doing. */
X		/* Using -X - -T - -f - will get you *REALLY* strange
X		   results. . . */
X		fp=stdin;
X
X	if(!fp) {
X		msg_perror("can't open %s",file);
X		exit(2);
X	}
X	while(fgets(buf,1024,fp)) {
X		int size_buf;
X		char *end_str;
X
X		end_str=rindex(buf,'\n');
X		if(end_str)
X			*end_str='\0';
X		add_exclude(buf);
X
X	}
X	fclose(fp);
X}
X
Xint
Xis_regex(str)
Xchar *str;
X{
X	return index(str,'*') || index(str,'[') || index(str,'?');
X}
X
X/* Returns non-zero if the file 'name' should not be added/extracted */
Xint
Xcheck_exclude(name)
Xchar *name;
X{
X	int n;
X	char *str;
X	extern char *strstr();
X
X	for(n=0;n<size_re_exclude;n++) {
X		if(wildmat(name,re_exclude[n]))
X			return 1;
X	}
X	for(n=0;n<size_exclude;n++) {
X		/* Accept the output from strstr only if it is the last
X		   part of the string.  There is certainly a faster way to
X		   do this. . . */
X		if(   (str=strstr(name,exclude[n]))
X 		   && (str==name || str[-1]=='/')
X		   && str[strlen(exclude[n])]=='\0')
X			return 1;
X	}
X	return 0;
X}
END_OF_FILE
if test 31481 -ne `wc -c <'tar.c'`; then
    echo shar: \"'tar.c'\" unpacked with wrong size!
fi
# end of 'tar.c'
fi
if test -f 'create.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'create.c'\"
else
echo shar: Extracting \"'create.c'\" \(30999 characters\)
sed "s/^X//" >'create.c' <<'END_OF_FILE'
X/* Create a tar archive.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/*
X * Create a tar archive.
X *
X * Written 25 Aug 1985 by John Gilmore, ihnp4!hoptoad!gnu.
X *
X * @(#)create.c 1.36 11/6/87 - gnu
X */
X#include <sys/types.h>
X#include <sys/stat.h>
X#include <stdio.h>
X
X#ifndef V7
X#include <fcntl.h>
X#endif
X
X#ifndef	__MSDOS__
X#include <sys/file.h>
X#include <sys/param.h>		/* for MAXPATHLEN */
X#include <pwd.h>
X#include <grp.h>
X#endif
X
X#ifdef BSD42
X#include <sys/dir.h>
X#else
X#ifdef __MSDOS__
X#include "msd_dir.h"
X#else
X#ifdef USG
X#ifdef NDIR
X#include <ndir.h>
X#else
X#include <dirent.h>
X#endif
X#ifndef DIRECT
X#define direct dirent
X#endif
X#define DP_NAMELEN(x) strlen((x)->d_name)
X#else
X/*
X * FIXME: On other systems there is no standard place for the header file
X * for the portable directory access routines.  Change the #include line
X * below to bring it in from wherever it is.
X */
X#include "ndir.h"
X#endif
X#endif
X#endif
X
X#ifndef DP_NAMELEN
X#define DP_NAMELEN(x)	(x)->d_namlen
X#endif
X
X#ifdef USG
X#include <sys/sysmacros.h>	/* major() and minor() defined here */
X#endif
X
X/*
X * V7 doesn't have a #define for this.
X */
X#ifndef O_RDONLY
X#define	O_RDONLY	0
X#endif
X
X/*
X * Most people don't have a #define for this.
X */
X#ifndef	O_BINARY
X#define	O_BINARY	0
X#endif
X
X#ifndef MAXPATHLEN
X#define MAXPATHLEN 1024
X#endif
X
X#include "tar.h"
X#include "port.h"
X
Xextern struct stat hstat;		/* Stat struct corresponding */
X
X#ifndef __MSDOS__
Xextern dev_t ar_dev;
Xextern ino_t ar_ino;
X#endif
X
X/* JF */
Xextern struct name *gnu_list_name;
X
X/*
X * If there are no symbolic links, there is no lstat().  Use stat().
X */
X#ifndef S_IFLNK
X#define lstat stat
X#endif
X
Xextern char	*malloc();
Xextern char	*strcpy();
Xextern char	*strncpy();
Xextern void	bzero();
Xextern void	bcopy();
Xextern int	errno;
X
Xextern void print_header();
X
Xunion record *start_header();
Xvoid finish_header();
Xvoid finduname();
Xvoid findgname();
Xchar *name_next();
Xvoid to_oct();
Xvoid dump_file();
X
X
X/* This code moved from tar.h since create.c is the only file that cares
X   about 'struct link's.  This means that other files might not have to
X   include sys/types.h any more.
X */
X
Xstruct link {
X	struct link	*next;
X	dev_t		dev;
X	ino_t		ino;
X	short		linkcount;
X	char		name[1];
X};
X
Xstruct link	*linklist;	/* Points to first link in list */
X
Xstatic nolinks;			/* Gets set if we run out of RAM */
X
X/*
X * "Scratch" space to store the information about a sparse file before
X * writing the info into the header or extended header
X */
X/* struct sp_array	 *sparsearray;*/
X
X/* number of elts storable in the sparsearray */
X/*int 	sparse_array_size = 10;*/
X
Xvoid
Xcreate_archive()
X{
X	register char	*p;
X	char *name_from_list();
X
X	open_archive(0);		/* Open for writing */
X
X	if(f_gnudump) {
X		char buf[MAXNAMLEN],*q,*bufp;
X
X		collect_and_sort_names();
X
X		while(p=name_from_list())
X			dump_file(p,-1);
X		/* if(!f_dironly) { */
X			blank_name_list();
X			while(p=name_from_list()) {
X				strcpy(buf,p);
X				if(p[strlen(p)-1]!='/')
X					strcat(buf,"/");
X				bufp=buf+strlen(buf);
X				for(q=gnu_list_name->dir_contents;q && *q;q+=strlen(q)+1) {
X					if(*q=='Y') {
X						strcpy(bufp,q+1);
X						dump_file(buf,-1);
X					}
X				}
X			}
X		/* } */
X	
X	} else {
X		p = name_next(1);
X		if(!p)
X			dump_file(".", -1);
X		else {
X			do dump_file(p, -1);
X			while (p = name_next(1));
X		}
X	}
X
X	write_mangled();
X	write_eot();
X	close_archive();
X	if(f_gnudump)
X		write_dir_file();
X	name_close();
X}
X
X/*
X * Dump a single file.  If it's a directory, recurse.
X * Result is 1 for success, 0 for failure.
X * Sets global "hstat" to stat() output for this file.
X */
Xvoid
Xdump_file (p, curdev)
X	char	*p;			/* File name to dump */
X	int	curdev;			/* Device our parent dir was on */
X{
X	union record	*header;
X	char type;
X	extern char *save_name;		/* JF for multi-volume support */
X	extern long save_totsize;
X	extern long save_sizeleft;
X	union record	*exhdr;
X	char save_linkflag;
X	extern time_t new_time;
X	int sparse_ind = 0;
X
X
X	if(f_confirm && !confirm("add",p))
X		return;
X
X	/*
X	 * Use stat if following (rather than dumping) 4.2BSD's
X	 * symbolic links.  Otherwise, use lstat (which, on non-4.2
X	 * systems, is #define'd to stat anyway.
X	 */
X#ifdef AIX
X	if (0 != f_follow_links ?
X	    statx (p, &hstat, STATSIZE, STX_HIDDEN):
X	    statx (p, &hstat, STATSIZE, STX_HIDDEN|STX_LINK))
X#else
X	if (0 != f_follow_links? stat(p, &hstat): lstat(p, &hstat))
X#endif /* AIX */
X	{
Xbadperror:
X		msg_perror("can't add file %s",p);
Xbadfile:
X		errors++;
X		return;
X	}
X
X#ifdef AIX
X	if (S_ISHIDDEN (hstat.st_mode)) {
X		char *new = (char *)allocate (strlen (p) + 2);
X		if (new) {
X			strcpy (new, p);
X			strcat (new, "@");
X			p = new;
X		}
X	}
X#endif /* AIX */
X
X	/* See if we only want new files, and check if this one is too old to
X	   put in the archive. */
X	if(   f_new_files
X	   && !f_gnudump
X 	   && new_time>hstat.st_mtime
X 	   && (hstat.st_mode&S_IFMT)!=S_IFDIR
X 	   && (f_new_files>1 || new_time>hstat.st_ctime)) {
X		if(curdev<0) {
X			msg("%s: is unchanged; not dumped",p);
X		}
X		return;
X	}
X
X#ifndef __MSDOS__
X	/* See if we are trying to dump the archive */
X	if(ar_dev && hstat.st_dev==ar_dev && hstat.st_ino==ar_ino) {
X		msg("%s is the archive; not dumped",p);
X		return;
X	}
X#endif
X	/*
X	 * Check for multiple links.
X	 *
X	 * We maintain a list of all such files that we've written so
X	 * far.  Any time we see another, we check the list and
X	 * avoid dumping the data again if we've done it once already.
X	 */
X	if (hstat.st_nlink > 1) switch (hstat.st_mode & S_IFMT) {
X		register struct link	*lp;
X
X	case S_IFREG:			/* Regular file */
X#ifdef S_IFCTG
X	case S_IFCTG:			/* Contigous file */
X#endif
X#ifdef S_IFCHR
X	case S_IFCHR:			/* Character special file */
X#endif
X
X#ifdef S_IFBLK
X	case S_IFBLK:			/* Block     special file */
X#endif
X
X#ifdef S_IFIFO
X	case S_IFIFO:			/* Fifo      special file */
X#endif
X
X		/* First quick and dirty.  Hashing, etc later FIXME */
X		for (lp = linklist; lp; lp = lp->next) {
X			if (lp->ino == hstat.st_ino &&
X			    lp->dev == hstat.st_dev) {
X				char *link_name = lp->name;
X
X				/* We found a link. */
X				hstat.st_size = 0;
X				header = start_header(p, &hstat);
X				if (header == NULL) goto badfile;
X				while(!f_absolute_paths && *link_name == '/') {
X					static int link_warn = 0;
X
X					if (!link_warn) {
X						msg("Removing leading / from absolute links");
X						link_warn++;
X					}
X					link_name++;
X				}
X  				strncpy(header->header.linkname,
X					link_name,NAMSIZ);
X				if(header->header.linkname[NAMSIZ-1]) {
X					char *mangled;
X					extern char *find_mangled();
X
X					mangled=find_mangled(link_name);
X					msg("%s: link name too long: mangled to %s",link_name,mangled);
X					strncpy(header->header.linkname,mangled,NAMSIZ);
X				}
X				header->header.linkflag = LF_LINK;
X				finish_header(header);
X		/* FIXME: Maybe remove from list after all links found? */
X				return;		/* We dumped it */
X			}
X		}
X
X		/* Not found.  Add it to the list of possible links. */
X		lp = (struct link *)malloc((unsigned)(sizeof(struct link)+strlen(p)));
X		if (!lp) {
X			if (!nolinks) {
X				msg(
X	"no memory for links, they will be dumped as separate files");
X				nolinks++;
X			}
X		}
X		lp->ino = hstat.st_ino;
X		lp->dev = hstat.st_dev;
X		strcpy(lp->name, p);
X		lp->next = linklist;
X		linklist = lp;
X	}
X
X	/*
X	 * This is not a link to a previously dumped file, so dump it.
X	 */
X	switch (hstat.st_mode & S_IFMT) {
X
X	case S_IFREG:			/* Regular file */
X#ifdef S_IFCTG
X	case S_IFCTG:			/* Contiguous file */
X#endif
X	{
X		int	f;		/* File descriptor */
X		long	bufsize, count;
X		long	sizeleft;
X		register union record 	*start;
X		int 	header_moved;
X		char	isextended = 0;
X		int 	upperbound;
X		int	end_nulls = 0;
X		
X		header_moved = 0;
X
X#ifdef BSD42
X		if (f_sparse_files) {
X		/*
X	 	 * JK - This is the test for sparseness: whether the
X		 * "size" of the file matches the number of blocks
X		 * allocated for it.  If there is a smaller number
X		 * of blocks that would be necessary to accommodate
X		 * a file of this size, we have a sparse file, i.e.,
X		 * at least one of those records in the file is just
X		 * a useless hole.
X		 */
X#ifdef hpux	/* Nice of HPUX to gratuitiously change it, huh?  - mib */
X		        if (hstat.st_size - (hstat.st_blocks * 1024) > 1024 ) {
X#else
X			if (hstat.st_size - (hstat.st_blocks * RECORDSIZE) > RECORDSIZE) {
X#endif
X				int	filesize = hstat.st_size;
X				register int i;
X				
X				header = start_header(p, &hstat);
X				if (header == NULL)
X					goto badfile;
X				header->header.linkflag = LF_SPARSE;
X				header_moved++;
X				
X			/*
X			 * Call the routine that figures out the
X			 * layout of the sparse file in question.
X			 * UPPERBOUND is the index of the last
X			 * element of the "sparsearray," i.e.,
X			 * the number of elements it needed to
X			 * describe the file.
X			 */
X				 
X				upperbound = deal_with_sparse(p, header);
X 						
X			/* 
X			 * See if we'll need an extended header
X			 * later
X			 */
X				if (upperbound > SPARSE_IN_HDR-1)
X		 			header->header.isextended++;
X			/*
X			 * We store the "real" file size so
X			 * we can show that in case someone wants
X			 * to list the archive, i.e., tar tvf <file>.
X			 * It might be kind of disconcerting if the
X			 * shrunken file size was the one that showed
X			 * up.
X			 */
X				 to_oct((long) hstat.st_size, 1+12, 
X				 		header->header.realsize);
X					
X			/*
X			 * This will be the new "size" of the
X			 * file, i.e., the size of the file
X			 * minus the records of holes that we're
X			 * skipping over. 
X			 */
X				 
X				find_new_file_size(&filesize, upperbound);
X				hstat.st_size = filesize;
X				to_oct((long) filesize, 1+12,
X 						header->header.size);
X/*				to_oct((long) end_nulls, 1+12, 
X						header->header.ending_blanks);*/
X						
X				for (i = 0; i < SPARSE_IN_HDR; i++) {
X					if (!sparsearray[i].numbytes)
X						break;
X					to_oct(sparsearray[i].offset, 1+12,
X						header->header.sp[i].offset);
X					to_oct(sparsearray[i].numbytes, 1+12,
X						header->header.sp[i].numbytes);
X				}
X					
X			}
X		}
X#else
X		upperbound=SPARSE_IN_HDR-1;
X#endif
X		
X		sizeleft = hstat.st_size;
X		/* Don't bother opening empty, world readable files. */
X		if (sizeleft > 0 || 0444 != (0444 & hstat.st_mode)) {
X			f = open(p, O_RDONLY|O_BINARY);
X			if (f < 0) goto badperror;
X		} else {
X			f = -1;
X		}
X		
X		/* If the file is sparse, we've already taken care of this */
X		if (!header_moved) {
X			header = start_header(p, &hstat);
X			if (header == NULL) {
X				if(f>=0)
X					(void)close(f);
X				goto badfile;
X			}
X		}
X#ifdef S_IFCTG
X		/* Mark contiguous files, if we support them */
X		if (f_standard && (hstat.st_mode & S_IFMT) == S_IFCTG) {
X			header->header.linkflag = LF_CONTIG;
X		}
X#endif
X		isextended = header->header.isextended;
X		save_linkflag = header->header.linkflag;
X		finish_header(header);
X		if (isextended) {
X			int	 sum = 0;
X			register int i;
X/*			register union record *exhdr;*/
X			int	 arraybound = SPARSE_EXT_HDR;
X			/* static */ int index_offset = SPARSE_IN_HDR;
X			
X	extend:		exhdr = findrec();
X			
X			if (exhdr == NULL) goto badfile;
X			bzero(exhdr->charptr, RECORDSIZE);
X			for (i = 0; i < SPARSE_EXT_HDR; i++) {
X				if (i+index_offset > upperbound)
X					break;
X				to_oct((long) sparsearray[i+index_offset].numbytes,
X 					1+12,
X					exhdr->ext_hdr.sp[i].numbytes);
X				to_oct((long) sparsearray[i+index_offset].offset,
X 					1+12,
X					exhdr->ext_hdr.sp[i].offset);
X			}
X			userec(exhdr);
X/*			sum += i;
X			if (sum < upperbound)
X				goto extend;*/
X			if (index_offset+i < upperbound) {
X				index_offset += i;
X				exhdr->ext_hdr.isextended++;
X				goto extend;
X			}
X				
X		}
X		if (save_linkflag == LF_SPARSE) {
X			if (finish_sparse_file(f, &sizeleft, hstat.st_size, p))
X				goto padit;
X		}
X		else
X		  while (sizeleft > 0) {
X			
X			if(f_multivol) {   
X				save_name = p;
X				save_sizeleft = sizeleft;
X				save_totsize = hstat.st_size;
X			}
X			start = findrec();
X
X			bufsize = endofrecs()->charptr - start->charptr;
X				
X			if (sizeleft < bufsize) {
X				/* Last read -- zero out area beyond */
X				bufsize = (int)sizeleft;
X				count = bufsize % RECORDSIZE;
X				if (count) 
X					bzero(start->charptr + sizeleft,
X						(int)(RECORDSIZE - count));
X			}
X			count = read(f, start->charptr, bufsize);
X			if (count < 0) {
X				msg_perror("read error at byte %ld, reading\
X %d bytes, in file %s",  hstat.st_size - sizeleft, bufsize,p);
X				goto padit;
X			}
X			sizeleft -= count;
X
X			/* This is nonportable (the type of userec's arg). */
X			userec(start+(count-1)/RECORDSIZE);
X
X			if (count == bufsize) continue;
X			msg( "file %s shrunk by %d bytes, padding with zeros.", p, sizeleft);
X			goto padit;		/* Short read */
X		}
X
X		if(f_multivol)
X			save_name = 0;
X
X		if (f >= 0)
X			(void)close(f);
X
X		break;
X
X		/*
X		 * File shrunk or gave error, pad out tape to match
X		 * the size we specified in the header.
X		 */
X	padit:
X		while(sizeleft>0) {
X			save_sizeleft=sizeleft;
X			start=findrec();
X			bzero(start->charptr,RECORDSIZE);
X			userec(start);
X			sizeleft-=RECORDSIZE;
X		}
X		if(f_multivol)
X			save_name=0;
X		if(f>=0)
X			(void)close(f);
X		break;
X/*		abort(); */
X	}
X
X#ifdef S_IFLNK
X	case S_IFLNK:			/* Symbolic link */
X	{
X		int size;
X
X		hstat.st_size = 0;		/* Force 0 size on symlink */
X		header = start_header(p, &hstat);
X		if (header == NULL) goto badfile;
X		size = readlink(p, header->header.linkname, NAMSIZ);
X		if (size < 0) goto badperror;
X		if (size == NAMSIZ) {
X			char buf[MAXPATHLEN];
X
X			readlink(p,buf,MAXPATHLEN);
X			/* next_mangle(header->header.linkname); */
X			add_symlink_mangle(buf,p,header->header.linkname);
X			msg("symbolic link %s too long: mangling to %s",p, header->header.linkname);
X			/* size=strlen(header->header.linkname); */
X		} else
X			header->header.linkname[size] = '\0';
X		header->header.linkflag = LF_SYMLINK;
X		finish_header(header);		/* Nothing more to do to it */
X	}
X		break;
X#endif
X
X	case S_IFDIR:			/* Directory */
X	{
X		register DIR *dirp;
X		register struct direct *d;
X		char *namebuf;
X		int buflen;
X		register int len;
X		int our_device = hstat.st_dev;
X		extern char *ck_malloc(),*ck_realloc();
X
X		/* Build new prototype name */
X		len = strlen(p);
X		buflen=len+NAMSIZ;
X		namebuf=ck_malloc(buflen+1);
X		strncpy(namebuf, p, buflen);
X		while (len >= 1 && '/' == namebuf[len-1]) 
X			len--;			/* Delete trailing slashes */
X		namebuf[len++] = '/';		/* Now add exactly one back */
X		namebuf[len] = '\0';		/* Make sure null-terminated */
X
X		/*
X		 * Output directory header record with permissions
X		 * FIXME, do this AFTER files, to avoid R/O dir problems?
X		 * If old archive format, don't write record at all.
X		 */
X		if (!f_oldarch) {
X			hstat.st_size = 0;	/* Force 0 size on dir */
X			/*
X			 * If people could really read standard archives,
X			 * this should be:		(FIXME)
X			header = start_header(f_standard? p: namebuf, &hstat);
X			 * but since they'd interpret LF_DIR records as
X			 * regular files, we'd better put the / on the name.
X			 */
X			header = start_header(namebuf, &hstat);
X			if (header == NULL)
X				goto badfile;	/* eg name too long */
X
X			if (f_gnudump)
X				header->header.linkflag = LF_DUMPDIR;
X			else if (f_standard)
X				header->header.linkflag = LF_DIR;
X
X			/* If we're gnudumping, we aren't done yet so don't close it. */
X			if(!f_gnudump)
X				finish_header(header);	/* Done with directory header */
X		}
X
X		if(f_gnudump) {
X			int sizeleft;
X			int totsize;
X			int bufsize;
X			union record *start;
X			int count;
X			char *buf,*p_buf;
X
X			buf=gnu_list_name->dir_contents; /* FOO */
X			totsize=0;
X			for(p_buf=buf;p_buf && *p_buf;) {
X				int tmp;
X
X				tmp=strlen(p_buf)+1;
X				totsize+=tmp;
X				p_buf+=tmp;
X			}
X			totsize++;
X			to_oct((long)totsize,1+12,header->header.size);
X			finish_header(header);
X			p_buf=buf;
X			sizeleft=totsize;
X			while(sizeleft>0) {
X				if(f_multivol) {
X					save_name=p;
X					save_sizeleft=sizeleft;
X					save_totsize=totsize;
X				}
X				start=findrec();
X				bufsize=endofrecs()->charptr - start->charptr;
X				if(sizeleft<bufsize) {
X					bufsize=sizeleft;
X					count=bufsize%RECORDSIZE;
X					if(count)
X						bzero(start->charptr+sizeleft,RECORDSIZE-count);
X				}
X				bcopy(p_buf,start->charptr,bufsize);
X				sizeleft-=bufsize;
X				p_buf+=bufsize;
X				userec(start+(bufsize-1)/RECORDSIZE);
X			}
X			if(f_multivol)
X				save_name = 0;
X 			break;
X		}
X
X		/* Now output all the files in the directory */
X		/* if (f_dironly)
X			break;		/* Unless the cmdline said not to */
X		/*
X		 * See if we are crossing from one file system to another,
X		 * and avoid doing so if the user only wants to dump one file system.
X		 */
X		if (f_local_filesys && curdev >= 0 && curdev != hstat.st_dev) {
X			if(f_verbose)
X				msg("%s: is on a different filesystem; not dumped",p);
X			break;
X		}
X
X
X		errno = 0;
X		dirp = opendir(p);
X		if (!dirp) {
X			if (errno) {
X				msg_perror ("can't open directory %s",p);
X			} else {
X				msg("error opening directory %s",
X					p);
X			}
X			break;
X		}
X
X		/* Hack to remove "./" from the front of all the file names */
X		if (len == 2 && namebuf[0] == '.' && namebuf[1]=='/')
X			len = 0;
X
X		/* Should speed this up by cd-ing into the dir, FIXME */
X		while (NULL != (d=readdir(dirp))) {
X			/* Skip . and .. */
X			if(is_dot_or_dotdot(d->d_name))
X				continue;
X
X			if (DP_NAMELEN(d) + len >= buflen) {
X				buflen=len+DP_NAMELEN(d);
X				namebuf=ck_realloc(namebuf,buflen+1);
X				/* namebuf[len]='\0';
X				msg("file name %s%s too long", 
X					namebuf, d->d_name);
X				continue; */
X			}
X			strcpy(namebuf+len, d->d_name);
X			if(f_exclude && check_exclude(namebuf))
X				continue;
X			dump_file(namebuf, our_device);
X		}
X
X		closedir(dirp);
X		free(namebuf);
X	}
X		break;
X
X#ifdef S_IFCHR
X	case S_IFCHR:			/* Character special file */
X		type = LF_CHR;
X		goto easy;
X#endif
X
X#ifdef S_IFBLK
X	case S_IFBLK:			/* Block     special file */
X		type = LF_BLK;
X		goto easy;
X#endif
X
X/* Avoid screwy apollo lossage where S_IFIFO == S_IFSOCK */
X#if ((_ISP__M68K == 0) && (_ISP__A88K == 0))
X#ifdef S_IFIFO
X	case S_IFIFO:			/* Fifo      special file */
X		
X		type = LF_FIFO;
X		goto easy;
X#endif
X#endif
X
X#ifdef S_IFSOCK
X	case S_IFSOCK:			/* Socket	pretend its a fifo? */
X		type = LF_FIFO;
X		goto easy;
X#endif
X
X	easy:
X		if (!f_standard) goto unknown;
X
X		hstat.st_size = 0;		/* Force 0 size */
X		header = start_header(p, &hstat);
X		if (header == NULL) goto badfile;	/* eg name too long */
X
X		header->header.linkflag = type;
X		if (type != LF_FIFO) {
X			to_oct((long) major(hstat.st_rdev), 8,
X				header->header.devmajor);
X			to_oct((long) minor(hstat.st_rdev), 8,
X				header->header.devminor);
X		}
X
X		finish_header(header);
X		break;
X
X	default:
X	unknown:
X		msg("%s: Unknown file type; file ignored.", p);
X		break;
X	}
X}
X
Xint
Xfinish_sparse_file(fd, sizeleft, fullsize, name)
X	int	fd;
X	long 	*sizeleft,
X		fullsize;
X	char	*name;
X{
X	union record	*start;
X	char		tempbuf[RECORDSIZE];
X	int		bufsize,
X			sparse_ind = 0,
X			count;
X	long		pos;
X	long		nwritten = 0;
X
X
X	while (*sizeleft > 0) {
X		start = findrec();
X		bzero(start->charptr, RECORDSIZE);
X		bufsize = sparsearray[sparse_ind].numbytes;
X		if (!bufsize) {  /* we blew it, maybe */
X		        msg("Wrote %ld of %ld bytes to file %s",
X			           fullsize - *sizeleft, fullsize, name);
X			break;
X 	        }
X		pos = lseek(fd, sparsearray[sparse_ind++].offset, 0);
X		/* 
X		 * If the number of bytes to be written here exceeds
X		 * the size of the temporary buffer, do it in steps.
X		 */
X		while (bufsize > RECORDSIZE) {
X/*			if (amt_read) {
X				count = read(fd, start->charptr+amt_read, RECORDSIZE-amt_read);
X				bufsize -= RECORDSIZE - amt_read;
X				amt_read = 0;
X				userec(start);
X				start = findrec();
X				bzero(start->charptr, RECORDSIZE);
X			}*/
X			/* store the data */
X			count = read(fd, start->charptr, RECORDSIZE);
X			if (count < 0) 	{
X				msg_perror("read error at byte %ld, reading %d bytes, in file %s", 
X						fullsize - *sizeleft, bufsize, name);
X				return 1;
X			}			
X			bufsize -= count;
X			*sizeleft -= count;
X			userec(start);
X			nwritten += RECORDSIZE;	/* XXX */
X			start = findrec();
X			bzero(start->charptr, RECORDSIZE);
X		}
X
X
X		clear_buffer(tempbuf);
X		count = read(fd, tempbuf, bufsize);
X		bcopy(tempbuf, start->charptr, RECORDSIZE);
X		if (count < 0) 	{
X			msg_perror("read error at byte %ld, reading %d bytes, in file %s", 
X					fullsize - *sizeleft, bufsize, name);
X			return 1;
X		}
X/*		if (amt_read >= RECORDSIZE) {
X			amt_read = 0;
X			userec(start+(count-1)/RECORDSIZE);
X			if (count != bufsize) {
X				msg("file %s shrunk by %d bytes, padding with zeros.", name, sizeleft);
X				return 1;
X			}
X			start = findrec();
X		} else 
X			amt_read += bufsize;*/
X		nwritten += count; /* XXX */
X		*sizeleft -= count;
X		userec(start);
X
X	}
X	free(sparsearray);
X	printf ("Amount actually written is (I hope) %d.\n", nwritten);
X/*	userec(start+(count-1)/RECORDSIZE);*/
X	return 0;
X
X}
X
Xinit_sparsearray()
X{
X	register int i;
X
X	sp_array_size = 10;
X	/* 
X	 * Make room for our scratch space -- initially is 10 elts long
X	 */
X	sparsearray = (struct sp_array *) malloc(sp_array_size * sizeof(struct sp_array));
X	for (i = 0; i < sp_array_size; i++) {
X		sparsearray[i].offset = 0;
X		sparsearray[i].numbytes = 0;
X	}
X}
X
X
X
X/*
X * Okay, we've got a sparse file on our hands -- now, what we need to do is
X * make a pass through the file and carefully note where any data is, i.e.,
X * we want to find how far into the file each instance of data is, and how
X * many bytes are there.  We store this information in the sparsearray,
X * which will later be translated into header information.  For now, we use
X * the sparsearray as convenient storage.
X *
X * As a side note, this routine is a mess.  If I could have found a cleaner
X * way to do it, I would have.  If anyone wants to find a nicer way to do
X * this, feel free.
X */
X
X/* There is little point in trimming small amounts of null data at the */
X /* head and tail of blocks -- it's ok if we only avoid dumping blocks */
X /* of complete null data */
Xint
Xdeal_with_sparse(name, header, nulls_at_end)
X	char		*name;
X	union record 	*header;
X	
X{
X	long	numbytes = 0;
X	long	offset = 0;
X	long	save_offset;
X	int	fd;
X	int	current_size = hstat.st_size;
X	int	sparse_ind = 0,
X		cc;
X	char	buf[RECORDSIZE];
X	int	read_last_data = 0; /* did we just read the last record? */
X	int 	amidst_data = 0;
X	
X	header->header.isextended = 0;
X	/* 
X	 * Can't open the file -- this problem will be caught later on,
X	 * so just return.
X	 */
X	if ((fd = open(name, O_RDONLY)) < 0)
X		return 0;
X		
X	init_sparsearray();
X	clear_buffer(buf);
X
X	while ((cc = read(fd, buf, sizeof buf)) != 0) {
X			
X		if (sparse_ind > sp_array_size-1) {
X		
X		/*
X		 * realloc the scratch area, since we've run out of room --
X		 */
X			sparsearray = (struct sp_array *) 
X					realloc(sparsearray,
X 						2 * sp_array_size * (sizeof(struct sp_array)));
X			sp_array_size *= 2;
X		}
X		if (cc == sizeof buf) {
X			if (zero_record(buf)) {
X				if (amidst_data) {
X					sparsearray[sparse_ind++].numbytes
X						= numbytes;
X					amidst_data = 0;
X				}
X			} else {  /* !zero_record(buf) */
X			        if (amidst_data)
X				        numbytes += cc;
X				else {
X				        amidst_data = 1;
X					numbytes = cc;
X					sparsearray[sparse_ind].offset
X					  = offset;
X				} 
X			}
X		} else if (cc < sizeof buf) {
X		  /* This has to be the last bit of the file, so this */
X		  /* is somewhat shorter than the above. */
X		        if (!zero_record(buf)) {
X				if (!amidst_data) {
X				        amidst_data = 1;
X					numbytes = cc;
X					sparsearray[sparse_ind].offset
X					  = offset;
X				} else
X					numbytes += cc;
X			} 
X		}
X		offset += cc;
X		clear_buffer(buf);
X	}
X	if (amidst_data)
X	        sparsearray[sparse_ind++].numbytes = numbytes;
X	close(fd);
X
X	return sparse_ind - 1;
X}
X
X/* 
X * Just zeroes out the buffer so we don't confuse ourselves with leftover
X * data.
X */
Xclear_buffer(buf)
X	char	*buf;
X{
X	register int 	i;
X
X	for (i = 0; i < RECORDSIZE; i++)
X		buf[i] = '\0';
X}
X
X#if 0  /* I'm leaving this as a monument to Joy Kendall, who wrote it */
X/* 
X * JK - 
X * This routine takes a character array, and tells where within that array
X * the data can be found.  It skips over any zeros, and sets the first
X * non-zero point in the array to be the "start", and continues until it
X * finds non-data again, which is marked as the "end."  This routine is 
X * mainly for 1) seeing how far into a file we must lseek to data, given
X * that we have a sparse file, and 2) determining the "real size" of the
X * file, i.e., the number of bytes in the sparse file that are data, as
X * opposed to the zeros we are trying to skip.
X */
Xwhere_is_data(from, to, buffer)
X	int	*from,
X		*to;
X	char	*buffer;
X{
X	register int	i = 0;
X	register int	save_to = *to;
X	int	amidst_data = 0;
X
X	
X	while (!buffer[i])
X		i++;
X	*from = i;
X
X	if (*from < 16)	/* don't bother */
X		*from = 0;
X	/* keep going to make sure there isn't more real
X	   data in this record */
X	while (i < RECORDSIZE) {
X		if (!buffer[i]) {
X			if (amidst_data) {
X				save_to = i;
X				amidst_data = 0;
X			}
X			i++;
X		}
X		else if (buffer[i]) {
X			if (!amidst_data)
X				amidst_data = 1;
X			i++;
X		}
X	}
X	if (i == RECORDSIZE)
X		*to = i;
X	else
X		*to = save_to;
X		
X}
X#endif
X
X/* Note that this routine is only called if zero_record returned true */
X#if 0 /* But we actually don't need it at all. */
Xwhere_is_data (from, to, buffer)
X     int *from, *to;
X     char *buffer;
X{
X  char *fp, *tp;
X
X  for (fp = buffer; ! *fp; fp++)
X    ;
X  for (tp = buffer + RECORDSIZE - 1; ! *tp; tp--)
X    ;
X  *from = fp - buffer;
X  *to = tp - buffer + 1;
X}
X#endif
X
X
X
X/*
X * Takes a recordful of data and basically cruises through it to see if
X * it's made *entirely* of zeros, returning a 0 the instant it finds
X * something that is a non-zero, i.e., useful data.
X */
Xzero_record(buffer)
X	char	*buffer;
X{
X	register int	i;
X
X	for (i = 0; i < RECORDSIZE; i++)
X		if (buffer[i] != '\000')
X			return 0;
X	return 1;
X}
X
Xfind_new_file_size(filesize, highest_index)
X	int	*filesize;
X	int	highest_index;
X{
X	register int 	i;
X
X	*filesize = 0;
X	for (i = 0; sparsearray[i].numbytes && i <= highest_index; i++)
X		*filesize += sparsearray[i].numbytes;
X}
X	
X/*
X * Make a header block for the file  name  whose stat info is  st .
X * Return header pointer for success, NULL if the name is too long.
X */
Xunion record *
Xstart_header(name, st)
X	char	*name;
X	register struct stat *st;
X{
X	register union record *header;
X
X	header = (union record *) findrec();
X	bzero(header->charptr, sizeof(*header)); /* XXX speed up */
X
X	/*
X	 * Check the file name and put it in the record.
X	 */
X	if(!f_absolute_paths) {
X		static int warned_once = 0;
X#ifdef __MSDOS__
X		if(name[1]==':') {
X			name+=2;
X			if(!warned_once++)
X				msg("Removing drive spec from names in the archive");
X		}
X#endif
X		while ('/' == *name) {
X			name++;				/* Force relative path */
X			if (!warned_once++)
X				msg("Removing leading / from absolute path names in the archive.");
X		}
X	}
X	strncpy(header->header.name, name, NAMSIZ);
X	if (header->header.name[NAMSIZ-1]) {
X		char *mangled;
X
X		/* next_mangle(header->header.name); */
X		add_mangle(name,header->header.name);
X		msg("%s: is too long: mangling to %s", name, header->header.name);
X	}
X
X	to_oct((long) (st->st_mode & ~S_IFMT),
X					8,  header->header.mode);
X	to_oct((long) st->st_uid,	8,  header->header.uid);
X	to_oct((long) st->st_gid,	8,  header->header.gid);
X	to_oct((long) st->st_size,	1+12, header->header.size);
X	to_oct((long) st->st_mtime,	1+12, header->header.mtime);
X	/* header->header.linkflag is left as null */
X	if(f_gnudump) {
X		to_oct((long) st->st_atime, 1+12, header->header.atime);
X		to_oct((long) st->st_ctime, 1+12, header->header.ctime);
X	}
X
X#ifndef NONAMES
X	/* Fill in new Unix Standard fields if desired. */
X	if (f_standard) {
X		header->header.linkflag = LF_NORMAL;	/* New default */
X		strcpy(header->header.magic, TMAGIC);	/* Mark as Unix Std */
X		finduname(header->header.uname, st->st_uid);
X		findgname(header->header.gname, st->st_gid);
X	}
X#endif
X	return header;
X}
X
X/* 
X * Finish off a filled-in header block and write it out.
X * We also print the file name and/or full info if verbose is on.
X */
Xvoid
Xfinish_header(header)
X	register union record *header;
X{
X	register int	i, sum;
X	register char	*p;
X	void bcopy();
X
X	bcopy(CHKBLANKS, header->header.chksum, sizeof(header->header.chksum));
X
X	sum = 0;
X	p = header->charptr;
X	for (i = sizeof(*header); --i >= 0; ) {
X		/*
X		 * We can't use unsigned char here because of old compilers,
X		 * e.g. V7.
X		 */
X		sum += 0xFF & *p++;
X	}
X
X	/*
X	 * Fill in the checksum field.  It's formatted differently
X	 * from the other fields:  it has [6] digits, a null, then a
X	 * space -- rather than digits, a space, then a null.
X	 * We use to_oct then write the null in over to_oct's space.
X	 * The final space is already there, from checksumming, and
X	 * to_oct doesn't modify it.
X	 *
X	 * This is a fast way to do:
X	 * (void) sprintf(header->header.chksum, "%6o", sum);
X	 */
X	to_oct((long) sum,	8,  header->header.chksum);
X	header->header.chksum[6] = '\0';	/* Zap the space */
X
X	userec(header);
X
X	if (f_verbose) {
X		extern union record *head;		/* Points to current tape header */
X		extern int head_standard;		/* Tape header is in ANSI format */
X
X		/* These globals are parameters to print_header, sigh */
X		head = header;
X		/* hstat is already set up */
X		head_standard = f_standard;
X		print_header();
X	}
X
X	return;
X}
X
X
X/*
X * Quick and dirty octal conversion.
X * Converts long "value" into a "digs"-digit field at "where",
X * including a trailing space and room for a null.  "digs"==3 means
X * 1 digit, a space, and room for a null.
X *
X * We assume the trailing null is already there and don't fill it in.
X * This fact is used by start_header and finish_header, so don't change it!
X *
X * This should be equivalent to:
X *	(void) sprintf(where, "%*lo ", digs-2, value);
X * except that sprintf fills in the trailing null and we don't.
X */
Xvoid
Xto_oct(value, digs, where)
X	register long	value;
X	register int	digs;
X	register char	*where;
X{
X	
X	--digs;				/* Trailing null slot is left alone */
X	where[--digs] = ' ';		/* Put in the space, though */
X
X	/* Produce the digits -- at least one */
X	do {
X		where[--digs] = '0' + (char)(value & 7); /* one octal digit */
X		value >>= 3;
X	} while (digs > 0 && value != 0);
X
X	/* Leading spaces, if necessary */
X	while (digs > 0)
X		where[--digs] = ' ';
X
X}
X
X
X/*
X * Write the EOT record(s).
X * We actually zero at least one record, through the end of the block.
X * Old tar writes garbage after two zeroed records -- and PDtar used to.
X */
Xwrite_eot()
X{
X	union record *p;
X	int bufsize;
X	void bzero();
X
X	p = findrec();
X	if (p)
X	  {
X	    bufsize = endofrecs()->charptr - p->charptr;
X	    bzero(p->charptr, bufsize);
X	    userec(p);
X	  }
X}
END_OF_FILE
if test 30999 -ne `wc -c <'create.c'`; then
    echo shar: \"'create.c'\" unpacked with wrong size!
fi
# end of 'create.c'
fi
if test -f 'extract.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'extract.c'\"
else
echo shar: Extracting \"'extract.c'\" \(20086 characters\)
sed "s/^X//" >'extract.c' <<'END_OF_FILE'
X/* Extract files from a tar archive.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/*
X * Extract files from a tar archive.
X *
X * Written 19 Nov 1985 by John Gilmore, ihnp4!hoptoad!gnu.
X *
X * @(#) extract.c 1.32 87/11/11 - gnu
X */
X
X#include <stdio.h>
X#include <errno.h>
X#include <sys/types.h>
X#include <sys/stat.h>
X
X#ifdef BSD42
X#include <sys/file.h>
X#endif
X
X#ifdef USG
X#include <fcntl.h>
X#endif
X
X#ifdef	MSDOS
X#include <fcntl.h>
X#endif	/* MSDOS */
X
X/*
X * Some people don't have a #define for these.
X */
X#ifndef	O_BINARY
X#define	O_BINARY	0
X#endif
X#ifndef O_NDELAY
X#define	O_NDELAY	0
X#endif
X
X#ifdef NO_OPEN3
X/* We need the #define's even though we don't use them. */
X#include "open3.h"
X#endif
X
X#ifdef EMUL_OPEN3
X/* Simulated 3-argument open for systems that don't have it */
X#include "open3.h"
X#endif
X
Xextern int errno;			/* From libc.a */
Xextern time_t time();			/* From libc.a */
Xextern char *index();			/* From libc.a or port.c */
X
X#include "tar.h"
X#include "port.h"
X
Xextern FILE *msg_file;
X
Xextern union record *head;		/* Points to current tape header */
Xextern struct stat hstat;		/* Stat struct corresponding */
Xextern int head_standard;		/* Tape header is in ANSI format */
X
Xextern char *save_name;
Xextern long save_totsize;
Xextern long save_sizeleft;
X
Xextern void print_header();
Xextern void skip_file();
Xextern void skip_extended_headers();
Xextern void pr_mkdir();
X
Xint make_dirs();			/* Makes required directories */
X
Xstatic time_t now = 0;			/* Current time */
Xstatic we_are_root = 0;			/* True if our effective uid == 0 */
Xstatic int notumask = ~0;		/* Masks out bits user doesn't want */
X
X/*
X * "Scratch" space to store the information about a sparse file before
X * writing the info into the header or extended header
X */
X/*struct sp_array	*sparsearray;*/
X
X/* number of elts storable in the sparsearray */
X/*int	sp_array_size = 10;*/
X
X/*
X * Set up to extract files.
X */
Xextr_init()
X{
X	int ourmask;
X
X	now = time((time_t *)0);
X	if (geteuid() == 0)
X		we_are_root = 1;
X
X	/*
X	 * We need to know our umask.  But if f_use_protection is set,
X	 * leave our kernel umask at 0, and our "notumask" at ~0.
X	 */
X	ourmask = umask(0);		/* Read it */
X	if (!f_use_protection) {
X		(void) umask (ourmask);	/* Set it back how it was */
X		notumask = ~ourmask;	/* Make umask override permissions */
X	}
X}
X
X
X/*
X * Extract a file from the archive.
X */
Xvoid
Xextract_archive()
X{
X	register char *data;
X	int fd, check, namelen, written, openflag;
X	long size;
X	time_t acc_upd_times[2];
X	register int skipcrud;
X	register int i;
X	int sparse_ind = 0;
X	union record *exhdr;	
X	int end_nulls;
X	
X	saverec(&head);			/* Make sure it sticks around */
X	userec(head);			/* And go past it in the archive */
X	decode_header(head, &hstat, &head_standard, 1);	/* Snarf fields */
X
X	if(f_confirm && !confirm("extract",head->header.name)) {
X		if (head->header.isextended)
X			skip_extended_headers();
X		skip_file((long)hstat.st_size);
X		saverec((union record **)0);
X		return;
X	}
X
X	/* Print the record from 'head' and 'hstat' */
X	if (f_verbose)
X		print_header();
X
X	/*
X	 * Check for fully specified pathnames and other atrocities.
X	 *
X	 * Note, we can't just make a pointer to the new file name,
X	 * since saverec() might move the header and adjust "head".
X	 * We have to start from "head" every time we want to touch
X	 * the header record.
X	 */
X	skipcrud = 0;
X	while (!f_absolute_paths && '/' == head->header.name[skipcrud]) {
X		static int warned_once = 0;
X
X		skipcrud++;	/* Force relative path */
X		if (!warned_once++) {
X			msg("Removing leading / from absolute path names in the archive.");
X		}
X	}
X
X	switch (head->header.linkflag) {
X
X	default:
X		msg("Unknown file type '%c' for %s, extracted as normal file",
X			head->header.linkflag, skipcrud+head->header.name);
X		/* FALL THRU */
X
X	/* 
X	 * JK - What we want to do if the file is sparse is loop through
X	 * the array of sparse structures in the header and read in
X	 * and translate the character strings representing  1) the offset
X	 * at which to write and 2) how many bytes to write into numbers,
X	 * which we store into the scratch array, "sparsearray".  This
X	 * array makes our life easier the same way it did in creating
X	 * the tar file that had to deal with a sparse file.
X	 *
X	 * After we read in the first five (at most) sparse structures,
X	 * we check to see if the file has an extended header, i.e., 
X	 * if more sparse structures are needed to describe the contents
X	 * of the new file.  If so, we read in the extended headers
X	 * and continue to store their contents into the sparsearray.
X	 */
X	case LF_SPARSE:
X		sp_array_size = 10;
X		sparsearray = (struct sp_array *) malloc(sp_array_size * sizeof(struct sp_array));
X		for (i = 0; i < SPARSE_IN_HDR; i++) {
X			sparsearray[i].offset = 
X				from_oct(1+12, head->header.sp[i].offset);
X			sparsearray[i].numbytes = 
X				from_oct(1+12, head->header.sp[i].numbytes);
X			if (!sparsearray[i].numbytes)
X				break;
X		}
X		
X/*		end_nulls = from_oct(1+12, head->header.ending_blanks);*/
X		
X		if (head->header.isextended) {
X			/* read in the list of extended headers
X			   and translate them into the sparsearray 
X			   as before */
X
X			/* static */ int ind = SPARSE_IN_HDR;
X			
X			for (;;) {
X				
X				exhdr = findrec();
X				for (i = 0; i < SPARSE_EXT_HDR; i++) {
X					
X					if (i+ind > sp_array_size-1) {
X					/*
X					 * realloc the scratch area
X					 * since we've run out of room --
X		 			 */
X						sparsearray = (struct sp_array *) 
X								realloc(sparsearray,
X 								2 * sp_array_size * (sizeof(struct sp_array)));
X						sp_array_size *= 2;
X					}
X					if (!exhdr->ext_hdr.sp[i].numbytes)
X						break;
X					sparsearray[i+ind].offset = 
X						from_oct(1+12, exhdr->ext_hdr.sp[i].offset);
X					sparsearray[i+ind].numbytes = 
X						from_oct(1+12, exhdr->ext_hdr.sp[i].numbytes);
X				}
X				if (!exhdr->ext_hdr.isextended) 
X					break;
X				else {
X					ind += SPARSE_EXT_HDR;
X					userec(exhdr);
X				}
X			}
X			userec(exhdr);
X		}
X		
X		/* FALL THRU */
X	case LF_OLDNORMAL:
X	case LF_NORMAL:
X	case LF_CONTIG:
X		/*
X		 * Appears to be a file.
X		 * See if it's really a directory.
X		 */
X		namelen = strlen(skipcrud+head->header.name)-1;
X		if (head->header.name[skipcrud+namelen] == '/')
X			goto really_dir;
X
X		/* FIXME, deal with protection issues */
X	again_file:
X		openflag = (f_keep?
X			O_BINARY|O_NDELAY|O_WRONLY|O_CREAT|O_EXCL:
X			O_BINARY|O_NDELAY|O_WRONLY|O_CREAT|O_TRUNC)
X			| ((head->header.linkflag == LF_SPARSE) ? 0 : O_APPEND);			
X			/*
X			 * JK - The last | is a kludge to solve the problem
X			 * the O_APPEND flag  causes with files we are
X			 * trying to make sparse:  when a file is opened
X			 * with O_APPEND, it writes  to the last place
X			 * that something was written, thereby ignoring
X			 * any lseeks that we have done.  We add this
X			 * extra condition to make it able to lseek when
X			 * a file is sparse, i.e., we don't open the new
X			 * file with this flag.  (Grump -- this bug caused
X			 * me to waste a good deal of time, I might add)
X  			 */
X
X		if(f_exstdout) {
X			fd = 1;
X			goto extract_file;
X		}
X#ifdef O_CTG
X		/*
X		 * Contiguous files (on the Masscomp) have to specify
X		 * the size in the open call that creates them.
X		 */
X		if (head->header.linkflag == LF_CONTIG)
X			fd = open(skipcrud+head->header.name, openflag | O_CTG,
X				hstat.st_mode, hstat.st_size);
X		else
X#endif
X		{
X#ifdef NO_OPEN3
X			/*
X			 * On raw V7 we won't let them specify -k (f_keep), but
X			 * we just bull ahead and create the files.
X			 */
X			fd = creat(skipcrud+head->header.name, 
X				hstat.st_mode);
X#else
X			/*
X			 * With 3-arg open(), we can do this up right.
X			 */
X			fd = open(skipcrud+head->header.name, openflag,
X				hstat.st_mode);
X#endif
X		}
X
X		if (fd < 0) {
X			if (make_dirs(skipcrud+head->header.name))
X				goto again_file;
X			msg_perror("Could not create file %s",skipcrud+head->header.name);
X			if (head->header.isextended)
X				skip_extended_headers();
X			skip_file((long)hstat.st_size);
X			goto quit;
X		}
X
X	extract_file:
X		if (head->header.linkflag == LF_SPARSE) {
X			char	*name;
X			int	namelen;
X
X			/*
X			 * Kludge alert.  NAME is assigned to header.name
X			 * because during the extraction, the space that
X			 * contains the header will get scribbled on, and
X			 * the name will get munged, so any error messages
X			 * that happen to contain the filename will look
X			 * REAL interesting unless we do this.
X			 */
X			namelen = strlen(skipcrud+head->header.name);
X			name = (char *) malloc((sizeof(char)) * namelen);
X			bcopy(skipcrud+head->header.name, name, namelen);
X			size = hstat.st_size;
X			extract_sparse_file(fd, &size, hstat.st_size,
X 						name);
X		}			
X		else 		
X		  for (size = hstat.st_size;
X		       size > 0;
X		       size -= written) {
X
X			long	offset,
X 				numbytes;
X
X			if(f_multivol) {
X				save_name=head->header.name;
X				save_totsize=hstat.st_size;
X				save_sizeleft=size;
X			}
X			
X			/*
X			 * Locate data, determine max length
X			 * writeable, write it, record that
X			 * we have used the data, then check
X			 * if the write worked.
X			 */
X			data = findrec()->charptr;
X			if (data == NULL) {	/* Check it... */
X				msg("Unexpected EOF on archive file");
X				break;
X			}
X			/*
X			 * JK - If the file is sparse, use the sparsearray
X			 * that we created before to lseek into the new
X			 * file the proper amount, and to see how many
X			 * bytes we want to write at that position.
X			 */
X/*			if (head->header.linkflag == LF_SPARSE) {
X				off_t pos;
X				
X				pos = lseek(fd, (off_t) sparsearray[sparse_ind].offset, 0);
X				printf("%d at %d\n", (int) pos, sparse_ind);
X				written = sparsearray[sparse_ind++].numbytes;
X			} else*/
X			written = endofrecs()->charptr - data;
X			if (written > size)
X				written = size;
X			errno = 0;
X			check = write(fd, data, written);
X			/*
X			 * The following is in violation of strict
X			 * typing, since the arg to userec
X			 * should be a struct rec *.  FIXME.
X			 */
X			userec((union record *)(data + written - 1));
X			if (check == written) continue;
X			/*
X			 * Error in writing to file.
X			 * Print it, skip to next file in archive.
X			 */
X			if(check<0)
X				msg_perror("couldn't write to file %s",skipcrud+head->header.name);
X			else
X				msg("could only write %d of %d bytes to file %s",written,check,skipcrud+head->header.name);
X			skip_file((long)(size - written));
X			break;	/* Still do the close, mod time, chmod, etc */
X		}
X
X		if(f_multivol)
X			save_name = 0;
X
X			/* If writing to stdout, don't try to do anything
X			   to the filename; it doesn't exist, or we don't
X			   want to touch it anyway */
X		if(f_exstdout)
X			break;
X			
X/*		if (head->header.isextended) {
X			register union record *exhdr;
X			register int i;
X			
X			for (i = 0; i < 21; i++) {
X				long offset;
X				
X				if (!exhdr->ext_hdr.sp[i].numbytes)
X					break;
X				offset = from_oct(1+12,
X 						exhdr->ext_hdr.sp[i].offset);
X				written = from_oct(1+12,
X 						exhdr->ext_hdr.sp[i].numbytes);
X				lseek(fd, offset, 0);
X				check = write(fd, data, written);
X				if (check == written) continue;
X
X			}
X			
X
X		}*/
X 		check = close(fd);
X		if (check < 0) {
X			msg_perror("Error while closing %s",skipcrud+head->header.name);
X		}
X
X		
X	set_filestat:
X
X		/*
X		 * If we are root, set the owner and group of the extracted
X		 * file.  This does what is wanted both on real Unix and on
X		 * System V.  If we are running as a user, we extract as that
X		 * user; if running as root, we extract as the original owner.
X		 */
X		if (we_are_root || f_do_chown) {
X			if (chown(skipcrud+head->header.name, hstat.st_uid,
X				  hstat.st_gid) < 0) {
X				msg_perror("cannot chown file %s to uid %d gid %d",skipcrud+head->header.name,hstat.st_uid,hstat.st_gid);
X			}
X		}
X
X		/*
X		 * Set the modified time of the file.
X		 * 
X		 * Note that we set the accessed time to "now", which
X		 * is really "the time we started extracting files".
X		 * unless f_gnudump is used, in which case .st_atime is used
X		 */
X		if (!f_modified) {
X			/* fixme if f_gnudump should set ctime too, but how? */
X			if(f_gnudump)
X				acc_upd_times[0]=hstat.st_atime;
X			else acc_upd_times[0] = now;	         /* Accessed now */
X			acc_upd_times[1] = hstat.st_mtime; /* Mod'd */
X			if (utime(skipcrud+head->header.name,
X			    acc_upd_times) < 0) {
X				msg_perror("couldn't change access and modification times of %s",skipcrud+head->header.name);
X			}
X		}
X		/* We do the utime before the chmod because some versions of
X		   utime are broken and trash the modes of the file.  Since
X		   we then change the mode anyway, we don't care. . . */
X
X		/*
X		 * If '-k' is not set, open() or creat() could have saved
X		 * the permission bits from a previously created file,
X		 * ignoring the ones we specified.
X		 * Even if -k is set, if the file has abnormal
X		 * mode bits, we must chmod since writing or chown() has
X		 * probably reset them.
X		 *
X		 * If -k is set, we know *we* created this file, so the mode
X		 * bits were set by our open().   If the file is "normal", we
X		 * skip the chmod.  This works because we did umask(0) if -p
X		 * is set, so umask will have left the specified mode alone.
X		 */
X		if ((!f_keep)
X		    || (hstat.st_mode & (S_ISUID|S_ISGID|S_ISVTX))) {
X			if (chmod(skipcrud+head->header.name,
X				  notumask & (int)hstat.st_mode) < 0) {
X				msg_perror("cannot change mode of file %s to %ld",skipcrud+head->header.name,notumask & (int)hstat.st_mode);
X			}
X		}
X
X	quit:
X		break;
X
X	case LF_LINK:
X	again_link:
X	{
X		struct stat st1,st2;
X
X		check = link (head->header.linkname,
X			      skipcrud+head->header.name);
X		if (check == 0)
X			break;
X		if (make_dirs(skipcrud+head->header.name))
X			goto again_link;
X		if(f_gnudump && errno==EEXIST)
X			break;
X		if(   stat(head->header.linkname, &st1) == 0
X		   && stat(skipcrud+head->header.name, &st2)==0
X		   && st1.st_dev==st2.st_dev
X		   && st1.st_ino==st2.st_ino)
X			break;
X		msg_perror("Could not link %s to %s",
X			skipcrud+head->header.name,head->header.linkname);
X	}
X		break;
X
X#ifdef S_IFLNK
X	case LF_SYMLINK:
X	again_symlink:
X		check = symlink(head->header.linkname,
X			        skipcrud+head->header.name);
X		/* FIXME, don't worry uid, gid, etc... */
X		if (check == 0)
X			break;
X		if (make_dirs(skipcrud+head->header.name))
X			goto again_symlink;
X		msg_perror("Could not create symlink to %s",head->header.linkname);
X		break;
X#endif
X
X#ifdef S_IFCHR
X	case LF_CHR:
X		hstat.st_mode |= S_IFCHR;
X		goto make_node;
X#endif
X
X#ifdef S_IFBLK
X	case LF_BLK:
X		hstat.st_mode |= S_IFBLK;
X		goto make_node;
X#endif
X
X#ifdef S_IFIFO
X	/* If local system doesn't support FIFOs, use default case */
X	case LF_FIFO:
X		hstat.st_mode |= S_IFIFO;
X		hstat.st_rdev = 0;		/* FIXME, do we need this? */
X		goto make_node;
X#endif
X
X	make_node:
X		check = mknod(skipcrud+head->header.name,
X			      (int) hstat.st_mode, (int) hstat.st_rdev);
X		if (check != 0) {
X			if (make_dirs(skipcrud+head->header.name))
X				goto make_node;
X			msg_perror("Could not make %s",skipcrud+head->header.name);
X			break;
X		};
X		goto set_filestat;
X
X	case LF_DIR:
X	case LF_DUMPDIR:
X		namelen = strlen(skipcrud+head->header.name)-1;
X	really_dir:
X		/* Check for trailing /, and zap as many as we find. */
X		while (namelen && head->header.name[skipcrud+namelen] == '/')
X			head->header.name[skipcrud+namelen--] = '\0';
X		if(f_gnudump) {		/* Read the entry and delete files
X					   that aren't listed in the archive */
X			gnu_restore(skipcrud);
X		
X		} else if(head->header.linkflag==LF_DUMPDIR)
X			skip_file((long)(hstat.st_size));
X
X	
X	again_dir:
X		check = mkdir(skipcrud+head->header.name,
X			      (we_are_root ? 0 : 0300) | (int)hstat.st_mode);
X		if (check != 0) {
X			struct stat st1;
X
X			if (make_dirs(skipcrud+head->header.name))
X				goto again_dir;
X			/* If we're trying to create '.', let it be. */
X			if (head->header.name[skipcrud+namelen] == '.' && 
X			    (namelen==0 ||
X			     head->header.name[skipcrud+namelen-1]=='/'))
X				goto check_perms;
X			if(   errno==EEXIST
X 			   && stat(skipcrud+head->header.name,&st1)==0
X 			   && (st1.st_mode&S_IFMT)==S_IFDIR)
X				break;
X			msg_perror("Could not create directory %s",skipcrud+head->header.name);
X			break;
X		}
X		
X	check_perms:
X		if (!we_are_root && 0300 != (0300 & (int) hstat.st_mode)) {
X			hstat.st_mode |= 0300;
X			msg("Added write and execute permission to directory %s",
X			  skipcrud+head->header.name);
X		}
X
X		goto set_filestat;
X		/* FIXME, Remember timestamps for after files created? */
X		/* FIXME, change mode after files created (if was R/O dir) */
X	case LF_VOLHDR:
X		if(f_verbose) {
X			printf("Reading %s\n",head->header.name);
X		}
X		break;
X
X	case LF_NAMES:
X		extract_mangle(head);
X		break;
X
X	case LF_MULTIVOL:
X		msg("Can't extract '%s'--file is continued from another volume\n",head->header.name);
X		skip_file((long)hstat.st_size);
X		break;
X
X	}
X
X	/* We don't need to save it any longer. */
X	saverec((union record **) 0);	/* Unsave it */
X}
X
X/*
X * After a file/link/symlink/dir creation has failed, see if
X * it's because some required directory was not present, and if
X * so, create all required dirs.
X */
Xint
Xmake_dirs(pathname)
X	char *pathname;
X{
X	char *p;			/* Points into path */
X	int madeone = 0;		/* Did we do anything yet? */
X	int save_errno = errno;		/* Remember caller's errno */
X	int check;
X
X	if (errno != ENOENT)
X		return 0;		/* Not our problem */
X
X	for (p = index(pathname, '/'); p != NULL; p = index(p+1, '/')) {
X		/* Avoid mkdir of empty string, if leading or double '/' */
X		if (p == pathname || p[-1] == '/')
X			continue;
X		/* Avoid mkdir where last part of path is '.' */
X		if (p[-1] == '.' && (p == pathname+1 || p[-2] == '/'))
X			continue;
X		*p = 0;				/* Truncate the path there */
X		check = mkdir (pathname, 0777);	/* Try to create it as a dir */
X		if (check == 0) {
X			/* Fix ownership */
X			if (we_are_root) {
X				if (chown(pathname, hstat.st_uid,
X					  hstat.st_gid) < 0) {
X					msg_perror("cannot change owner of %s to uid %d gid %d",pathname,hstat.st_uid,hstat.st_gid);
X				}
X			}
X			pr_mkdir(pathname, p-pathname, notumask&0777);
X			madeone++;		/* Remember if we made one */
X			*p = '/';
X			continue;
X		}
X		*p = '/';
X		if (errno == EEXIST)		/* Directory already exists */
X			continue;
X		/*
X		 * Some other error in the mkdir.  We return to the caller.
X		 */
X		break;
X	}
X
X	errno = save_errno;		/* Restore caller's errno */
X	return madeone;			/* Tell them to retry if we made one */
X}
X
Xextract_sparse_file(fd, sizeleft, totalsize, name)
X	int	fd;
X	long	*sizeleft,
X		totalsize;
X	char	*name;
X{		
X	register char	*data;
X	union record	*datarec;
X	int	sparse_ind = 0;
X	int	written,
X		count;
X	
X	/* assuming sizeleft is initially totalsize */
X
X
X	while (*sizeleft > 0) {
X		datarec = findrec();
X		if (datarec == NULL) {
X			msg("Unexpected EOF on archive file");
X			return;
X		}
X		lseek(fd, sparsearray[sparse_ind].offset, 0);
X		written = sparsearray[sparse_ind++].numbytes;
X		while (written > RECORDSIZE) {
X			count = write(fd, datarec->charptr, RECORDSIZE);
X			if (count < 0) 
X				msg_perror("couldn't write to file %s", name);
X			written -= count;
X			*sizeleft -= count;
X			userec(datarec);
X			datarec = findrec();
X		}
X
X		count = write(fd, datarec->charptr, written);
X	        
X		if (count < 0) {
X			msg_perror("couldn't write to file %s", name);
X		} else if (count != written) {
X			msg("could only write %d of %d bytes to file %s", totalsize - *sizeleft, totalsize, name);
X			skip_file((long) (*sizeleft));
X		}
X
X		written -= count;
X		*sizeleft -= count;		
X		userec(datarec);
X	}
X	free(sparsearray);
X/*	if (end_nulls) {
X		register int i;
X
X		printf("%d\n", (int) end_nulls);
X		for (i = 0; i < end_nulls; i++)
X			write(fd, "\000", 1);
X	}*/
X	userec(datarec);
X}
END_OF_FILE
if test 20086 -ne `wc -c <'extract.c'`; then
    echo shar: \"'extract.c'\" unpacked with wrong size!
fi
# end of 'extract.c'
fi
if test -f 'buffer.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'buffer.c'\"
else
echo shar: Extracting \"'buffer.c'\" \(30617 characters\)
sed "s/^X//" >'buffer.c' <<'END_OF_FILE'
X/* Buffer management for tar.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/*
X * Buffer management for tar.
X *
X * Written by John Gilmore, ihnp4!hoptoad!gnu, on 25 August 1985.
X *
X * @(#) buffer.c 1.28 11/6/87 - gnu
X */
X
X#include <stdio.h>
X#include <errno.h>
X#include <sys/types.h>		/* For non-Berkeley systems */
X#include <sys/stat.h>
X#include <signal.h>
X
X#ifndef MSDOS
X#include <sys/ioctl.h>
X#if !defined(USG) || defined(HAVE_MTIO)
X#include <sys/mtio.h>
X#endif
X#endif
X
X#ifdef	MSDOS
X# include <fcntl.h>
X#include <process.h>
X#else
X# ifdef XENIX
X#  include <sys/inode.h>
X# endif
X# include <sys/file.h>
X#endif
X
Xextern int errno;
X
X#include "tar.h"
X#include "port.h"
X#include "rmt.h"
X#include "regex.h"
X
X/* Either stdout or stderr:  The thing we write messages (standard msgs, not
X   errors) to.  Stdout unless we're writing a pipe, in which case stderr */
XFILE *msg_file = stdout;
X
X#define	STDIN	0		/* Standard input  file descriptor */
X#define	STDOUT	1		/* Standard output file descriptor */
X
X#define	PREAD	0		/* Read  file descriptor from pipe() */
X#define	PWRITE	1		/* Write file descriptor from pipe() */
X
X#ifdef __STDC__
Xextern void	*malloc();
Xextern void	*valloc();
X#else
Xextern char	*malloc();
Xextern char	*valloc();
X#endif
Xextern time_t time();
X
Xextern char	*index(), *strcat();
Xextern char	*strcpy();
X
X/*
X * V7 doesn't have a #define for this.
X */
X#ifndef O_RDONLY
X#define	O_RDONLY	0
X#endif
X#ifndef O_RDWR
X#define O_RDWR		2
X#endif
X#ifndef O_CREAT
X#define O_CREAT		0
X#endif
X#ifndef O_BINARY
X#define O_BINARY	0
X#endif
X
X#define	MAGIC_STAT	105	/* Magic status returned by child, if
X				   it can't exec.  We hope compress/sh
X				   never return this status! */
X
Xvoid writeerror();
Xvoid readerror();
X
Xvoid ck_pipe();
Xvoid ck_close();
X
Xextern void finish_header();
Xextern void to_oct();
X
X#ifndef __MSDOS__
X/* Obnoxious test to see if dimwit is trying to dump the archive */
Xdev_t ar_dev;
Xino_t ar_ino;
X#endif
X
X/*
X * The record pointed to by save_rec should not be overlaid
X * when reading in a new tape block.  Copy it to record_save_area first, and
X * change the pointer in *save_rec to point to record_save_area.
X * Saved_recno records the record number at the time of the save.
X * This is used by annofile() to print the record number of a file's
X * header record.
X */
Xstatic union record **save_rec;
X union record record_save_area;
Xstatic long	    saved_recno;
X
X/*
X * PID of child program, if f_compress or remote archive access.
X */
Xstatic int	childpid = 0;
X
X/*
X * Record number of the start of this block of records
X */
Xlong	baserec;
X
X/*
X * Error recovery stuff
X */
Xstatic int	r_error_count;
X
X/*
X * Have we hit EOF yet?
X */
Xstatic int	eof;
X
X/* JF we're reading, but we just read the last record and its time to update */
Xextern time_to_start_writing;
Xint file_to_switch_to= -1;	/* If remote update, close archive, and use
X				   this descriptor to write to */
X
Xstatic int volno = 1;		/* JF which volume of a multi-volume tape
X				   we're on */
X
Xchar *save_name = 0;		/* Name of the file we are currently writing */
Xlong save_totsize;		/* total size of file we are writing.  Only
X				   valid if save_name is non_zero */
Xlong save_sizeleft;		/* Where we are in the file we are writing.
X				   Only valid if save_name is non-zero */
X
Xint write_archive_to_stdout;
X
X/* Used by fl_read and fl_write to store the real info about saved names */
Xstatic char real_s_name[NAMSIZ];
Xstatic long real_s_totsize;
Xstatic long real_s_sizeleft;
X
X/* Reset the EOF flag (if set), and re-set ar_record, etc */
X
Xvoid
Xreset_eof()
X{
X	if(eof) {
X		eof=0;
X		ar_record=ar_block;
X		ar_last=ar_block+blocking;
X		ar_reading=0;
X	}
X}
X
X/*
X * Return the location of the next available input or output record.
X * Return NULL for EOF.  Once we have returned NULL, we just keep returning
X * it, to avoid accidentally going on to the next file on the "tape".
X */
Xunion record *
Xfindrec()
X{
X	if (ar_record == ar_last) {
X		if (eof)
X			return (union record *)NULL;	/* EOF */
X		flush_archive();
X		if (ar_record == ar_last) {
X			eof++;
X			return (union record *)NULL;	/* EOF */
X		}
X	}
X	return ar_record;
X}
X
X
X/*
X * Indicate that we have used all records up thru the argument.
X * (should the arg have an off-by-1? XXX FIXME)
X */
Xvoid
Xuserec(rec)
X	union record *rec;
X{
X	while(rec >= ar_record)
X		ar_record++;
X	/*
X	 * Do NOT flush the archive here.  If we do, the same
X	 * argument to userec() could mean the next record (if the
X	 * input block is exactly one record long), which is not what
X	 * is intended.
X	 */
X	if (ar_record > ar_last)
X		abort();
X}
X
X
X/*
X * Return a pointer to the end of the current records buffer.
X * All the space between findrec() and endofrecs() is available
X * for filling with data, or taking data from.
X */
Xunion record *
Xendofrecs()
X{
X	return ar_last;
X}
X
X
X/*
X * Duplicate a file descriptor into a certain slot.
X * Equivalent to BSD "dup2" with error reporting.
X */
Xvoid
Xdupto(from, to, msg)
X	int from, to;
X	char *msg;
X{
X	int err;
X
X	if (from != to) {
X		err=close(to);
X		if(err<0 && errno!=EBADF) {
X			msg_perror("Cannot close descriptor %d",to);
X			exit(EX_SYSTEM);
X		}
X		err = dup(from);
X		if (err != to) {
X			msg_perror("cannot dup %s",msg);
X			exit(EX_SYSTEM);
X		}
X		ck_close(from);
X	}
X}
X
X#ifdef MSDOS
Xvoid
Xchild_open()
X{
X	fprintf(stderr,"MSDOS %s can't use compressed or remote archives\n",tar);
X	exit(EX_ARGSBAD);
X}
X#else
Xvoid
Xchild_open()
X{
X	int pipe[2];
X	int err = 0;
X
X	int kidpipe[2];
X	int kidchildpid;
X
X#define READ	0
X#define WRITE	1
X
X	ck_pipe(pipe);
X
X	childpid=fork();
X	if(childpid<0) {
X		msg_perror("cannot fork");
X		exit(EX_SYSTEM);
X	}
X	if(childpid>0) {
X		/* We're the parent.  Clean up and be happy */
X		/* This, at least, is easy */
X
X		if(ar_reading) {
X			f_reblock++;
X			archive=pipe[READ];
X			ck_close(pipe[WRITE]);
X		} else {
X			archive = pipe[WRITE];
X			ck_close(pipe[READ]);
X		}
X		return;
X	}
X
X	/* We're the kid */
X	if(ar_reading) {
X		dupto(pipe[WRITE],STDOUT,"(child) pipe to stdout");
X		ck_close(pipe[READ]);
X	} else {
X		dupto(pipe[READ],STDIN,"(child) pipe to stdin");
X		ck_close(pipe[WRITE]);
X	}
X
X	/* We need a child tar only if
X	   1: we're reading/writing stdin/out (to force reblocking)
X	   2: the file is to be accessed by rmt (compress doesn't know how)
X	   3: the file is not a plain file */
X#ifdef NO_REMOTE
X	if(!(ar_file[0]=='-' && ar_file[1]=='\0') && isfile(ar_file))
X#else
X	if(!(ar_file[0]=='-' && ar_file[1]=='\0') && !_remdev(ar_file) && isfile(ar_file))
X#endif
X	{
X		/* We don't need a child tar.  Open the archive */
X		if(ar_reading) {
X			archive=open(ar_file, O_RDONLY|O_BINARY, 0666);
X			if(archive<0) {
X				msg_perror("can't open archive %s",ar_file);
X				exit(EX_BADARCH);
X			}
X			dupto(archive,STDIN,"archive to stdin");
X			/* close(archive); */
X		} else {
X			archive=creat(ar_file,0666);
X			if(archive<0) {
X				msg_perror("can't open archive %s",ar_file);
X				exit(EX_BADARCH);
X			}
X			dupto(archive,STDOUT,"archive to stdout");
X			/* close(archive); */
X		}
X	} else {
X		/* We need a child tar */
X		ck_pipe(kidpipe);
X
X		kidchildpid=fork();
X		if(kidchildpid<0) {
X			msg_perror("child can't fork");
X			exit(EX_SYSTEM);
X		}
X
X		if(kidchildpid>0) {
X			/* About to exec compress:  set up the files */
X			if(ar_reading) {
X				dupto(kidpipe[READ],STDIN,"((child)) pipe to stdin");
X				ck_close(kidpipe[WRITE]);
X				/* dup2(pipe[WRITE],STDOUT); */
X			} else {
X				/* dup2(pipe[READ],STDIN); */
X				dupto(kidpipe[WRITE],STDOUT,"((child)) pipe to stdout");
X				ck_close(kidpipe[READ]);
X			}
X			/* ck_close(pipe[READ]); */
X			/* ck_close(pipe[WRITE]); */
X			/* ck_close(kidpipe[READ]);
X			ck_close(kidpipe[WRITE]); */
X		} else {
X		/* Grandchild.  Do the right thing, namely sit here and
X		   read/write the archive, and feed stuff back to compress */
X			tar="tar (child)";
X			if(ar_reading) {
X				dupto(kidpipe[WRITE],STDOUT,"[child] pipe to stdout");
X				ck_close(kidpipe[READ]);
X			} else {
X				dupto(kidpipe[READ],STDIN,"[child] pipe to stdin");
X				ck_close(kidpipe[WRITE]);
X			}
X
X			if (ar_file[0] == '-' && ar_file[1] == '\0') {
X				if (ar_reading)
X					archive = STDIN;
X				else
X					archive = STDOUT;
X			} else /* This can't happen if (ar_reading==2)
X				archive = rmtopen(ar_file, O_RDWR|O_CREAT|O_BINARY, 0666);
X			else */if(ar_reading)
X				archive = rmtopen(ar_file, O_RDONLY|O_BINARY, 0666);
X			else
X				archive = rmtcreat(ar_file, 0666);
X
X			if (archive < 0) {
X				msg_perror("can't open archive %s",ar_file);
X				exit(EX_BADARCH);
X			}
X
X			if(ar_reading) {
X				for(;;) {
X					char *ptr;
X					int max,count;
X		
X					r_error_count = 0;
X				error_loop:
X					err=rmtread(archive, ar_block->charptr,(int)(blocksize));
X					if(err<0) {
X						readerror();
X						goto error_loop;
X					}
X					if(err==0)
X						break;
X					ptr = ar_block->charptr;
X					max = err;
X					while(max) {
X						count = (max<RECORDSIZE) ? max : RECORDSIZE;
X						err=write(STDOUT,ptr,count);
X						if(err!=count) {
X							if(err<0) {
X								msg_perror("can't write to compress");
X								exit(EX_SYSTEM);
X							} else
X								msg("write to compress short %d bytes",count-err);
X							count = (err<0) ? 0 : err;
X						}
X						ptr+=count;
X						max-=count;
X					}
X				}
X			} else {
X				for(;;) {
X					int n;
X					char *ptr;
X		
X					n=blocksize;
X					ptr = ar_block->charptr;
X					while(n) {
X						err=read(STDIN,ptr,(n<RECORDSIZE) ? n : RECORDSIZE);
X						if(err<=0)
X							break;
X						n-=err;
X						ptr+=err;
X					}
X						/* EOF */
X					if(err==0) {
X						if(f_compress<2)
X							blocksize-=n;
X						else
X							bzero(ar_block->charptr+blocksize-n,n);
X						err=rmtwrite(archive,ar_block->charptr,blocksize);
X						if(err!=(blocksize))
X							writeerror(err);
X						if(f_compress<2)
X							blocksize+=n;
X						break;
X					}
X					if(n) {
X						msg_perror("can't read from compress");
X						exit(EX_SYSTEM);
X					}
X					err=rmtwrite(archive, ar_block->charptr, (int)blocksize);
X					if(err!=blocksize)
X						writeerror(err);
X				}
X			}
X		
X			/* close_archive(); */
X			exit(0);
X		}
X	}
X		/* So we should exec compress (-d) */
X	if(ar_reading)
X		execlp("compress", "compress", "-d", (char *)0);
X	else
X		execlp("compress", "compress", (char *)0);
X	msg_perror("can't exec compress");
X	_exit(EX_SYSTEM);
X}
X
X
X/* return non-zero if p is the name of a directory */
Xisfile(p)
Xchar *p;
X{
X	struct stat stbuf;
X
X	if(stat(p,&stbuf)<0)
X		return 1;
X	if((stbuf.st_mode&S_IFMT)==S_IFREG)
X		return 1;
X	return 0;
X}
X
X#endif
X
X/*
X * Open an archive file.  The argument specifies whether we are
X * reading or writing.
X */
X/* JF if the arg is 2, open for reading and writing. */
Xopen_archive(reading)
X	int reading;
X{
X	msg_file = f_exstdout ? stderr : stdout;
X
X	if (blocksize == 0) {
X		msg("invalid value for blocksize");
X		exit(EX_ARGSBAD);
X	}
X
X	if(ar_file==0) {
X		msg("No archive name given, what should I do?");
X		exit(EX_BADARCH);
X	}
X
X	/*NOSTRICT*/
X	if(f_multivol) {
X		ar_block = (union record *) valloc((unsigned)(blocksize+(2*RECORDSIZE)));
X		if(ar_block)
X			ar_block += 2;
X	} else
X		ar_block = (union record *) valloc((unsigned)blocksize);
X	if (!ar_block) {
X		msg("could not allocate memory for blocking factor %d",
X			blocking);
X		exit(EX_ARGSBAD);
X	}
X
X	ar_record = ar_block;
X	ar_last   = ar_block + blocking;
X	ar_reading = reading;
X
X	if (f_compress) {
X		if(reading==2 || f_verify) {
X			msg("cannot update or verify compressed archives");
X			exit(EX_ARGSBAD);
X		}
X		child_open();
X		if(!reading && ar_file[0]=='-' && ar_file[1]=='\0')
X			msg_file = stderr;
X		/* child_open(rem_host, rem_file); */
X	} else if (ar_file[0] == '-' && ar_file[1] == '\0') {
X		f_reblock++;	/* Could be a pipe, be safe */
X		if(f_verify) {
X			msg("can't verify stdin/stdout archive");
X			exit(EX_ARGSBAD);
X		}
X		if(reading==2) {
X			archive=STDIN;
X			msg_file=stderr;
X			write_archive_to_stdout++;
X		} else if (reading)
X			archive = STDIN;
X		else {
X			archive = STDOUT;
X			msg_file = stderr;
X		}
X	} else if (reading==2 || f_verify) {
X		archive = rmtopen(ar_file, O_RDWR|O_CREAT|O_BINARY, 0666);
X	} else if(reading) {
X		archive = rmtopen(ar_file, O_RDONLY|O_BINARY, 0666);
X	} else {
X		archive = rmtcreat(ar_file, 0666);
X	}
X#ifndef __MSDOS__
X	if(!_isrmt(archive)) {
X		struct stat tmp_stat;
X
X		fstat(archive,&tmp_stat);
X		if((tmp_stat.st_mode&S_IFMT)==S_IFREG) {
X			ar_dev=tmp_stat.st_dev;
X			ar_ino=tmp_stat.st_ino;
X		}
X	}
X#endif
X
X	if (archive < 0) {
X		msg_perror("can't open %s",ar_file);
X		exit(EX_BADARCH);
X	}
X#ifdef	MSDOS
X	setmode(archive, O_BINARY);
X#endif
X
X	if (reading) {
X		ar_last = ar_block;		/* Set up for 1st block = # 0 */
X		(void) findrec();		/* Read it in, check for EOF */
X
X		if(f_volhdr) {
X			union record *head;
X#if 0
X			char *ptr;
X
X			if(f_multivol) {
X				ptr=malloc(strlen(f_volhdr)+20);
X				sprintf(ptr,"%s Volume %d",f_volhdr,1);
X			} else
X				ptr=f_volhdr;
X#endif
X			head=findrec();
X			if(!head) {
X				msg("Archive not labelled to match %s",f_volhdr);
X				exit(EX_BADVOL);
X			}
X			if (re_match (label_pattern, head->header.name,
X				      strlen (head->header.name), 0, 0) < 0) {
X				msg ("Volume mismatch!  %s!=%s", f_volhdr,
X				     head->header.name);
X				exit (EX_BADVOL);
X			}
X#if 0			
X			if(strcmp(ptr,head->header.name)) {
X				msg("Volume mismatch!  %s!=%s",ptr,head->header.name);
X				exit(EX_BADVOL);
X			}
X			if(ptr!=f_volhdr)
X				free(ptr);
X#endif
X		}
X	} else if(f_volhdr) {
X		bzero((void *)ar_block,RECORDSIZE);
X		if(f_multivol)
X			sprintf(ar_block->header.name,"%s Volume 1",f_volhdr);
X		else
X			strcpy(ar_block->header.name,f_volhdr);
X		ar_block->header.linkflag = LF_VOLHDR;
X		to_oct(time(0),	1+12, ar_block->header.mtime);
X		finish_header(ar_block);
X		/* ar_record++; */
X	}
X}
X
X
X/*
X * Remember a union record * as pointing to something that we
X * need to keep when reading onward in the file.  Only one such
X * thing can be remembered at once, and it only works when reading
X * an archive.
X *
X * We calculate "offset" then add it because some compilers end up
X * adding (baserec+ar_record), doing a 9-bit shift of baserec, then
X * subtracting ar_block from that, shifting it back, losing the top 9 bits.
X */
Xsaverec(pointer)
X	union record **pointer;
X{
X	long offset;
X
X	save_rec = pointer;
X	offset = ar_record - ar_block;
X	saved_recno = baserec + offset;
X}
X
X/*
X * Perform a write to flush the buffer.
X */
X
X/*send_buffer_to_file();
X  if(new_volume) {
X  	deal_with_new_volume_stuff();
X	send_buffer_to_file();
X  }
X */
X
Xfl_write()
X{
X	int err;
X	int copy_back;
X	static long bytes_written = 0;
X
X	if(tape_length && bytes_written >= tape_length * 1024) {
X		errno = ENOSPC;
X		err = 0;
X	} else
X		err = rmtwrite(archive, ar_block->charptr,(int) blocksize);
X	if(err!=blocksize && !f_multivol)
X		writeerror(err);
X	else if (f_totals)
X	        tot_written += blocksize;
X
X	if(err>0)
X		bytes_written+=err;
X	if (err == blocksize) {
X		if(f_multivol) {
X			if(!save_name) {
X				real_s_name[0]='\0';
X				real_s_totsize=0;
X				real_s_sizeleft = 0;
X				return;
X			}
X#ifdef MSDOS
X			if(save_name[1]==':')
X				save_name+=2;
X#endif
X			while(*save_name=='/')
X				save_name++;
X
X			strcpy(real_s_name,save_name);
X			real_s_totsize = save_totsize;
X			real_s_sizeleft = save_sizeleft;
X		}
X		return;
X	}
X
X	/* We're multivol  Panic if we didn't get the right kind of response */
X	/* ENXIO is for the UNIX PC */
X	if(err>0 || (err<0 && errno!=ENOSPC && errno!=EIO && errno!=ENXIO))
X		writeerror(err);
X
X	if(new_volume(0)<0)
X		return;
X	bytes_written=0;
X	if(f_volhdr && real_s_name[0]) {
X		copy_back=2;
X		ar_block-=2;
X	} else if(f_volhdr || real_s_name[0]) {
X		copy_back = 1;
X		ar_block--;
X	} else
X		copy_back = 0;
X	if(f_volhdr) {
X		bzero((void *)ar_block,RECORDSIZE);
X		sprintf(ar_block->header.name,"%s Volume %d",f_volhdr,volno);
X		to_oct(time(0),	1+12, ar_block->header.mtime);
X		ar_block->header.linkflag = LF_VOLHDR;
X		finish_header(ar_block);
X	}
X	if(real_s_name[0]) {
X		int tmp;
X
X		if(f_volhdr)
X			ar_block++;
X		bzero((void *)ar_block,RECORDSIZE);
X		strcpy(ar_block->header.name,real_s_name);
X		ar_block->header.linkflag = LF_MULTIVOL;
X		to_oct((long)real_s_sizeleft,1+12,
X		       ar_block->header.size);
X		to_oct((long)real_s_totsize-real_s_sizeleft,
X		       1+12,ar_block->header.offset);
X		tmp=f_verbose;
X		f_verbose=0;
X		finish_header(ar_block);
X		f_verbose=tmp;
X		if(f_volhdr)
X			ar_block--;
X	}
X
X	err = rmtwrite(archive, ar_block->charptr,(int) blocksize);
X	if(err!=blocksize)
X		writeerror(err);
X	else if (f_totals)
X	        tot_written += blocksize;
X	        
X
X	bytes_written = blocksize;
X	if(copy_back) {
X		ar_block+=copy_back;
X		bcopy((void *)(ar_block+blocking-copy_back),
X		      (void *)ar_record,
X		      copy_back*RECORDSIZE);
X		ar_record+=copy_back;
X
X		if(real_s_sizeleft>=copy_back*RECORDSIZE)
X			real_s_sizeleft-=copy_back*RECORDSIZE;
X		else if((real_s_sizeleft+RECORDSIZE-1)/RECORDSIZE<=copy_back)
X			real_s_name[0] = '\0';
X		else {
X#ifdef MSDOS
X			if(save_name[1]==':')
X				save_name+=2;
X#endif
X			while(*save_name=='/')
X				save_name++;
X
X			strcpy(real_s_name,save_name);
X			real_s_sizeleft = save_sizeleft;
X			real_s_totsize=save_totsize;
X		}
X		copy_back = 0;
X	}
X}
X
X/* Handle write errors on the archive.  Write errors are always fatal */
X/* Hitting the end of a volume does not cause a write error unless the write
X*  was the first block of the volume */
X
Xvoid
Xwriteerror(err)
Xint err;
X{
X	if (err < 0) {
X		msg_perror("can't write to %s",ar_file);
X		exit(EX_BADARCH);
X	} else {
X		msg("only wrote %u of %u bytes to %s",err,blocksize,ar_file);
X		exit(EX_BADARCH);
X	}
X}
X
X/*
X * Handle read errors on the archive.
X *
X * If the read should be retried, readerror() returns to the caller.
X */
Xvoid
Xreaderror()
X{
X#	define	READ_ERROR_MAX	10
X
X	read_error_flag++;		/* Tell callers */
X
X	msg_perror("read error on %s",ar_file);
X
X	if (baserec == 0) {
X		/* First block of tape.  Probably stupidity error */
X		exit(EX_BADARCH);
X	}
X
X	/*
X	 * Read error in mid archive.  We retry up to READ_ERROR_MAX times
X	 * and then give up on reading the archive.  We set read_error_flag
X	 * for our callers, so they can cope if they want.
X	 */
X	if (r_error_count++ > READ_ERROR_MAX) {
X		msg("Too many errors, quitting.");
X		exit(EX_BADARCH);
X	}
X	return;
X}
X
X
X/*
X * Perform a read to flush the buffer.
X */
Xfl_read()
X{
X	int err;		/* Result from system call */
X	int left;		/* Bytes left */
X	char *more;		/* Pointer to next byte to read */
X
X	/*
X	 * Clear the count of errors.  This only applies to a single
X	 * call to fl_read.  We leave read_error_flag alone; it is
X	 * only turned off by higher level software.
X	 */
X	r_error_count = 0;	/* Clear error count */
X
X	/*
X	 * If we are about to wipe out a record that
X	 * somebody needs to keep, copy it out to a holding
X	 * area and adjust somebody's pointer to it.
X	 */
X	if (save_rec &&
X	    *save_rec >= ar_record &&
X	    *save_rec < ar_last) {
X		record_save_area = **save_rec;
X		*save_rec = &record_save_area;
X	}
X	if(write_archive_to_stdout && baserec!=0) {
X		err=rmtwrite(1, ar_block->charptr, blocksize);
X		if(err!=blocksize)
X			writeerror(err);
X	}
X	if(f_multivol) {
X		if(save_name) {
X			if(save_name!=real_s_name) {
X#ifdef MSDOS
X				if(save_name[1]==':')
X					save_name+=2;
X#endif
X				while(*save_name=='/')
X					save_name++;
X
X				strcpy(real_s_name,save_name);
X				save_name=real_s_name;
X			}
X			real_s_totsize = save_totsize;
X			real_s_sizeleft = save_sizeleft;
X				
X		} else {
X			real_s_name[0]='\0';
X			real_s_totsize=0;
X			real_s_sizeleft = 0;
X		}
X	}
X
Xerror_loop:
X	err = rmtread(archive, ar_block->charptr, (int)blocksize);
X	if (err == blocksize)
X		return;
X
X	if((err == 0 || (err<0 && errno==ENOSPC)) && f_multivol) {
X		union record *head;
X
X	try_volume:
X		if(new_volume((cmd_mode==CMD_APPEND || cmd_mode==CMD_CAT || cmd_mode==CMD_UPDATE) ? 2 : 1)<0)
X			return;
X	vol_error:
X		err = rmtread(archive, ar_block->charptr,(int) blocksize);
X		if(err < 0) {
X			readerror();
X			goto vol_error;
X		}
X		if(err!=blocksize)
X			goto short_read;
X
X		head=ar_block;
X
X		if(head->header.linkflag==LF_VOLHDR) {
X			if(f_volhdr) {
X#if 0
X				char *ptr;
X
X				ptr=(char *)malloc(strlen(f_volhdr)+20);
X				sprintf(ptr,"%s Volume %d",f_volhdr,volno);
X#endif
X				if (re_match (label_pattern, head->header.name,
X					      strlen (head->header.name),
X					      0, 0) < 0) {
X					msg("Volume mismatch! %s!=%s",f_volhdr,
X					    head->header.name);
X					--volno;
X					goto try_volume;
X				      }
X				    
X#if 0
X 				if(strcmp(ptr,head->header.name)) {
X					msg("Volume mismatch! %s!=%s",ptr,head->header.name);
X					--volno;
X					free(ptr);
X					goto try_volume;
X				}
X				free(ptr);
X#endif
X			}
X			if(f_verbose)
X				fprintf(msg_file,"Reading %s",head->header.name);
X			head++;
X		} else if(f_volhdr) {
X			msg("Warning:  No volume header!");
X		}
X
X		if(real_s_name[0]) {
X			long from_oct();
X
X			if(head->header.linkflag!=LF_MULTIVOL || strcmp(head->header.name,real_s_name)) {
X				msg("%s is not continued on this volume!",real_s_name);
X				--volno;
X				goto try_volume;
X			}
X			if(real_s_totsize!=from_oct(1+12,head->header.size)+from_oct(1+12,head->header.offset)) {
X				msg("%s is the wrong size (%ld!=%ld+%ld)",
X				       head->header.name,save_totsize,
X				       from_oct(1+12,head->header.size),
X				       from_oct(1+12,head->header.offset));
X				--volno;
X				goto try_volume;
X			}
X			if(real_s_totsize-real_s_sizeleft!=from_oct(1+12,head->header.offset)) {
X				msg("This volume is out of sequence");
X				--volno;
X				goto try_volume;
X			}
X			head++;
X		}
X		ar_record=head;
X		return;
X	} else if (err < 0) {
X		readerror();
X		goto error_loop;	/* Try again */
X	}
X
X short_read:
X	more = ar_block->charptr + err;
X	left = blocksize - err;
X
Xagain:
X	if (0 == (((unsigned)left) % RECORDSIZE)) {
X		/* FIXME, for size=0, multi vol support */
X		/* On the first block, warn about the problem */
X		if (!f_reblock && baserec == 0 && f_verbose && err > 0) {
X		/*	msg("Blocksize = %d record%s",
X				err / RECORDSIZE, (err > RECORDSIZE)? "s": "");*/
X			msg("Blocksize = %d records", err / RECORDSIZE);
X		}
X		ar_last = ar_block + ((unsigned)(blocksize - left))/RECORDSIZE;
X		return;
X	}
X	if (f_reblock) {
X		/*
X		 * User warned us about this.  Fix up.
X		 */
X		if (left > 0) {
Xerror2loop:
X			err = rmtread(archive, more, (int)left);
X			if (err < 0) {
X				readerror();
X				goto error2loop;	/* Try again */
X			}
X			if (err == 0) {
X				msg("archive %s EOF not on block boundary",ar_file);
X				exit(EX_BADARCH);
X			}
X			left -= err;
X			more += err;
X			goto again;
X		}
X	} else {
X		msg("only read %d bytes from archive %s",err,ar_file);
X		exit(EX_BADARCH);
X	}
X}
X
X
X/*
X * Flush the current buffer to/from the archive.
X */
Xflush_archive()
X{
X	int c;
X
X	baserec += ar_last - ar_block;	/* Keep track of block #s */
X	ar_record = ar_block;		/* Restore pointer to start */
X	ar_last = ar_block + blocking;	/* Restore pointer to end */
X
X	if (ar_reading) {
X		if(time_to_start_writing) {
X			time_to_start_writing=0;
X			ar_reading=0;
X
X			if(file_to_switch_to>=0) {
X				if((c=rmtclose(archive))<0)
X					msg_perror("Warning: can't close %s(%d,%d)",ar_file,archive,c);
X
X				archive=file_to_switch_to;
X			} else
X	 			(void)backspace_output();
X			fl_write();
X		} else
X			fl_read();
X	} else {
X		fl_write();
X	}
X}
X
X/* Backspace the archive descriptor by one blocks worth.
X   If its a tape, MTIOCTOP will work.  If its something else,
X   we try to seek on it.  If we can't seek, we lose! */
Xbackspace_output()
X{
X	long cur;
X	/* int er; */
X	extern char *output_start;
X
X#ifdef MTIOCTOP
X	struct mtop t;
X
X	t.mt_op = MTBSR;
X	t.mt_count = 1;
X	if((rmtioctl(archive,MTIOCTOP,&t))>=0)
X		return 1;
X	if(errno==EIO && (rmtioctl(archive,MTIOCTOP,&t))>=0)
X		return 1;
X#endif
X
X		cur=rmtlseek(archive,0L,1);
X	cur-=blocksize;
X	/* Seek back to the beginning of this block and
X	   start writing there. */
X
X	if(rmtlseek(archive,cur,0)!=cur) {
X		/* Lseek failed.  Try a different method */
X		msg("Couldn't backspace archive file.  It may be unreadable without -i.");
X		/* Replace the first part of the block with nulls */
X		if(ar_block->charptr!=output_start)
X			bzero(ar_block->charptr,output_start-ar_block->charptr);
X		return 2;
X	}
X	return 3;
X}
X
X
X/*
X * Close the archive file.
X */
Xclose_archive()
X{
X	int child;
X	int status;
X	int c;
X
X	if (time_to_start_writing || !ar_reading)
X		flush_archive();
X	if(cmd_mode==CMD_DELETE) {
X		long pos;
X
X		pos = rmtlseek(archive,0L,1);
X#ifndef MSDOS
X		/* FIXME does ftruncate really take an INT?! */
X		(void) ftruncate(archive,(int)pos);
X#else
X		(void)rmtwrite(archive,"",0);
X#endif
X	}
X	if(f_verify)
X		verify_volume();
X
X	if((c=rmtclose(archive))<0)
X		msg_perror("Warning: can't close %s(%d,%d)",ar_file,archive,c);
X
X#ifndef	MSDOS
X	if (childpid) {
X		/*
X		 * Loop waiting for the right child to die, or for
X		 * no more kids.
X		 */
X		while (((child = wait(&status)) != childpid) && child != -1)
X			;
X
X		if (child != -1) {
X			switch (TERM_SIGNAL(status)) {
X			case 0:
X				/* Child voluntarily terminated  -- but why? */
X				if (TERM_VALUE(status) == MAGIC_STAT) {
X					exit(EX_SYSTEM);/* Child had trouble */
X				}
X				if (TERM_VALUE(status) == (SIGPIPE + 128)) {
X					/*
X					 * /bin/sh returns this if its child
X					 * dies with SIGPIPE.  'Sok.
X					 */
X					break;
X				} else if (TERM_VALUE(status))
X					msg("child returned status %d",
X						TERM_VALUE(status));
X			case SIGPIPE:
X				break;		/* This is OK. */
X
X			default:
X				msg("child died with signal %d%s",
X				 TERM_SIGNAL(status),
X				 TERM_COREDUMP(status)? " (core dumped)": "");
X			}
X		}
X	}
X#endif	/* MSDOS */
X}
X
X
X#ifdef DONTDEF
X/*
X * Message management.
X *
X * anno writes a message prefix on stream (eg stdout, stderr).
X *
X * The specified prefix is normally output followed by a colon and a space.
X * However, if other command line options are set, more output can come
X * out, such as the record # within the archive.
X *
X * If the specified prefix is NULL, no output is produced unless the
X * command line option(s) are set.
X *
X * If the third argument is 1, the "saved" record # is used; if 0, the
X * "current" record # is used.
X */
Xvoid
Xanno(stream, prefix, savedp)
X	FILE	*stream;
X	char	*prefix;
X	int	savedp;
X{
X#	define	MAXANNO	50
X	char	buffer[MAXANNO];	/* Holds annorecment */
X#	define	ANNOWIDTH 13
X	int	space;
X	long	offset;
X	int	save_e;
X
X	save_e=errno;
X	/* Make sure previous output gets out in sequence */
X	if (stream == stderr)
X		fflush(stdout);
X	if (f_sayblock) {
X		if (prefix) {
X			fputs(prefix, stream);
X			putc(' ', stream);
X		}
X		offset = ar_record - ar_block;
X		(void) sprintf(buffer, "rec %d: ",
X			savedp?	saved_recno:
X				baserec + offset);
X		fputs(buffer, stream);
X		space = ANNOWIDTH - strlen(buffer);
X		if (space > 0) {
X			fprintf(stream, "%*s", space, "");
X		}
X	} else if (prefix) {
X		fputs(prefix, stream);
X		fputs(": ", stream);
X	}
X	errno=save_e;
X}
X#endif
X
X/* We've hit the end of the old volume.  Close it and open the next one */
X/* Values for type:  0: writing  1: reading  2: updating */
Xnew_volume(type)
Xint	type;
X{
X	int	c;
X	char	inbuf[80];
X	char	*p;
X	static FILE *read_file = 0;
X	extern int now_verifying;
X	extern char TTY_NAME[];
X	char *getenv();
X
X	if(!read_file && !f_run_script_at_end)
X		read_file = (archive==0) ? fopen(TTY_NAME, "r") : stdin;
X
X	if(now_verifying)
X		return -1;
X	if(f_verify)
X		verify_volume();
X	if((c=rmtclose(archive))<0)
X		msg_perror("Warning: can't close %s(%d,%d)",ar_file,archive,c);
X
X	volno++;
X tryagain:
X	if (f_run_script_at_end)
X		system(info_script);
X	else for(;;) {
X		fprintf(msg_file,"\007Prepare volume #%d and hit return: ",volno);
X		fflush(msg_file);
X		if(fgets(inbuf,sizeof(inbuf),read_file)==0) {
X 			fprintf(msg_file,"EOF?  What does that mean?");
X			if(cmd_mode!=CMD_EXTRACT && cmd_mode!=CMD_LIST && cmd_mode!=CMD_DIFF)
X				msg("Warning:  Archive is INCOMPLETE!");
X			exit(EX_BADARCH);
X		}
X		if(inbuf[0]=='\n' || inbuf[0]=='y' || inbuf[0]=='Y')
X			break;
X
X		switch(inbuf[0]) {
X		case '?':
X		{
X			fprintf(msg_file,"\
X n [name]   Give a new filename for the next (and subsequent) volume(s)\n\
X q          Abort tar\n\
X !          Spawn a subshell\n\
X ?          Print this list\n");
X		}
X			break;
X
X		case 'q':	/* Quit */
X			fprintf(msg_file,"No new volume; exiting.\n");
X			if(cmd_mode!=CMD_EXTRACT && cmd_mode!=CMD_LIST && cmd_mode!=CMD_DIFF)
X				msg("Warning:  Archive is INCOMPLETE!");
X			exit(EX_BADARCH);
X
X		case 'n':	/* Get new file name */
X		{
X			char *q,*r;
X			static char *old_name;
X
X			for(q= &inbuf[1];*q==' ' || *q=='\t';q++)
X				;
X			for(r=q;*r;r++)
X				if(*r=='\n')
X					*r='\0';
X			if(old_name)
X				free(old_name);
X			old_name=p=(char *)malloc((unsigned)(strlen(q)+2));
X			if(p==0) {
X				msg("Can't allocate memory for name");
X				exit(EX_SYSTEM);
X			}
X			(void) strcpy(p,q);
X			ar_file=p;
X		}
X			break;
X
X		case '!':
X#ifdef MSDOS
X			spawnl(P_WAIT,getenv("COMSPEC"),"-",0);
X#else
X				/* JF this needs work! */
X			switch(fork()) {
X			case -1:
X				msg_perror("can't fork!");
X				break;
X			case 0:
X				p=getenv("SHELL");
X				if(p==0) p="/bin/sh";
X				execlp(p,"-sh","-i",0);
X				msg_perror("can't exec a shell %s",p);
X				_exit(55);
X			default:
X				wait(0);
X				break;
X			}
X#endif
X			break;
X		}
X	}
X
X	if(type==2 || f_verify)
X		archive=rmtopen(ar_file,O_RDWR|O_CREAT,0666);
X	else if(type==1)
X		archive=rmtopen(ar_file,O_RDONLY,0666);
X	else if(type==0)
X		archive=rmtcreat(ar_file,0666);
X	else
X		archive= -1;
X
X	if(archive<0) {
X		msg_perror("can't open %s",ar_file);
X		goto tryagain;
X	}
X#ifdef MSDOS
X	setmode(archive,O_BINARY);
X#endif
X	return 0;
X}
X
X/* this is a useless function that takes a buffer returned by wantbytes
X   and does nothing with it.  If the function called by wantbytes returns
X   an error indicator (non-zero), this function is called for the rest of
X   the file.
X */
Xint
Xno_op(size,data)
Xint size;
Xchar *data;
X{
X	return 0;
X}
X
X/* Some other routine wants SIZE bytes in the archive.  For each chunk of
X   the archive, call FUNC with the size of the chunk, and the address of
X   the chunk it can work with.
X */
Xint
Xwantbytes(size,func)
Xlong size;
Xint (*func)();
X{
X	char *data;
X	long	data_size;
X
X	while(size) {
X		data = findrec()->charptr;
X		if (data == NULL) {	/* Check it... */
X			msg("Unexpected EOF on archive file");
X			return -1;
X		}
X		data_size = endofrecs()->charptr - data;
X		if(data_size>size)
X			data_size=size;
X		if((*func)(data_size,data))
X			func=no_op;
X		userec((union record *)(data + data_size - 1));
X		size-=data_size;
X	}
X	return 0;
X}
END_OF_FILE
if test 30617 -ne `wc -c <'buffer.c'`; then
    echo shar: \"'buffer.c'\" unpacked with wrong size!
fi
# end of 'buffer.c'
fi
if test -f 'getoldopt.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'getoldopt.c'\"
else
echo shar: Extracting \"'getoldopt.c'\" \(2165 characters\)
sed "s/^X//" >'getoldopt.c' <<'END_OF_FILE'
X/* Replacement for getopt() that can be used by tar.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/*
X * Plug-compatible replacement for getopt() for parsing tar-like
X * arguments.  If the first argument begins with "-", it uses getopt;
X * otherwise, it uses the old rules used by tar, dump, and ps.
X *
X * Written 25 August 1985 by John Gilmore (ihnp4!hoptoad!gnu)
X *
X * @(#)getoldopt.c 1.4 2/4/86 - gnu
X */
X
X#include <stdio.h>
X#include "getopt.h"
X
Xint
Xgetoldopt(argc, argv, optstring, long_options, opt_index)
X	int	argc;
X	char	**argv;
X	char	*optstring;
X	struct option *long_options;
X	int 	*opt_index;
X{
X	extern char	*optarg;	/* Points to next arg */
X	extern int	optind;		/* Global argv index */
X	static char	*key;		/* Points to next keyletter */
X	static char	use_getopt;	/* !=0 if argv[1][0] was '-' */
X	extern char	*index();
X	char		c;
X	char		*place;
X
X	optarg = NULL;
X	
X	if (key == NULL) {		/* First time */
X		if (argc < 2) return EOF;
X		key = argv[1];
X		if ((*key == '-') || (*key == '+'))
X			use_getopt++;
X		else
X			optind = 2;
X	}
X
X	if (use_getopt)
X		return getopt_long(argc, argv, optstring, 
X				   long_options, opt_index);
X
X	c = *key++;
X	if (c == '\0') {
X		key--;
X		return EOF;
X	}
X	place = index(optstring, c);
X
X	if (place == NULL || c == ':') {
X		msg("unknown option %c", c);
X		return('?');
X	}
X
X	place++;
X	if (*place == ':') {
X		if (optind < argc) {
X			optarg = argv[optind];
X			optind++;
X		} else {
X			msg("%c argument missing", c);
X			return('?');
X		}
X	}
X
X	return(c);
X}
END_OF_FILE
if test 2165 -ne `wc -c <'getoldopt.c'`; then
    echo shar: \"'getoldopt.c'\" unpacked with wrong size!
fi
# end of 'getoldopt.c'
fi
if test -f 'update.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'update.c'\"
else
echo shar: Extracting \"'update.c'\" \(12751 characters\)
sed "s/^X//" >'update.c' <<'END_OF_FILE'
X/* Update a tar archive.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/* JF implement the 'r' 'u' and 'A' options for tar. */
X/* The 'A' option is my own invention:  It means that the file-names are
X   tar files, and they should simply be appended to the end of the archive.
X   No attempt is made to block the reads from the args; if they're on raw
X   tape or something like that, it'll probably lose. . . */
X
X#include <sys/types.h>
X#include <sys/stat.h>
X#include <stdio.h>
X#include <errno.h>
X
X/* JF these includes are copied from create.c  I'm not sure if they're right
X   or not.  */
X#ifndef V7
X#include <fcntl.h>
X#endif
X
X#ifndef	MSDOS
X#include <pwd.h>
X#include <grp.h>
X#endif
X
X#ifdef USG
X#include <sys/sysmacros.h>	/* major() and minor() defined here */
X#endif
X
X/*
X * V7 doesn't have a #define for this.
X */
X#ifndef O_RDONLY
X#define	O_RDONLY	0
X#endif
X
X/*
X * Most people don't have a #define for this.
X */
X#ifndef	O_BINARY
X#define	O_BINARY	0
X#endif
X
X#define STDIN 0
X#define STDOUT 1
X
X#include "tar.h"
X#include "port.h"
X#include "rmt.h"
X
Xint time_to_start_writing = 0;	/* We've hit the end of the old stuff,
X				   and its time to start writing new stuff
X				   to the tape.  This involves seeking
X				   back one block and re-writing the current
X				   block (which has been changed). */
X
Xchar *output_start;		/* Pointer to where we started to write in
X				   the first block we write out.  This is used
X				   if we can't backspace the output and have
X				   to null out the first part of the block */
X
Xextern void skip_file();
Xextern void skip_extended_headers();
X
Xextern union record *head;
Xextern struct stat hstat;
X
Xstruct name *name_scan();
Xchar	*name_from_list();
X
X/* Implement the 'r' (add files to end of archive), and 'u' (add files to
X   end of archive if they arent there, or are more up to date than the
X   version in the archive.) commands.*/
Xvoid
Xupdate_archive()
X{
X	int	found_end = 0;
X	int	status = 3;
X	int	prev_status;
X	char	*p;
X	struct name *name;
X	extern void dump_file();
X
X	name_gather();
X	if(cmd_mode==CMD_UPDATE)
X		name_expand();
X	open_archive(2);	/* Open for updating */
X
X	do {
X		prev_status=status;
X		status=read_header();
X		switch(status) {
X		case EOF:
X			found_end=1;
X			break;
X
X		case 0:		/* A bad record */
X			userec(head);
X			switch(prev_status) {
X			case 3:
X				msg("This doesn't look like a tar archive.");
X				/* FALL THROUGH */
X			case 2:
X			case 1:
X				msg("Skipping to next header");
X			case 0:
X				break;
X			}
X			break;
X
X			/* A good record */
X		case 1:
X /* printf("File %s\n",head->header.name); */
X			/* head->header.name[NAMSIZ-1]='\0'; */
X			if(cmd_mode==CMD_UPDATE && (name=name_scan(head->header.name))) {
X				/* struct stat hstat; */
X				struct stat nstat;
X				int head_standard;
X
X				decode_header(head,&hstat,&head_standard,0);
X				if(stat(head->header.name,&nstat)<0) {
X					msg_perror("can't stat %s:",head->header.name);
X				} else {
X					if(hstat.st_mtime>=nstat.st_mtime)
X						name->found++;
X				}
X			}
X			userec(head);
X			if (head->header.isextended)
X				skip_extended_headers();
X			skip_file((long)hstat.st_size);
X			break;
X
X		case 2:
X			ar_record=head;
X			found_end = 1;
X			break;
X		}
X	} while(!found_end);
X
X	reset_eof();
X	time_to_start_writing = 1;
X	output_start=ar_record->charptr;
X
X	while(p=name_from_list()) {
X		if(f_confirm && !confirm("add", p))
X			continue;
X		if(cmd_mode==CMD_CAT)
X			append_file(p);
X		else
X			dump_file(p,-1);
X	}
X
X	write_eot();
X	close_archive();
X	names_notfound();
X}
X
X/* Catenate file p to the archive without creating a header for it.  It had
X   better be a tar file or the archive is screwed */
X
Xappend_file(p)
Xchar *p;
X{
X	int	fd;
X	struct stat statbuf;
X	long	bytes_left;
X	union record *start;
X	long	bufsiz,count;
X
X	if(0 != stat(p,&statbuf) || (fd=open(p,O_RDONLY|O_BINARY))<0) {
X		msg_perror("can't open file %s",p);
X		errors++;
X		return;
X	}
X
X	bytes_left = statbuf.st_size;
X
X	while(bytes_left>0) {
X		start=findrec();
X		bufsiz=endofrecs()->charptr - start->charptr;
X		if(bytes_left < bufsiz) {
X			bufsiz = bytes_left;
X			count = bufsiz % RECORDSIZE;
X			if(count)
X				bzero(start->charptr + bytes_left,(int)(RECORDSIZE-count));
X		}
X		count=read(fd,start->charptr,bufsiz);
X		if(count<0) {
X			msg_perror("read error at byte %ld reading %d bytes in file %s",statbuf.st_size-bytes_left,bufsiz,p);
X			exit(EX_ARGSBAD);		/* FOO */
X		}
X		bytes_left-=count;
X		userec(start+(count-1)/RECORDSIZE);
X		if(count!=bufsiz) {
X			msg("%s: file shrunk by %d bytes, yark!",p,bytes_left);
X			abort();
X		}
X	}
X	(void)close(fd);
X}
X
X#ifdef DONTDEF
Xbprint(fp,buf,num)
XFILE *fp;
Xchar *buf;
X{
X	int	c;
X
X	if(num==0 || num==-1)
X		return;
X	fputs(" '",fp);
X	while(num--) {
X		c= *buf++;
X		if(c=='\\') fputs("\\\\",fp);
X		else if(c>=' ' && c<='~')
X			putc(c,fp);
X		else switch(c) {
X		case '\n':
X			fputs("\\n",fp);
X			break;
X		case '\r':
X			fputs("\\r",fp);
X			break;
X		case '\b':
X			fputs("\\b",fp);
X			break;
X		case '\0':
X			/* fputs("\\-",fp); */
X			break;
X		default:
X			fprintf(fp,"\\%03o",c);
X			break;
X		}
X	}
X	fputs("'\n",fp);
X}
X#endif
X
Xint number_of_blocks_read = 0;
X
Xint number_of_new_records = 0;
Xint number_of_records_needed = 0;
X
Xunion record *new_block = 0;
Xunion record *save_block = 0;
X
Xvoid
Xjunk_archive()
X{
X	int	found_stuff = 0;
X	int	status = 3;
X	int	prev_status;
X	struct name *name;
X
X	/* int dummy_head; */
X	int number_of_records_to_skip = 0;
X	int number_of_records_to_keep = 0;
X	int number_of_kept_records_in_block;
X	int sub_status;
X	extern int write_archive_to_stdout;
X
X/* fprintf(stderr,"Junk files\n"); */
X	name_gather();
X	open_archive(2);
X
X	while(!found_stuff) {
X		prev_status=status;
X		status=read_header();
X		switch(status) {
X		case EOF:
X			found_stuff = 1;
X			break;
X
X		case 0:
X			userec(head);
X			switch(prev_status) {
X			case 3:
X				msg("This doesn't look like a tar archive.");
X				/* FALL THROUGH */
X			case 2:
X			case 1:
X				msg("Skipping to next header");
X				/* FALL THROUGH */
X			case 0:
X				break;
X			}
X			break;
X
X		case 1:
X			/* head->header.name[NAMSIZ-1] = '\0'; */
X /* fprintf(stderr,"file %s\n",head->header.name); */
X			if((name=name_scan(head->header.name))==(struct name *)0) {
X				userec(head);
X /* fprintf(stderr,"Skip %ld\n",(long)(hstat.st_size)); */
X 				if (head->header.isextended)
X					skip_extended_headers();
X				skip_file((long)(hstat.st_size));
X				break;
X			}
X			name->found = 1;
X			found_stuff = 2;
X			break;
X
X		case 2:
X			found_stuff = 1;
X			break;
X		}
X	}
X /* fprintf(stderr,"Out of first loop\n"); */
X
X	if(found_stuff!=2) {
X		write_eot();
X		close_archive();
X		names_notfound();
X		return;
X	}
X
X	if(write_archive_to_stdout)
X		write_archive_to_stdout = 0;
X	new_block = (union record *)malloc(blocksize);
X	if(new_block==0) {
X		msg("Can't allocate secondary block of %d bytes",blocksize);
X		exit(EX_SYSTEM);
X	}
X
X		/* Save away records before this one in this block */
X	number_of_new_records=ar_record-ar_block;
X	number_of_records_needed = blocking - number_of_new_records;
X	if(number_of_new_records)
X		bcopy((void *)ar_block,(void *)new_block,(number_of_new_records)*RECORDSIZE);
X
X /* fprintf(stderr,"Saved %d recs, need %d more\n",number_of_new_records,number_of_records_needed); */
X	userec(head);
X	if (head->header.isextended)
X		skip_extended_headers();
X	skip_file((long)(hstat.st_size));
X	found_stuff=0;
X	/* goto flush_file; */
X
X	for(;;) {
X			/* Fill in a block */
X	/* another_file: */
X		if(ar_record==ar_last) {
X /* fprintf(stderr,"New block\n"); */
X			flush_archive();
X			number_of_blocks_read++;
X		}
X		sub_status = read_header();
X /* fprintf(stderr,"Header type %d\n",sub_status); */
X
X		if(sub_status==2 && f_ignorez) {
X			userec(head);
X			continue;
X		}
X		if(sub_status==EOF || sub_status==2) {
X			found_stuff = 1;
X			bzero(new_block[number_of_new_records].charptr,RECORDSIZE*number_of_records_needed);
X			number_of_new_records+=number_of_records_needed;
X			number_of_records_needed = 0;
X			write_block(0);
X			break;
X		}
X
X		if(sub_status==0) {
X			msg("Deleting non-header from archive.");
X			userec(head);
X			continue;
X		}
X
X		/* Found another header.  Yipee! */
X		/* head->header.name[NAMSIZ-1] = '\0'; */
X /* fprintf(stderr,"File %s ",head->header.name); */
X		if(name=name_scan(head->header.name)) {
X			name->found = 1;
X /* fprintf(stderr,"Flush it\n"); */
X		/* flush_file: */
X			/* decode_header(head,&hstat,&dummy_head,0); */
X			userec(head);
X			number_of_records_to_skip=(hstat.st_size+RECORDSIZE-1)/RECORDSIZE;
X /* fprintf(stderr,"Flushing %d recs from %s\n",number_of_records_to_skip,head->header.name); */
X
X			while(ar_last-ar_record<=number_of_records_to_skip) {
X
X /* fprintf(stderr,"Block: %d <= %d  ",ar_last-ar_record,number_of_records_to_skip); */
X				number_of_records_to_skip -= (ar_last - ar_record);
X				flush_archive();
X				number_of_blocks_read++;
X /* fprintf(stderr,"Block %d left\n",number_of_records_to_skip); */
X			}
X			ar_record+=number_of_records_to_skip;
X /* fprintf(stderr,"Final %d\n",number_of_records_to_skip); */
X			number_of_records_to_skip = 0;
X			continue;
X		}
X
X	/* copy_header: */
X		new_block[number_of_new_records]= *head;
X		number_of_new_records++;
X		number_of_records_needed--;
X		number_of_records_to_keep=(hstat.st_size+RECORDSIZE-1)/RECORDSIZE;
X		userec(head);
X		if(number_of_records_needed==0)
X			write_block(1);
X	/* copy_data: */
X		number_of_kept_records_in_block = ar_last - ar_record;
X		if(number_of_kept_records_in_block > number_of_records_to_keep)
X			number_of_kept_records_in_block = number_of_records_to_keep;
X
X /* fprintf(stderr,"Need %d kept_in %d keep %d\n",blocking,number_of_kept_records_in_block,number_of_records_to_keep); */
X
X		while(number_of_records_to_keep) {
X			int n;
X
X			if(ar_record==ar_last) {
X /* fprintf(stderr,"Flush. . .\n"); */
X				fl_read();
X				number_of_blocks_read++;
X				ar_record=ar_block;
X				number_of_kept_records_in_block = blocking;
X				if(number_of_kept_records_in_block > number_of_records_to_keep)
X					number_of_kept_records_in_block = number_of_records_to_keep;
X			}
X			n = number_of_kept_records_in_block;
X			if(n>number_of_records_needed)
X				n = number_of_records_needed;
X
X /* fprintf(stderr,"Copying %d\n",n); */
X			bcopy((void *)ar_record, (void *)(new_block+number_of_new_records), n*RECORDSIZE);
X			number_of_new_records           += n;
X			number_of_records_needed        -= n;
X			ar_record                       += n;
X			number_of_records_to_keep       -= n;
X			number_of_kept_records_in_block -= n;
X /* fprintf(stderr,"Now new %d  need %d  keep %d  keep_in %d rec %d/%d\n", 
X number_of_new_records,number_of_records_needed,number_of_records_to_keep,
X number_of_kept_records_in_block,ar_record-ar_block,ar_last-ar_block); */
X 
X			if(number_of_records_needed == 0) {
X				write_block(1);
X			}
X		}
X	}
X
X	write_eot();
X	close_archive();
X	names_notfound();
X}
X
Xwrite_block(f)
X{
X /* fprintf(stderr,"Write block\n"); */
X	/* We've filled out a block.  Write it out. */
X
X	/* Backspace back to where we started. . . */
X	if(archive!=STDIN)
X		(void)move_arch(-(number_of_blocks_read+1));
X
X	save_block = ar_block;
X	ar_block = new_block;
X
X	if(archive==STDIN)
X		archive=STDOUT;
X	fl_write();
X
X	if(archive==STDOUT)
X		archive=STDIN;
X	ar_block = save_block;
X
X	if(f) {
X		/* Move the tape head back to where we were */
X		if(archive!=STDIN)
X			(void)move_arch(number_of_blocks_read);
X		number_of_blocks_read--;
X	}
X
X	number_of_records_needed = blocking;
X	number_of_new_records = 0;
X}
X
X/* Move archive descriptor by n blocks worth.  If n is positive we move
X   forward, else we move negative.   If its a tape, MTIOCTOP had better
X   work.  If its something else, we try to seek on it.  If we can't
X   seek, we lose! */
Xmove_arch(n)
X{
X	long cur;
X	extern int errno;
X
X#ifdef MTIOCTOP
X	struct mtop t;
X	int er;
X
X	if(n>0) {
X		t.mt_op = MTFSR;
X		t.mt_count = n;
X	} else {
X		t.mt_op = MTBSR;
X		t.mt_count = -n;
X	}
X	if((er=rmtioctl(archive,MTIOCTOP,&t))>=0)
X		return 1;
X	if(errno==EIO && (er=rmtioctl(archive,MTIOCTOP,&t))>=0)
X		return 1;
X#endif
X
X	cur=rmtlseek(archive,0L,1);
X	cur+=blocksize*n;
X
X /* fprintf(stderr,"Fore to %x\n",cur); */
X	if(rmtlseek(archive,cur,0)!=cur) {
X		/* Lseek failed.  Try a different method */
X		msg("Couldn't re-position archive file.");
X		exit(EX_BADARCH);
X	}
X	return 3;
X}
X
END_OF_FILE
if test 12751 -ne `wc -c <'update.c'`; then
    echo shar: \"'update.c'\" unpacked with wrong size!
fi
# end of 'update.c'
fi
if test -f 'gnu.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'gnu.c'\"
else
echo shar: Extracting \"'gnu.c'\" \(12068 characters\)
sed "s/^X//" >'gnu.c' <<'END_OF_FILE'
X#include <stdio.h>
X#include <sys/types.h>
X#include <sys/stat.h>
X#include <ctype.h>
X#include <errno.h>
X
X#ifdef BSD42
X#include <sys/dir.h>
X#else
X#ifdef __MSDOS__
X#include "msd_dir.h"
X#else
X#ifdef USG
X#ifdef NDIR
X#include <ndir.h>
X#else
X#include <dirent.h>
X#endif
X#ifndef DIRECT
X#define direct dirent
X#endif
X#define DP_NAMELEN(x) strlen((x)->d_name)
X#else
X/*
X * FIXME: On other systems there is no standard place for the header file
X * for the portable directory access routines.  Change the #include line
X * below to bring it in from wherever it is.
X */
X#include "ndir.h"
X#endif
X#endif
X#endif
X
X#ifndef DP_NAMELEN
X#define DP_NAMELEN(x)	(x)->d_namlen
X#endif
X
X#ifndef MAXPATHLEN
X#define MAXPATHLEN 1024
X#endif
X
X/*
X * If there are no symbolic links, there is no lstat().  Use stat().
X */
X#ifndef S_IFLNK
X#define lstat stat
X#endif
X
X#ifdef __STDC__
X#define VOIDSTAR void *
X#else
X#define VOIDSTAR char *
X#endif
Xextern VOIDSTAR ck_malloc();
Xextern VOIDSTAR ck_realloc();
X
X#ifndef S_IFLNK
X#define lstat stat
X#endif
X
Xextern VOIDSTAR malloc();
X
X#include "tar.h"
X
Xextern time_t new_time;
Xextern FILE *msg_file;
X
Xextern VOIDSTAR init_buffer();
Xextern char *get_buffer();
Xextern void add_buffer();
Xextern void flush_buffer();
X
Xextern char *new_name();
X
Xstatic void add_dir_name();
X
Xstruct dirname {
X	struct dirname *next;
X	char *name;
X	char *dir_text;
X	int dev;
X	int ino;
X	int allnew;
X};
Xstatic struct dirname *dir_list;
Xstatic time_t this_time;
X
Xvoid
Xadd_dir(name,dev,ino,text)
Xchar *name;
Xchar *text;
X{
X	struct dirname *dp;
X
X	dp=(struct dirname *)malloc(sizeof(struct dirname));
X	if(!dp)
X		abort();
X	dp->next=dir_list;
X	dir_list=dp;
X	dp->dev=dev;
X	dp->ino=ino;
X	dp->name=malloc(strlen(name)+1);
X	strcpy(dp->name,name);
X	dp->dir_text=text;
X	dp->allnew=0;
X}
X
Xvoid
Xread_dir_file()
X{
X	int dev;
X	int ino;
X	char *strp;
X	FILE *fp;
X	char buf[512];
X	extern int errno;
X	static char path[MAXPATHLEN];
X
X	time(&this_time);
X	if(gnu_dumpfile[0]!='/') {
X#if defined(MSDOS) || defined(USG)
X			int getcwd();
X
X			if(!getcwd(path,MAXPATHLEN))
X				msg("Couldn't get current directory.");
X				exit(EX_SYSTEM);
X#else
X			char *getwd();
X
X			if(!getwd(path)) {
X				msg("Couldn't get current directory: %s",path);
X				exit(EX_SYSTEM);
X			}
X#endif
X		/* If this doesn't fit, we're in serious trouble */
X		strcat(path,"/");
X		strcat(path,gnu_dumpfile);
X		gnu_dumpfile=path;
X	}
X	fp=fopen(gnu_dumpfile,"r");
X	if(fp==0 && errno!=ENOENT) {
X		msg_perror("Can't open %s",gnu_dumpfile);
X		return;
X	}
X	if(!fp)
X		return;
X	fgets(buf,sizeof(buf),fp);
X	if(!f_new_files) {
X		f_new_files++;
X		new_time=atol(buf);
X	}
X	while(fgets(buf,sizeof(buf),fp)) {
X		strp= &buf[strlen(buf)];
X		if(strp[-1]=='\n')
X			strp[-1]='\0';
X		strp=buf;
X		dev=atol(strp);
X		while(isdigit(*strp))
X			strp++;
X		ino=atol(strp);
X		while(isspace(*strp))
X			strp++;
X		while(isdigit(*strp))
X			strp++;
X		strp++;
X		add_dir(un_quote_string(strp),dev,ino,(char *)0);
X	}
X	fclose(fp);
X}
X
Xvoid
Xwrite_dir_file()
X{
X	FILE *fp;
X	struct dirname *dp;
X	char *str;
X	extern char *quote_copy_string();
X
X	fp=fopen(gnu_dumpfile,"w");
X	if(fp==0) {
X		msg_perror("Can't write to %s",gnu_dumpfile);
X		return;
X	}
X	fprintf(fp,"%lu\n",this_time);
X	for(dp=dir_list;dp;dp=dp->next) {
X		if(!dp->dir_text)
X			continue;
X		str=quote_copy_string(dp->name);
X		if(str) {
X			fprintf(fp,"%u %u %s\n",dp->dev,dp->ino,str);
X			free(str);
X		} else
X			fprintf(fp,"%u %u %s\n",dp->dev,dp->ino,dp->name);
X	}
X	fclose(fp);
X}
X
Xstruct dirname *
Xget_dir(name)
Xchar *name;
X{
X	struct dirname *dp;
X
X	for(dp=dir_list;dp;dp=dp->next) {
X		if(!strcmp(dp->name,name))
X			return dp;
X	}
X	return 0;
X}
X
X
X/* Collect all the names from argv[] (or whatever), then expand them into
X   a directory tree, and put all the directories at the beginning. */
Xcollect_and_sort_names()
X{
X	struct name *n,*n_next;
X	int num_names;
X	struct stat statbuf;
X	int name_cmp();
X	char *merge_sort();
X
X	name_gather();
X
X	if(gnu_dumpfile)
X		read_dir_file();
X	if(!namelist) addname(".");
X	for(n=namelist;n;n=n_next) {
X		n_next=n->next;
X		if(n->found || n->dir_contents)
X			continue;
X		if(n->regexp)		/* FIXME just skip regexps for now */
X			continue;
X		if(n->change_dir)
X			if(chdir(n->change_dir)<0) {
X				msg_perror("can't chdir to %s",n->change_dir);
X				continue;
X			}
X
X#ifdef AIX
X		if (statx (n->name, &statbuf, STATSIZE, STX_HIDDEN|STX_LINK))
X#else
X		if(lstat(n->name,&statbuf)<0) {
X#endif /* AIX */
X			msg_perror("can't stat %s",n->name);
X			continue;
X		}
X		if((statbuf.st_mode&S_IFMT)==S_IFDIR) {
X			n->found++;
X			add_dir_name(n->name,statbuf.st_dev);
X		}
X	}
X
X	num_names=0;
X	for(n=namelist;n;n=n->next)
X		num_names++;
X	namelist=(struct name *)merge_sort((VOIDSTAR)namelist,num_names,(char *)(&(namelist->next))-(char *)namelist,name_cmp);
X
X	for(n=namelist;n;n=n->next) {
X		n->found=0;
X	}
X	/* if(gnu_dumpfile)
X		write_dir_file(gnu_dumpfile); */
X}
X
Xint
Xname_cmp(n1,n2)
Xstruct name *n1,*n2;
X{
X	if(n1->found) {
X		if(n2->found)
X			return strcmp(n1->name,n2->name);
X		else
X			return -1;
X	} else if(n2->found)
X		return 1;
X	else
X		return strcmp(n1->name,n2->name);
X}
X
Xint
Xdirent_cmp(p1,p2)
Xchar **p1,**p2;
X{
X	char *frst,*scnd;
X
X	frst= (*p1)+1;
X	scnd= (*p2)+1;
X
X	return strcmp(frst,scnd);
X}
X
Xchar *
Xget_dir_contents(p,device)
Xchar *p;
Xint device;
X{
X	DIR *dirp;
X	register struct direct *d;
X	char *new_buf;
X	char *namebuf;
X	int bufsiz;
X	int len;
X	VOIDSTAR the_buffer;
X	char *buf;
X	int n_strs;
X	int n_size;
X	char *p_buf;
X	char **vec,**p_vec;
X
X	extern int errno;
X
X	errno=0;
X	dirp=opendir(p);
X	bufsiz=strlen(p)+NAMSIZ;
X	namebuf=ck_malloc(bufsiz+2);
X	if(!dirp) {
X		if(errno)
X			msg_perror("can't open directory %s",p);
X		else
X			msg("error opening directory %s",p);
X		new_buf="\0\0\0\0";
X	} else {
X		struct dirname *dp;
X		int all_children;
X
X		dp=get_dir(p);
X		all_children= dp ? dp->allnew : 0;
X		(void) strcpy(namebuf,p);
X		if(p[strlen(p)-1]!='/')
X			(void) strcat(namebuf,"/");
X		len=strlen(namebuf);
X
X		the_buffer=init_buffer();
X		while(d=readdir(dirp)) {
X			struct stat hs;
X
X			/* Skip . and .. */
X			if(is_dot_or_dotdot(d->d_name))
X				continue;
X			if(DP_NAMELEN(d) + len >=bufsiz) {
X				bufsiz+=NAMSIZ;
X				namebuf=ck_realloc(namebuf,bufsiz+2);
X			}
X			(void) strcpy(namebuf+len,d->d_name);
X#ifdef AIX
X			if (0 != f_follow_links?
X			    statx(namebuf, &hs, STATSIZE, STX_HIDDEN):
X			    statx(namebuf, &hs, STATSIZE, STX_HIDDEN|STX_LINK))
X#else
X			if (0 != f_follow_links? stat(namebuf, &hs): lstat(namebuf, &hs))
X#endif
X			{
X				msg_perror("can't stat %s",namebuf);
X				continue;
X			}
X			if(   (f_local_filesys && device!=hs.st_dev)
X			   || (f_exclude && check_exclude(namebuf)))
X				add_buffer(the_buffer,"N",1);
X#ifdef AIX
X			else if (S_ISHIDDEN (hs.st_mode)) {
X				add_buffer (the_buffer, "D", 1);
X				strcat (d->d_name, "A");
X				d->d_namlen++;
X			}	
X#endif /* AIX */
X			else if((hs.st_mode&S_IFMT)==S_IFDIR) {
X				if(dp=get_dir(namebuf)) {
X					if(   dp->dev!=hs.st_dev
X 					   || dp->ino!=hs.st_ino) {
X					   	if(f_verbose)
X							msg("directory %s has been renamed.",namebuf);
X						dp->allnew=1;
X						dp->dev=hs.st_dev;
X						dp->ino=hs.st_ino;
X					}
X					dp->dir_text="";
X				} else {
X					if(f_verbose)
X						msg("Directory %s is new",namebuf);
X					add_dir(namebuf,hs.st_dev,hs.st_ino,"");
X					dp=get_dir(namebuf);
X					dp->allnew=1;
X				}
X				if(all_children)
X					dp->allnew=1;
X
X				add_buffer(the_buffer,"D",1);
X			} else if(   !all_children
X   				&& f_new_files
X 				&& new_time>hs.st_mtime
X				&& (   f_new_files>1
X 				    || new_time>hs.st_ctime))
X				add_buffer(the_buffer,"N",1);
X			else
X				add_buffer(the_buffer,"Y",1);
X			add_buffer(the_buffer,d->d_name,(int)(DP_NAMELEN(d)+1));
X		}
X		add_buffer(the_buffer,"\000\000",2);
X		closedir(dirp);
X
X		/* Well, we've read in the contents of the dir, now sort them */
X		buf=get_buffer(the_buffer);
X		if(buf[0]=='\0') {
X			flush_buffer(the_buffer);
X			new_buf="\0\0\0\0";
X		} else {
X			n_strs=0;
X			for(p_buf=buf;*p_buf;) {
X				int tmp;
X
X				tmp=strlen(p_buf)+1;
X				n_strs++;
X				p_buf+=tmp;
X			}
X			vec=(char **)malloc(sizeof(char *)*(n_strs+1));
X			for(p_vec=vec,p_buf=buf;*p_buf;p_buf+=strlen(p_buf)+1)
X				*p_vec++= p_buf;
X			*p_vec= 0;
X			qsort((VOIDSTAR)vec,n_strs,sizeof(char *),dirent_cmp);
X			new_buf=(char *)malloc(p_buf-buf+2);
X			for(p_vec=vec,p_buf=new_buf;*p_vec;p_vec++) {
X				char *p_tmp;
X
X				for(p_tmp= *p_vec;*p_buf++= *p_tmp++;)
X					;
X			}
X			*p_buf++='\0';
X			free(vec);
X			flush_buffer(the_buffer);
X		}
X	}
X	free(namebuf);
X	return new_buf;
X}
X
X/* p is a directory.  Add all the files in P to the namelist.  If any of the
X   files is a directory, recurse on the subdirectory. . . */
Xstatic void
Xadd_dir_name(p,device)
Xchar *p;
Xint device;
X{
X	char *new_buf;
X	char *p_buf;
X
X	char *namebuf;
X	int buflen;
X	register int len;
X	int sublen;
X
X	VOIDSTAR the_buffer;
X
X	char *buf;
X	char **vec,**p_vec;
X	int n_strs,n_size;
X
X	struct name *n;
X
X	int dirent_cmp();
X
X	new_buf=get_dir_contents(p,device);
X
X	for(n=namelist;n;n=n->next) {
X		if(!strcmp(n->name,p)) {
X			n->dir_contents = new_buf;
X			break;
X		}
X	}
X
X	len=strlen(p);
X	buflen= NAMSIZ<=len ? len + NAMSIZ : NAMSIZ;
X	namebuf= ck_malloc(buflen+1);
X
X	(void)strcpy(namebuf,p);
X	if(namebuf[len-1]!='/') {
X		namebuf[len++]='/';
X		namebuf[len]='\0';
X	}
X	for(p_buf=new_buf;*p_buf;p_buf+=sublen+1) {
X		sublen=strlen(p_buf);
X		if(*p_buf=='D') {
X			if(len+sublen>=buflen) {
X				buflen+=NAMSIZ;
X				namebuf= ck_realloc(namebuf,buflen+1);
X			}
X			(void)strcpy(namebuf+len,p_buf+1);
X			addname(namebuf);
X			add_dir_name(namebuf,device);
X		}
X	}
X	free(namebuf);
X}
X
X/* Returns non-zero if p is . or ..   This could be a macro for speed. */
Xis_dot_or_dotdot(p)
Xchar *p;
X{
X	return (p[0]=='.' && (p[1]=='\0' || (p[1]=='.' && p[2]=='\0')));
X}
X
X
X
X
X
X
Xgnu_restore(skipcrud)
Xint skipcrud;
X{
X	char *current_dir;
X/*	int current_dir_length; */
X
X	char *archive_dir;
X/*	int archive_dir_length; */
X	VOIDSTAR the_buffer;
X	char	*p;
X	DIR	*dirp;
X	struct direct *d;
X	char *cur,*arc;
X	extern struct stat hstat;		/* Stat struct corresponding */
X	long size,copied;
X	char *from,*to;
X	extern union record *head;
X
X	dirp=opendir(skipcrud+head->header.name);
X
X	if(!dirp) {
X			/* The directory doesn't exist now.  It'll be created.
X			   In any case, we don't have to delete any files out
X			   of it */
X		skip_file((long)hstat.st_size);
X		return;
X	}
X
X	the_buffer=init_buffer();
X	while(d=readdir(dirp)) {
X		if(is_dot_or_dotdot(d->d_name))
X			continue;
X
X		add_buffer(the_buffer,d->d_name,(int)(DP_NAMELEN(d)+1));
X	}
X	closedir(dirp);
X	add_buffer(the_buffer,"",1);
X
X	current_dir=get_buffer(the_buffer);
X	archive_dir=(char *)malloc(hstat.st_size);
X	if(archive_dir==0) {
X		msg("Can't allocate %d bytes for restore",hstat.st_size);
X		skip_file((long)hstat.st_size);
X		return;
X	}
X	to=archive_dir;
X	for(size=hstat.st_size;size>0;size-=copied) {
X		from=findrec()->charptr;
X		if(!from) {
X			msg("Unexpected EOF in archive\n");
X			break;
X		}
X		copied=endofrecs()->charptr - from;
X		if(copied>size)
X			copied=size;
X		bcopy((VOIDSTAR)from,(VOIDSTAR)to,(int)copied);
X		to+=copied;
X		userec((union record *)(from+copied-1));
X	}
X
X	for(cur=current_dir;*cur;cur+=strlen(cur)+1) {
X		for(arc=archive_dir;*arc;arc+=strlen(arc)+1) {
X			arc++;
X			if(!strcmp(arc,cur))
X				break;
X		}
X		if(*arc=='\0') {
X			p=new_name(skipcrud+head->header.name,cur);
X			if(f_confirm && !confirm("delete",p)) {
X				free(p);
X				continue;
X			}
X			if(f_verbose)
X				fprintf(msg_file,"%s: deleting %s\n",tar,p);
X			if(recursively_delete(p)) {
X				msg("%s: Error while deleting %s\n",tar,p);
X			}
X			free(p);
X		}
X
X	}
X	flush_buffer(the_buffer);
X	free(archive_dir);
X}
X
Xrecursively_delete(path)
Xchar *path;
X{
X	struct stat sbuf;
X	DIR *dirp;
X	struct direct *dp;
X	char *path_buf;
X	/* int path_len; */
X
X
X	if(lstat(path,&sbuf)<0)
X		return 1;
X	if((sbuf.st_mode &S_IFMT)==S_IFDIR) {
X
X		/* path_len=strlen(path); */
X		dirp=opendir(path);
X		if(dirp==0)
X			return 1;
X		while(dp=readdir(dirp)) {
X			if(is_dot_or_dotdot(dp->d_name))
X				continue;
X			path_buf=new_name(path,dp->d_name);
X			if(recursively_delete(path_buf)) {
X				free(path_buf);
X				closedir(dirp);
X				return 1;
X			}
X			free(path_buf);
X		}
X		closedir(dirp);
X
X		if(rmdir(path)<0)
X			return 1;
X		return 0;
X	}
X	if(unlink(path)<0)
X		return 1;
X	return 0;
X}
X
END_OF_FILE
if test 12068 -ne `wc -c <'gnu.c'`; then
    echo shar: \"'gnu.c'\" unpacked with wrong size!
fi
# end of 'gnu.c'
fi
if test -f 'mangle.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'mangle.c'\"
else
echo shar: Extracting \"'mangle.c'\" \(5054 characters\)
sed "s/^X//" >'mangle.c' <<'END_OF_FILE'
X#include <sys/types.h>
X#include <sys/stat.h>
X#include "tar.h"
X
X#ifdef __STDC__
X#define VOIDSTAR void *
X#else
X#define VOIDSTAR char *
X#endif
Xextern VOIDSTAR ck_malloc();
Xextern VOIDSTAR init_buffer();
Xextern char *quote_copy_string();
Xextern char *get_buffer();
Xextern char *index();
X
Xextern union record *start_header();
X
Xextern struct stat hstat;		/* Stat struct corresponding */
X
Xstruct mangled {
X	struct mangled *next;
X	int type;
X	char mangled[NAMSIZ];
X	char *linked_to;
X	char normal[1];
X};
X
X
X/* Should use a hash table, etc. .  */
Xstruct mangled *first_mangle;
Xint mangled_num = 0;
X
Xchar *
Xfind_mangled (name)
Xchar *name;
X{
X	struct mangled *munge;
X
X	for(munge=first_mangle;munge;munge=munge->next)
X		if(!strcmp(name,munge->normal))
X			return munge->mangled;
X	return 0;
X}
X
X
X#ifdef S_IFLNK
Xvoid add_symlink_mangle(symlink, linkto, buffer)
Xchar *symlink;
Xchar *linkto;
Xchar *buffer;
X{
X	struct mangled *munge,*kludge;
X
X	munge=(struct mangled *)ck_malloc(sizeof(struct mangled)+strlen(symlink)+strlen(linkto)+2);
X	if(!first_mangle)
X		first_mangle=munge;
X	else {
X		for(kludge=first_mangle;kludge->next;kludge=kludge->next)
X			;
X		kludge->next=munge;
X	}
X	munge->type=1;
X	munge->next=0;
X	strcpy(munge->normal,symlink);
X	munge->linked_to=munge->normal+strlen(symlink)+1;
X	strcpy(munge->linked_to,linkto);
X	sprintf(munge->mangled,"@@MaNgLeD.%d",mangled_num++);
X	strncpy(buffer,munge->mangled,NAMSIZ);
X}
X#endif
X
Xvoid
Xadd_mangle (name, buffer)
Xchar *name;
Xchar *buffer;
X{
X	struct mangled *munge,*kludge;
X
X	munge=(struct mangled *)ck_malloc(sizeof(struct mangled)+strlen(name));
X	if(!first_mangle)
X		first_mangle=munge;
X	else {
X		for(kludge=first_mangle;kludge->next;kludge=kludge->next)
X			;
X		kludge->next=munge;
X	}
X	munge->next=0;
X	munge->type=0;
X	strcpy(munge->normal,name);
X	sprintf(munge->mangled,"@@MaNgLeD.%d",mangled_num++);
X	strncpy(buffer,munge->mangled,NAMSIZ);
X}
X
Xvoid
Xwrite_mangled()
X{
X	struct mangled *munge;
X	struct stat hstat;
X	union record *header;
X	char *ptr1,*ptr2;
X	VOIDSTAR the_buffer;
X	int size;
X	int bufsize;
X
X	if(!first_mangle)
X		return;
X	the_buffer=init_buffer();
X	for(munge=first_mangle,size=0;munge;munge=munge->next) {
X		ptr1=quote_copy_string(munge->normal);
X		if(!ptr1)
X			ptr1=munge->normal;
X		if(munge->type) {
X			add_buffer(the_buffer,"Symlink ",8);
X			add_buffer(the_buffer,ptr1,strlen(ptr1));
X			add_buffer(the_buffer," to ",4);
X			
X			if(ptr2=quote_copy_string(munge->linked_to)) {
X				add_buffer(the_buffer,ptr2,strlen(ptr2));
X				free(ptr2);
X			} else
X				add_buffer(the_buffer,munge->linked_to,strlen(munge->linked_to));
X		} else {
X			add_buffer(the_buffer,"Rename ",7);
X			add_buffer(the_buffer,munge->mangled,strlen(munge->mangled));
X			add_buffer(the_buffer," to ",4);
X			add_buffer(the_buffer,ptr1,strlen(ptr1));
X		}
X		add_buffer(the_buffer,"\n",1);
X		if(ptr1!=munge->normal)
X			free(ptr1);
X	}
X
X	bzero(&hstat,sizeof(struct stat));
X	hstat.st_atime=hstat.st_mtime=hstat.st_ctime=time(0);
X	ptr1=get_buffer(the_buffer);
X	hstat.st_size=strlen(ptr1);
X
X	header=start_header("././@MaNgLeD_NaMeS",&hstat);
X	header->header.linkflag=LF_NAMES;
X	finish_header(header);
X	size=hstat.st_size;
X	header=findrec();
X	bufsize = endofrecs()->charptr - header->charptr;
X
X	while(bufsize<size) {
X		bcopy(ptr1,header->charptr,bufsize);
X		ptr1+=bufsize;
X		size-=bufsize;
X		userec(header+(bufsize-1)/RECORDSIZE);
X		header=findrec();
X		bufsize = endofrecs()->charptr - header->charptr;
X	}
X	bcopy(ptr1,header->charptr,size);
X	bzero(header->charptr+size,bufsize-size);
X	userec(header+(size-1)/RECORDSIZE);
X}
X
Xvoid
Xextract_mangle(head)
Xunion record *head;
X{
X	char *buf;
X	char *fromtape;
X	char *to;
X	char *ptr,*ptrend;
X	char *nam1,*nam1end;
X	int size;
X	int copied;
X
X	size=hstat.st_size;
X	buf=to=ck_malloc(size+1);
X	buf[size]='\0';
X	while(size>0) {
X		fromtape=findrec()->charptr;
X		if(fromtape==0) {
X			msg("Unexpected EOF in mangled names!");
X			return;
X		}
X		copied=endofrecs()->charptr-fromtape;
X		if(copied>size)
X			copied=size;
X		bcopy(fromtape,to,copied);
X		to+=copied;
X		size-=copied;
X		userec((union record *)(fromtape+copied-1));
X	}
X	for(ptr=buf;*ptr;ptr=ptrend) {
X		ptrend=index(ptr,'\n');
X		*ptrend++='\0';
X
X		if(!strncmp(ptr,"Rename ",7)) {
X			nam1=ptr+7;
X			nam1end=index(nam1,' ');
X			while(strncmp(nam1end," to ",4)) {
X				nam1end++;
X				nam1end=index(nam1end,' ');
X			}
X			*nam1end='\0';
X			if(ptrend[-2]=='/')
X				ptrend[-2]='\0';
X			un_quote_string(nam1end+4);
X			if(rename(nam1,nam1end+4))
X				msg_perror("Can't rename %s to %s",nam1,nam1end+4);
X			else if(f_verbose)
X				msg("Renamed %s to %s",nam1,nam1end+4);
X		}
X#ifdef S_IFLNK
X		else if(!strncmp(ptr,"Symlink ",8)) {
X			nam1=ptr+8;
X			nam1end=index(nam1,' ');
X			while(strncmp(nam1end," to ",4)) {
X				nam1end++;
X				nam1end=index(nam1end,' ');
X			}
X			un_quote_string(nam1);
X			un_quote_string(nam1end+4);
X			if(symlink(nam1,nam1end+4) && (unlink(nam1end+4) || symlink(nam1,nam1end+4)))
X				msg_perror("Can't symlink %s to %s",nam1,nam1end+4);
X			else if(f_verbose)
X				msg("Symlinkd %s to %s",nam1,nam1end+4);
X		}
X#endif
X		else
X			msg("Unknown demangling command %s",ptr);
X	}
X}
END_OF_FILE
if test 5054 -ne `wc -c <'mangle.c'`; then
    echo shar: \"'mangle.c'\" unpacked with wrong size!
fi
# end of 'mangle.c'
fi
if test -f 'version.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'version.c'\"
else
echo shar: Extracting \"'version.c'\" \(809 characters\)
sed "s/^X//" >'version.c' <<'END_OF_FILE'
X/* Version info for tar.
X   Copyright (C) 1989, Free Software Foundation.
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X   
Xchar version_string[] = "GNU tar version 1.10";
END_OF_FILE
if test 809 -ne `wc -c <'version.c'`; then
    echo shar: \"'version.c'\" unpacked with wrong size!
fi
# end of 'version.c'
fi
if test -f 'list.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'list.c'\"
else
echo shar: Extracting \"'list.c'\" \(16614 characters\)
sed "s/^X//" >'list.c' <<'END_OF_FILE'
X/* List a tar archive.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/*
X * List a tar archive.
X *
X * Also includes support routines for reading a tar archive.
X *
X * this version written 26 Aug 1985 by John Gilmore (ihnp4!hoptoad!gnu).
X *
X * @(#)list.c 1.31 11/5/87 - gnu
X */
X#include <stdio.h>
X#include <ctype.h>
X#include <sys/types.h>
X#include <sys/stat.h>
X#ifndef	MSDOS
X#include <sys/file.h>
X#endif	/* MSDOS */
X
X#ifdef USG
X#include <sys/sysmacros.h>	/* major() and minor() defined here */
X#endif
X
Xchar *ctime();				/* From libc.a */
X
X#define	isodigit(c)	( ((c) >= '0') && ((c) <= '7') )
X
X#include "tar.h"
X#include "port.h"
X
Xextern FILE *msg_file;
X
Xlong from_oct();			/* Decode octal number */
Xvoid demode();				/* Print file mode */
X
Xunion record *head;			/* Points to current archive header */
Xstruct stat hstat;			/* Stat struct corresponding */
Xint head_standard;			/* Tape header is in ANSI format */
X
Xvoid print_header();
Xvoid skip_file();
Xvoid skip_extended_headers();
X
Xextern char *quote_copy_string();
X
X
X/*
X * Main loop for reading an archive.
X */
Xvoid
Xread_and(do_something)
X	void (*do_something)();
X{
X	int status = 3;			/* Initial status at start of archive */
X	int prev_status;
X	extern time_t new_time;
X	char save_linkflag;
X	
X	name_gather();			/* Gather all the names */
X	open_archive(1);		/* Open for reading */
X
X	for(;;) {
X		prev_status = status;
X		status = read_header();
X		switch (status) {
X
X		case 1:			/* Valid header */
X			/* We should decode next field (mode) first... */
X			/* Ensure incoming names are null terminated. */
X			head->header.name[NAMSIZ-1] = '\0';
X
X			if (   !name_match(head->header.name)
X 			    || (f_new_files && hstat.st_mtime<new_time)
X 			    || (f_exclude && check_exclude(head->header.name))) {
X
X				int isextended = 0;
X
X				if(   head->header.linkflag==LF_VOLHDR
X 				   || head->header.linkflag==LF_MULTIVOL
X				   || head->header.linkflag==LF_NAMES) {
X					(*do_something)();
X					continue;
X				}
X				/* Skip past it in the archive */
X				if (head->header.isextended)
X					isextended = 1;
X				save_linkflag = head->header.linkflag;
X				userec(head);
X				if (isextended) {
X/*					register union record *exhdr;
X
X					for (;;) {
X					    exhdr = findrec();
X					    if (!exhdr->ext_hdr.isextended) {
X					    	userec(exhdr);
X					    	break;
X					    }
X					}
X					userec(exhdr);*/
X					skip_extended_headers();
X				}
X				/* Skip to the next header on the archive */
X				if(save_linkflag != LF_DIR)
X					skip_file((long)hstat.st_size);
X				continue;
X
X			}
X
X			(*do_something)();
X			continue;
X
X			/*
X			 * If the previous header was good, tell them
X			 * that we are skipping bad ones.
X			 */
X		case 0:			/* Invalid header */
X			userec(head);
X			switch (prev_status) {
X			case 3:		/* Error on first record */
X				msg("Hmm, this doesn't look like a tar archive.");
X				/* FALL THRU */
X			case 2:		/* Error after record of zeroes */
X			case 1:		/* Error after header rec */
X				msg("Skipping to next file header...");
X			case 0:		/* Error after error */
X				break;
X			}
X			continue;
X
X		case 2:			/* Record of zeroes */
X			userec(head);
X			status = prev_status;	/* If error after 0's */
X			if (f_ignorez)	
X				continue;
X			/* FALL THRU */
X		case EOF:		/* End of archive */
X			break;
X		}
X		break;
X	};
X
X	close_archive();
X	names_notfound();		/* Print names not found */
X}		
X
X
X/*
X * Print a header record, based on tar options.
X */
Xvoid
Xlist_archive()
X{
X	extern char *save_name;
X	int	isextended = 0; /* Flag to remember if head is extended */
X	
X	/* Save the record */
X	saverec(&head);
X
X	/* Print the header record */
X	if (f_verbose) {
X		if (f_verbose > 1)
X			decode_header(head, &hstat, &head_standard, 0);
X		print_header();
X	}
X
X	if(f_gnudump && head->header.linkflag==LF_DUMPDIR) {
X		size_t	size, written, check;
X		char	*data;
X		extern int errno;
X		extern long save_totsize;
X		extern long save_sizeleft;
X
X		userec(head);
X		if(f_multivol) {
X			save_name = head->header.name;
X			save_totsize=hstat.st_size;
X		}
X		for(size = hstat.st_size;size>0;size-=written) {
X			if(f_multivol)
X				save_sizeleft=size;
X			data = findrec()->charptr;
X			if(data==NULL) {
X				msg("EOF in archive file?");
X				break;
X			}
X			written = endofrecs()->charptr - data;
X			if(written>size)
X				written=size;
X			errno=0;
X			check=fwrite(data,sizeof(char), written, msg_file);
X			userec((union record *)(data+written - 1));
X			if(check!=written) {
X				msg_perror("only wrote %ld of %ld bytes to file %s",check, written,head->header.name);
X				skip_file((long)(size)-written);
X				break;
X			}
X		}
X		if(f_multivol)
X			save_name = 0;
X		saverec((union record **) 0);	/* Unsave it */
X		fputc('\n',msg_file);
X		fflush(msg_file);
X		return;
X
X	}
X	saverec((union record **) 0);	/* Unsave it */
X	/* Check to see if we have an extended header to skip over also */
X	if (head->header.isextended) 
X		isextended = 1;
X		
X	/* Skip past the header in the archive */
X	userec(head);
X
X	/*
X 	 * If we needed to skip any extended headers, do so now, by
X 	 * reading extended headers and skipping past them in the 
X	 * archive.
X	 */
X	if (isextended) {
X/*		register union record *exhdr;
X
X		for (;;) {
X			exhdr = findrec();
X
X			if (!exhdr->ext_hdr.isextended) {
X				userec(exhdr);
X				break;
X			}
X			userec(exhdr);
X		}*/
X		skip_extended_headers();
X	}
X			
X	if(f_multivol)
X		save_name=head->header.name;
X	/* Skip to the next header on the archive */
X		
X	skip_file((long) hstat.st_size);
X		
X	if(f_multivol)
X		save_name = 0;
X}
X
X
X/*
X * Read a record that's supposed to be a header record.
X * Return its address in "head", and if it is good, the file's
X * size in hstat.st_size.
X *
X * Return 1 for success, 0 if the checksum is bad, EOF on eof,
X * 2 for a record full of zeros (EOF marker).
X *
X * You must always userec(head) to skip past the header which this
X * routine reads.
X */
Xint
Xread_header()
X{
X	register int	i;
X	register long	sum, recsum;
X	register char	*p;
X	register union record *header;
X	long	from_oct();
X
X	header = findrec();
X	head = header;		/* This is our current header */
X	if (NULL == header)
X		return EOF;
X
X	recsum = from_oct(8,  header->header.chksum);
X
X	sum = 0;
X	p = header->charptr;
X	for (i = sizeof(*header); --i >= 0;) {
X		/*
X		 * We can't use unsigned char here because of old compilers,
X		 * e.g. V7.
X		 */
X		sum += 0xFF & *p++;
X	}
X
X	/* Adjust checksum to count the "chksum" field as blanks. */
X	for (i = sizeof(header->header.chksum); --i >= 0;)
X		sum -= 0xFF & header->header.chksum[i];
X	sum += ' '* sizeof header->header.chksum;	
X
X	if (sum == recsum) {
X		/*
X		 * Good record.  Decode file size and return.
X		 */
X		if (header->header.linkflag == LF_LINK)
X			hstat.st_size = 0;	/* Links 0 size on tape */
X		else
X			hstat.st_size = from_oct(1+12, header->header.size);
X		return 1;
X	}
X
X	if (sum == 8*' ') {
X		/*
X		 * This is a zeroed record...whole record is 0's except
X		 * for the 8 blanks we faked for the checksum field.
X		 */
X		return 2;
X	}
X
X	return 0;
X}
X
X
X/* 
X * Decode things from a file header record into a "struct stat".
X * Also set "*stdp" to !=0 or ==0 depending whether header record is "Unix
X * Standard" tar format or regular old tar format.
X *
X * read_header() has already decoded the checksum and length, so we don't.
X *
X * If wantug != 0, we want the uid/group info decoded from Unix Standard
X * tapes (for extraction).  If == 0, we are just printing anyway, so save time.
X *
X * decode_header should NOT be called twice for the same record, since the
X * two calls might use different "wantug" values and thus might end up with
X * different uid/gid for the two calls.  If anybody wants the uid/gid they
X * should decode it first, and other callers should decode it without uid/gid
X * before calling a routine, e.g. print_header, that assumes decoded data.
X */
Xdecode_header(header, st, stdp, wantug)
X	register union record	*header;
X	register struct stat	*st;
X	int	*stdp;
X	int	wantug;
X{
X
X	long from_oct();
X
X	st->st_mode = from_oct(8,  header->header.mode);
X	st->st_mtime = from_oct(1+12, header->header.mtime);
X	if(f_gnudump) {
X		st->st_atime = from_oct(1+12, header->header.atime);
X		st->st_ctime = from_oct(1+12, header->header.ctime);
X	}
X	
X	if (0==strcmp(header->header.magic, TMAGIC)) {
X		/* Unix Standard tar archive */
X		*stdp = 1;
X		if (wantug) {
X#ifdef NONAMES
X			st->st_uid = from_oct(8,  header->header.uid);
X			st->st_gid = from_oct(8,  header->header.gid);
X#else
X			st->st_uid = finduid(header->header.uname);
X			st->st_gid = findgid(header->header.gname);
X#endif
X		}
X		switch (header->header.linkflag) {
X		case LF_BLK: case LF_CHR:
X		    st->st_rdev = makedev(from_oct(8, header->header.devmajor),
X			 		  from_oct(8, header->header.devminor));
X		}
X	} else {
X		/* Old fashioned tar archive */
X		*stdp = 0;
X		st->st_uid = from_oct(8,  header->header.uid);
X		st->st_gid = from_oct(8,  header->header.gid);
X		st->st_rdev = 0;
X	}
X}
X
X
X/*
X * Quick and dirty octal conversion.
X *
X * Result is -1 if the field is invalid (all blank, or nonoctal).
X */
Xlong
Xfrom_oct(digs, where)
X	register int	digs;
X	register char	*where;
X{
X	register long	value;
X
X	while (isspace(*where)) {		/* Skip spaces */
X		where++;
X		if (--digs <= 0)
X			return -1;		/* All blank field */
X	}
X	value = 0;
X	while (digs > 0 && isodigit(*where)) {	/* Scan til nonoctal */
X		value = (value << 3) | (*where++ - '0');
X		--digs;
X	}
X
X	if (digs > 0 && *where && !isspace(*where))
X		return -1;			/* Ended on non-space/nul */
X
X	return value;
X}
X
X
X/*
X * Actually print it.
X *
X * Plain and fancy file header block logging.
X * Non-verbose just prints the name, e.g. for "tar t" or "tar x".
X * This should just contain file names, so it can be fed back into tar
X * with xargs or the "-T" option.  The verbose option can give a bunch
X * of info, one line per file.  I doubt anybody tries to parse its
X * format, or if they do, they shouldn't.  Unix tar is pretty random here
X * anyway.
X *
X * Note that print_header uses the globals <head>, <hstat>, and
X * <head_standard>, which must be set up in advance.  This is not very clean
X * and should be cleaned up.  FIXME.
X */
X#define	UGSWIDTH	11		/* min width of User, group, size */
X#define	DATEWIDTH	19		/* Last mod date */
Xstatic int	ugswidth = UGSWIDTH;	/* Max width encountered so far */
X
Xvoid
Xprint_header()
X{
X	char modes[11];
X	char *timestamp;
X	char uform[11], gform[11];	/* These hold formatted ints */
X	char *user, *group;
X	char size[24];		/* Holds a formatted long or maj, min */
X	long longie;		/* To make ctime() call portable */
X	int	pad;
X	char *name;
X	extern long baserec;
X
X	if(f_sayblock)
X		fprintf(msg_file,"rec %10d: ",baserec + (ar_record - ar_block));
X	/* annofile(msg_file, (char *)NULL); */
X
X	if (f_verbose <= 1) {
X		/* Just the fax, mam. */
X		char *name;
X
X		name=quote_copy_string(head->header.name);
X		if(name==0)
X			name=head->header.name;
X		fprintf(msg_file, "%s\n", name);
X		if(name!=head->header.name)
X			free(name);
X	} else {
X		/* File type and modes */
X		modes[0] = '?';
X		switch (head->header.linkflag) {
X		case LF_VOLHDR:
X			modes[0]='V';
X			break;
X
X		case LF_MULTIVOL:
X			modes[0]='M';
X			break;
X
X		case LF_NAMES:
X			modes[0]='N';
X			break;
X
X		case LF_SPARSE:
X		case LF_NORMAL:
X		case LF_OLDNORMAL:
X		case LF_LINK:
X				modes[0] = '-'; 
X				if ('/' == head->header.name[strlen(head->header.name)-1])
X					modes[0] = 'd';
X				break;
X		case LF_DUMPDIR:modes[0] = 'd'; break;
X		case LF_DIR:	modes[0] = 'd'; break;
X		case LF_SYMLINK:modes[0] = 'l'; break;
X		case LF_BLK:	modes[0] = 'b'; break;
X		case LF_CHR:	modes[0] = 'c'; break;
X		case LF_FIFO:	modes[0] = 'p'; break;	
X		case LF_CONTIG:	modes[0] = 'C'; break;
X		}
X
X		demode((unsigned)hstat.st_mode, modes+1);
X
X		/* Timestamp */
X		longie = hstat.st_mtime;
X		timestamp = ctime(&longie);
X		timestamp[16] = '\0';
X		timestamp[24] = '\0';
X
X		/* User and group names */
X		if (*head->header.uname && head_standard) {
X			user  = head->header.uname;
X		} else {
X			user = uform;
X			(void)sprintf(uform, "%d", (int)hstat.st_uid);
X		}
X		if (*head->header.gname && head_standard) {
X			group = head->header.gname;
X		} else {
X			group = gform;
X			(void)sprintf(gform, "%d", (int)hstat.st_gid);
X		}
X
X		/* Format the file size or major/minor device numbers */
X		switch (head->header.linkflag) {
X		case LF_CHR:
X		case LF_BLK:
X			(void)sprintf(size, "%d,%d",
X					major(hstat.st_rdev),
X					minor(hstat.st_rdev));
X			break;
X		case LF_SPARSE:
X			(void)sprintf(size, "%ld",
X 				from_oct(1+12, head->header.realsize));
X			break;
X		default:
X			(void)sprintf(size, "%ld", (long)hstat.st_size);
X		}
X
X		/* Figure out padding and print the whole line. */
X		pad = strlen(user) + strlen(group) + strlen(size) + 1;
X		if (pad > ugswidth) ugswidth = pad;
X
X		name = quote_copy_string(head->header.name);
X		if(!name)
X			name=head->header.name;
X		fprintf(msg_file, "%s %s/%s %*s%s %s %s %.*s",
X			modes,
X			user,
X			group,
X			ugswidth - pad,
X			"",
X			size,
X			timestamp+4, timestamp+20,
X			sizeof(head->header.name),
X			name);
X
X		if(name!=head->header.name)
X			free(name);
X		switch (head->header.linkflag) {
X		case LF_SYMLINK:
X			name=quote_copy_string(head->header.linkname);
X			if(!name)
X				name=head->header.linkname;
X			fprintf(msg_file, " -> %s\n", name);
X			if(name!=head->header.linkname)
X				free(name);
X			break;
X
X		case LF_LINK:
X			name=quote_copy_string(head->header.linkname);
X			if(!name)
X				name=head->header.linkname;
X			fprintf(msg_file, " link to %s\n", head->header.linkname);
X			if(name!=head->header.linkname)
X				free(name);
X			break;
X
X		default:
X			fprintf(msg_file, " unknown file type '%c'\n",
X				head->header.linkflag);
X			break;
X
X		case LF_OLDNORMAL:
X		case LF_NORMAL:
X		case LF_SPARSE:
X		case LF_CHR:
X		case LF_BLK:
X		case LF_DIR:
X		case LF_FIFO:
X		case LF_CONTIG:
X		case LF_DUMPDIR:
X			putc('\n', msg_file);
X			break;
X
X		case LF_VOLHDR:
X			fprintf(msg_file, "--Volume Header--\n");
X			break;
X			
X		case LF_MULTIVOL:
X			fprintf(msg_file, "--Continued at byte %ld--\n",from_oct(1+12,head->header.offset));
X			break;
X
X		case LF_NAMES:
X			fprintf(msg_file,"--Mangled file names--\n");
X			break;
X		}
X	}
X	fflush(msg_file);
X}
X
X/*
X * Print a similar line when we make a directory automatically.
X */
Xvoid
Xpr_mkdir(pathname, length, mode)
X	char *pathname;
X	int length;
X	int mode;
X{
X	char modes[11];
X	char *name;
X	extern long baserec;
X
X	if (f_verbose > 1) {
X		/* File type and modes */
X		modes[0] = 'd';
X		demode((unsigned)mode, modes+1);
X
X		if(f_sayblock)
X			fprintf(msg_file,"rec %10d: ",baserec + (ar_record - ar_block));
X		/* annofile(msg_file, (char *)NULL); */
X		name=quote_copy_string(pathname);
X		if(!name)
X			name=pathname;
X		fprintf(msg_file, "%s %*s %.*s\n",
X			modes,
X			ugswidth+DATEWIDTH,
X			"Creating directory:",
X			length,
X			pathname);
X		if(name!=pathname)
X			free(name);
X	}
X}
X
X
X/*
X * Skip over <size> bytes of data in records in the archive.
X */
Xvoid
Xskip_file(size)
X	register long size;
X{
X	union record *x;
X	extern long save_totsize;
X	extern long save_sizeleft;
X
X	if(f_multivol) {
X		save_totsize=size;
X		save_sizeleft=size;
X	}
X
X	while (size > 0) {
X		x = findrec();
X		if (x == NULL) {	/* Check it... */
X			msg("Unexpected EOF on archive file");
X			exit(EX_BADARCH);
X		}
X		userec(x);
X		size -= RECORDSIZE;
X		if(f_multivol)
X			save_sizeleft-=RECORDSIZE;
X	}
X}
X
Xvoid
Xskip_extended_headers()
X{
X	register union record *exhdr;
X
X	for (;;) {
X	    exhdr = findrec();
X	    if (!exhdr->ext_hdr.isextended) {
X	        userec(exhdr);
X	    	break;
X	    }
X	    userec (exhdr);
X	}
X}
X
X/*
X * Decode the mode string from a stat entry into a 9-char string and a null.
X */
Xvoid
Xdemode(mode, string)
X	register unsigned mode;
X	register char *string;
X{
X	register unsigned mask;
X	register char *rwx = "rwxrwxrwx";
X
X	for (mask = 0400; mask != 0; mask >>= 1) {
X		if (mode & mask)
X			*string++ = *rwx++;
X		else {
X			*string++ = '-';
X			rwx++;
X		}
X	}
X
X	if (mode & S_ISUID)
X		if (string[-7] == 'x')
X			string[-7] = 's';
X		else
X			string[-7] = 'S';
X	if (mode & S_ISGID)
X		if (string[-4] == 'x')
X			string[-4] = 's';
X		else
X			string[-4] = 'S';
X	if (mode & S_ISVTX)
X		if (string[-1] == 'x')
X			string[-1] = 't';
X		else
X			string[-1] = 'T';
X	*string = '\0';
X}
END_OF_FILE
if test 16614 -ne `wc -c <'list.c'`; then
    echo shar: \"'list.c'\" unpacked with wrong size!
fi
# end of 'list.c'
fi
if test -f 'names.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'names.c'\"
else
echo shar: Extracting \"'names.c'\" \(3106 characters\)
sed "s/^X//" >'names.c' <<'END_OF_FILE'
X/* Look up user and/or group names.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/*
X * Look up user and/or group names.
X *
X * This file should be modified for non-unix systems to do something
X * reasonable.
X *
X * @(#)names.c 1.3 10/30/87 - gnu
X */ 
X#include <sys/types.h>
X#include "tar.h"
X
Xextern	char	*strncpy();
X
X#ifndef NONAMES
X/* Whole module goes away if NONAMES defined.  Otherwise... */
X#include <pwd.h>
X#include <grp.h>
X
Xstatic int	saveuid = -993;
Xstatic char	saveuname[TUNMLEN];
Xstatic int	my_uid = -993;
X
Xstatic int	savegid = -993;
Xstatic char	savegname[TGNMLEN];
Xstatic int	my_gid = -993;
X
X#define myuid	( my_uid < 0? (my_uid = getuid()): my_uid )
X#define	mygid	( my_gid < 0? (my_gid = getgid()): my_gid )
X
X/*
X * Look up a user or group name from a uid/gid, maintaining a cache.
X * FIXME, for now it's a one-entry cache.
X * FIXME2, the "-993" is to reduce the chance of a hit on the first lookup.
X *
X * This is ifdef'd because on Suns, it drags in about 38K of "yellow
X * pages" code, roughly doubling the program size.  Thanks guys.
X */
Xvoid
Xfinduname(uname, uid)
X	char	uname[TUNMLEN];
X	int	uid;
X{
X	struct passwd	*pw;
X	extern struct passwd *getpwuid ();
X
X	if (uid != saveuid) {
X		saveuid = uid;
X		saveuname[0] = '\0';
X		pw = getpwuid(uid); 
X		if (pw) 
X			strncpy(saveuname, pw->pw_name, TUNMLEN);
X	}
X	strncpy(uname, saveuname, TUNMLEN);
X}
X
Xint
Xfinduid(uname)
X	char	uname[TUNMLEN];
X{
X	struct passwd	*pw;
X	extern struct passwd *getpwnam();
X
X	if (uname[0] != saveuname[0]	/* Quick test w/o proc call */
X	    || 0!=strncmp(uname, saveuname, TUNMLEN)) {
X		strncpy(saveuname, uname, TUNMLEN);
X		pw = getpwnam(uname); 
X		if (pw) {
X			saveuid = pw->pw_uid;
X		} else {
X			saveuid = myuid;
X		}
X	}
X	return saveuid;
X}
X
X
Xvoid
Xfindgname(gname, gid)
X	char	gname[TGNMLEN];
X	int	gid;
X{
X	struct group	*gr;
X	extern struct group *getgrgid ();
X
X	if (gid != savegid) {
X		savegid = gid;
X		savegname[0] = '\0';
X		(void)setgrent();
X		gr = getgrgid(gid); 
X		if (gr) 
X			strncpy(savegname, gr->gr_name, TGNMLEN);
X	}
X	(void) strncpy(gname, savegname, TGNMLEN);
X}
X
X
Xint
Xfindgid(gname)
X	char	gname[TUNMLEN];
X{
X	struct group	*gr;
X	extern struct group *getgrnam();
X
X	if (gname[0] != savegname[0]	/* Quick test w/o proc call */
X	    || 0!=strncmp(gname, savegname, TUNMLEN)) {
X		strncpy(savegname, gname, TUNMLEN);
X		gr = getgrnam(gname); 
X		if (gr) {
X			savegid = gr->gr_gid;
X		} else {
X			savegid = mygid;
X		}
X	}
X	return savegid;
X}
X#endif
END_OF_FILE
if test 3106 -ne `wc -c <'names.c'`; then
    echo shar: \"'names.c'\" unpacked with wrong size!
fi
# end of 'names.c'
fi
if test -f 'diffarch.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'diffarch.c'\"
else
echo shar: Extracting \"'diffarch.c'\" \(15348 characters\)
sed "s/^X//" >'diffarch.c' <<'END_OF_FILE'
X/* Diff files from a tar archive.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/*
X * Diff files from a tar archive.
X *
X * Written 30 April 1987 by John Gilmore, ihnp4!hoptoad!gnu.
X *
X * @(#) diffarch.c 1.10 87/11/11 - gnu
X */
X
X#include <stdio.h>
X#include <errno.h>
X#include <sys/types.h>
X#include <sys/stat.h>
X
X#ifdef BSD42
X#include <sys/file.h>
X#endif
X
X#ifndef MSDOS
X#include <sys/ioctl.h>
X#if !defined(USG) || defined(HAVE_MTIO)
X#include <sys/mtio.h>
X#endif
X#endif
X
X#ifdef USG
X#include <fcntl.h>
X#endif
X
X/* Some systems don't have these #define's -- we fake it here. */
X#ifndef O_RDONLY
X#define	O_RDONLY	0
X#endif
X#ifndef	O_NDELAY
X#define	O_NDELAY	0
X#endif
X
X#ifndef S_IFLNK
X#define lstat stat
X#endif
X
Xextern int errno;			/* From libc.a */
Xextern char *valloc();			/* From libc.a */
X
X#include "tar.h"
X#include "port.h"
X#include "rmt.h"
X
Xextern union record *head;		/* Points to current tape header */
Xextern struct stat hstat;		/* Stat struct corresponding */
Xextern int head_standard;		/* Tape header is in ANSI format */
X
Xextern void print_header();
Xextern void skip_file();
Xextern void skip_extended_headers();
X
Xextern FILE *msg_file;
X
Xint now_verifying = 0;		/* Are we verifying at the moment? */
X
Xint	diff_fd;		/* Descriptor of file we're diffing */
X
Xchar	*diff_buf = 0;		/* Pointer to area for reading
X					   file contents into */
X
Xchar	*diff_dir;		/* Directory contents for LF_DUMPDIR */
X
Xint different = 0;
X
X/*struct sp_array *sparsearray;
Xint 		sp_ar_size = 10;*/
X/*
X * Initialize for a diff operation
X */
Xdiff_init()
X{
X
X	/*NOSTRICT*/
X	diff_buf = (char *) valloc((unsigned)blocksize);
X	if (!diff_buf) {
X		msg("could not allocate memory for diff buffer of %d bytes",
X			blocksize);
X		exit(EX_ARGSBAD);
X	}
X}
X
X/*
X * Diff a file against the archive.
X */
Xvoid
Xdiff_archive()
X{
X	register char *data;
X	int check, namelen;
X	int err;
X	long offset;
X	struct stat filestat;
X	int compare_chunk();
X	int compare_dir();
X#ifndef __MSDOS__
X	dev_t	dev;
X	ino_t	ino;
X#endif
X	char *get_dir_contents();
X	long from_oct();
X	long lseek();
X
X	errno = EPIPE;			/* FIXME, remove perrors */
X
X	saverec(&head);			/* Make sure it sticks around */
X	userec(head);			/* And go past it in the archive */
X	decode_header(head, &hstat, &head_standard, 1);	/* Snarf fields */
X
X	/* Print the record from 'head' and 'hstat' */
X	if (f_verbose) {
X		if(now_verifying)
X			fprintf(msg_file,"Verify ");
X		print_header();
X	}
X
X	switch (head->header.linkflag) {
X
X	default:
X		msg("Unknown file type '%c' for %s, diffed as normal file",
X			head->header.linkflag, head->header.name);
X		/* FALL THRU */
X
X	case LF_OLDNORMAL:
X	case LF_NORMAL:
X	case LF_SPARSE:
X	case LF_CONTIG:
X		/*
X		 * Appears to be a file.
X		 * See if it's really a directory.
X		 */
X		namelen = strlen(head->header.name)-1;
X		if (head->header.name[namelen] == '/')
X			goto really_dir;
X
X		
X		if(do_stat(&filestat)) {
X			if (head->header.isextended)
X				skip_extended_headers();
X			skip_file((long)hstat.st_size);
X			different++;
X			goto quit;
X		}
X
X		if ((filestat.st_mode & S_IFMT) != S_IFREG) {
X			fprintf(msg_file, "%s: not a regular file\n",
X				head->header.name);
X			skip_file((long)hstat.st_size);
X			different++;
X			goto quit;
X		}
X
X		filestat.st_mode &= ~S_IFMT;
X		if (filestat.st_mode != hstat.st_mode)
X			sigh("mode");
X		if (filestat.st_uid  != hstat.st_uid)
X			sigh("uid");
X		if (filestat.st_gid  != hstat.st_gid)
X			sigh("gid");
X		if (filestat.st_mtime != hstat.st_mtime)
X			sigh("mod time");
X		if (head->header.linkflag != LF_SPARSE &&
X				filestat.st_size != hstat.st_size) {
X			sigh("size");
X			skip_file((long)hstat.st_size);
X			goto quit;
X		}
X
X		diff_fd = open(head->header.name, O_NDELAY|O_RDONLY);
X
X		if (diff_fd < 0 && !f_absolute_paths) {
X			char tmpbuf[NAMSIZ+2];
X
X			tmpbuf[0]='/';
X			strcpy(&tmpbuf[1],head->header.name);
X			diff_fd=open(tmpbuf, O_NDELAY|O_RDONLY);
X		}
X		if (diff_fd < 0) {
X			msg_perror("cannot open %s",head->header.name);
X			if (head->header.isextended)
X				skip_extended_headers();
X			skip_file((long)hstat.st_size);
X			different++;
X			goto quit;
X		}
X		/*
X		 * Need to treat sparse files completely differently here.
X		 */
X		if (head->header.linkflag == LF_SPARSE)
X			diff_sparse_files(hstat.st_size);
X		else 
X			wantbytes((long)(hstat.st_size),compare_chunk);
X
X		check = close(diff_fd);
X		if (check < 0)
X			msg_perror("Error while closing %s",head->header.name);
X
X	quit:
X		break;
X
X#ifndef __MSDOS__
X	case LF_LINK:
X		if(do_stat(&filestat))
X			break;
X		dev = filestat.st_dev;
X		ino = filestat.st_ino;
X		err = stat(head->header.linkname, &filestat);
X		if (err < 0) {
X			if (errno==ENOENT) {
X				fprintf(msg_file, "%s: does not exist\n",head->header.name);
X			} else {
X				msg_perror("cannot stat file %s",head->header.name);
X			}
X			different++;
X			break;
X		}
X		if(filestat.st_dev!=dev || filestat.st_ino!=ino) {
X			fprintf(msg_file, "%s not linked to %s\n",head->header.name,head->header.linkname);
X			break;
X		}
X		break;
X#endif
X
X#ifdef S_IFLNK
X	case LF_SYMLINK:
X	{
X		char linkbuf[NAMSIZ+3];
X		check = readlink(head->header.name, linkbuf,
X				 (sizeof linkbuf)-1);
X		
X		if (check < 0) {
X			if (errno == ENOENT) {
X				fprintf(msg_file,
X					"%s: no such file or directory\n",
X					head->header.name);
X			} else {
X				msg_perror("cannot read link %s",head->header.name);
X			}
X			different++;
X			break;
X		}
X
X		linkbuf[check] = '\0';	/* Null-terminate it */
X		if (strncmp(head->header.linkname, linkbuf, check) != 0) {
X			fprintf(msg_file, "%s: symlink differs\n",
X				head->header.linkname);
X			different++;
X		}
X	}
X		break;
X#endif
X
X	case LF_CHR:
X		hstat.st_mode |= S_IFCHR;
X		goto check_node;
X
X#ifdef S_IFBLK
X	/* If local system doesn't support block devices, use default case */
X	case LF_BLK:
X		hstat.st_mode |= S_IFBLK;
X		goto check_node;
X#endif
X
X#ifdef S_IFIFO
X	/* If local system doesn't support FIFOs, use default case */
X	case LF_FIFO:
X		hstat.st_mode |= S_IFIFO;
X		hstat.st_rdev = 0;		/* FIXME, do we need this? */
X		goto check_node;
X#endif
X
X	check_node:
X		/* FIXME, deal with umask */
X		if(do_stat(&filestat))
X			break;
X		if(hstat.st_rdev != filestat.st_rdev) {
X			fprintf(msg_file, "%s: device numbers changed\n", head->header.name);
X			different++;
X			break;
X		}
X		if(hstat.st_mode != filestat.st_mode) {
X			fprintf(msg_file, "%s: mode or device-type changed\n", head->header.name);
X			different++;
X			break;
X		}
X		break;
X
X	case LF_DUMPDIR:
X		data=diff_dir=get_dir_contents(head->header.name,0);
X		wantbytes((long)(hstat.st_size),compare_dir);
X		free(data);
X		/* FALL THROUGH */
X
X	case LF_DIR:
X		/* Check for trailing / */
X		namelen = strlen(head->header.name)-1;
X	really_dir:
X		while (namelen && head->header.name[namelen] == '/')
X			head->header.name[namelen--] = '\0';	/* Zap / */
X
X		if(do_stat(&filestat))
X			break;
X		if((filestat.st_mode&S_IFMT)!=S_IFDIR) {
X			fprintf(msg_file, "%s is no longer a directory\n",head->header.name);
X			different++;
X			break;
X		}
X		if((filestat.st_mode&~S_IFMT) != hstat.st_mode)
X			sigh("mode");
X		break;
X
X	case LF_VOLHDR:
X		break;
X
X	case LF_MULTIVOL:
X		namelen = strlen(head->header.name)-1;
X		if (head->header.name[namelen] == '/')
X			goto really_dir;
X
X		if(do_stat(&filestat))
X			break;
X
X		if ((filestat.st_mode & S_IFMT) != S_IFREG) {
X			fprintf(msg_file, "%s: not a regular file\n",
X				head->header.name);
X			skip_file((long)hstat.st_size);
X			different++;
X			break;
X		}
X
X		filestat.st_mode &= ~S_IFMT;
X		offset = from_oct(1+12, head->header.offset);
X		if (filestat.st_size != hstat.st_size + offset) {
X			sigh("size");
X			skip_file((long)hstat.st_size);
X			different++;
X			break;
X		}
X
X		diff_fd = open(head->header.name, O_NDELAY|O_RDONLY);
X
X		if (diff_fd < 0) {
X			msg_perror("cannot open file %s",head->header.name);
X			skip_file((long)hstat.st_size);
X			different++;
X			break;
X		}
X		err = lseek(diff_fd, offset, 0);
X		if(err!=offset) {
X			msg_perror("cannot seek to %ld in file %s",offset,head->header.name);
X			different++;
X			break;
X		}
X
X		wantbytes((long)(hstat.st_size),compare_chunk);
X
X		check = close(diff_fd);
X		if (check < 0) {
X			msg_perror("Error while closing %s",head->header.name);
X		}
X		break;
X
X	}
X
X	/* We don't need to save it any longer. */
X	saverec((union record **) 0);	/* Unsave it */
X}
X
Xint
Xcompare_chunk(bytes,buffer)
Xlong bytes;
Xchar *buffer;
X{
X	int err;
X
X	err=read(diff_fd,diff_buf,bytes);
X	if(err!=bytes) {
X		if(err<0) {
X			msg_perror("can't read %s",head->header.name);
X		} else {
X			fprintf(msg_file,"%s: could only read %d of %d bytes\n",head->header.name,err,bytes);
X		}
X		different++;
X		return -1;
X	}
X	if(bcmp(buffer,diff_buf,bytes)) {
X		fprintf(msg_file, "%s: data differs\n",head->header.name);
X		different++;
X		return -1;
X	}
X	return 0;
X}
X
Xint
Xcompare_dir(bytes,buffer)
Xlong bytes;
Xchar *buffer;
X{
X	if(bcmp(buffer,diff_dir,bytes)) {
X		fprintf(msg_file, "%s: data differs\n",head->header.name);
X		different++;
X		return -1;
X	}
X	diff_dir+=bytes;
X	return 0;
X}
X
X/*
X * Sigh about something that differs.
X */
Xsigh(what)
X	char *what;
X{
X
X	fprintf(msg_file, "%s: %s differs\n",
X		head->header.name, what);
X}
X
Xverify_volume()
X{
X	int status;
X#ifdef MTIOCTOP
X	struct mtop t;
X	int er;
X#endif
X
X	if(!diff_buf)
X		diff_init();
X#ifdef MTIOCTOP
X	t.mt_op = MTBSF;
X	t.mt_count = 1;
X	if((er=rmtioctl(archive,MTIOCTOP,&t))<0) {
X		if(errno!=EIO || (er=rmtioctl(archive,MTIOCTOP,&t))<0) {
X#endif
X			if(rmtlseek(archive,0L,0)!=0) {
X				/* Lseek failed.  Try a different method */
X				msg_perror("Couldn't rewind archive file for verify");
X				return;
X			}
X#ifdef MTIOCTOP
X		}
X	}
X#endif
X	ar_reading=1;
X	now_verifying = 1;
X	fl_read();
X	for(;;) {
X		status = read_header();
X		if(status==0) {
X			unsigned n;
X
X			n=0;
X			do {
X				n++;
X				status=read_header();
X			} while(status==0);
X			msg("VERIFY FAILURE: %d invalid header%s detected!",n,n==1?"":"s");
X		}
X		if(status==2 || status==EOF)
X			break;
X		diff_archive();
X	}
X	ar_reading=0;
X	now_verifying = 0;
X
X}
X
Xint do_stat(statp)
Xstruct stat *statp;
X{
X	int err;
X
X	err = f_follow_links ? stat(head->header.name, statp) : lstat(head->header.name, statp);
X	if (err < 0) {
X		if (errno==ENOENT) {
X			fprintf(msg_file, "%s: does not exist\n",head->header.name);
X		} else
X			msg_perror("can't stat file %s",head->header.name);
X/*		skip_file((long)hstat.st_size);
X		different++;*/
X		return 1;
X	} else
X		return 0;
X}
X
X/*
X * JK
X * Diff'ing a sparse file with its counterpart on the tar file is a 
X * bit of a different story than a normal file.  First, we must know
X * what areas of the file to skip through, i.e., we need to contruct
X * a sparsearray, which will hold all the information we need.  We must
X * compare small amounts of data at a time as we find it.  
X */
X
Xdiff_sparse_files(filesize)
Xint	filesize;
X
X{
X	int		sparse_ind = 0;
X	char		*buf;
X	int		buf_size = RECORDSIZE;
X	union record 	*datarec;	
X	int		err;
X	long		numbytes;
X	int		amt_read = 0;
X	int		size = filesize;
X
X	buf = (char *) malloc(buf_size * sizeof (char));
X	
X	fill_in_sparse_array();
X	
X
X	while (size > 0) {
X		datarec = findrec();
X		if (!sparsearray[sparse_ind].numbytes)
X			break;
X
X		/*
X		 * 'numbytes' is nicer to write than
X		 * 'sparsearray[sparse_ind].numbytes' all the time ...
X		 */
X		numbytes = sparsearray[sparse_ind].numbytes;
X		
X		lseek(diff_fd, sparsearray[sparse_ind].offset, 0);
X		/*
X		 * take care to not run out of room in our buffer
X		 */
X		while (buf_size < numbytes) {
X			buf = (char *) realloc(buf, buf_size * 2 * sizeof(char));
X			buf_size *= 2;
X		}
X		while (numbytes > RECORDSIZE) {
X			if ((err = read(diff_fd, buf, RECORDSIZE)) != RECORDSIZE) {
X	 			if (err < 0) 
X					msg_perror("can't read %s", head->header.name);
X				else
X					fprintf(msg_file, "%s: could only read %d of %d bytes\n", 
X						err, numbytes);
X				break;
X			}
X			if (bcmp(buf, datarec->charptr, RECORDSIZE)) {
X				different++;
X				break;
X			}
X			numbytes -= err;
X			size -= err;
X			userec(datarec);
X			datarec = findrec();
X		}
X		if ((err = read(diff_fd, buf, numbytes)) != numbytes) {
X 			if (err < 0) 
X				msg_perror("can't read %s", head->header.name);
X			else
X				fprintf(msg_file, "%s: could only read %d of %d bytes\n", 
X						err, numbytes);
X			break;
X		}
X
X		if (bcmp(buf, datarec->charptr, numbytes)) {
X			different++;
X			break;
X		}
X/*		amt_read += numbytes;
X		if (amt_read >= RECORDSIZE) {
X			amt_read = 0;
X			userec(datarec);
X			datarec = findrec();
X		}*/
X		userec(datarec);
X		sparse_ind++;
X		size -= numbytes;
X	}
X	/* 
X	 * if the number of bytes read isn't the
X	 * number of bytes supposedly in the file,
X	 * they're different
X	 */
X/*	if (amt_read != filesize)
X		different++;*/
X	userec(datarec);
X	free(sparsearray);
X	if (different)
X		fprintf(msg_file, "%s: data differs\n", head->header.name);
X
X}
X
X/*
X * JK
X * This routine should be used more often than it is ... look into
X * that.  Anyhow, what it does is translate the sparse information
X * on the header, and in any subsequent extended headers, into an
X * array of structures with true numbers, as opposed to character
X * strings.  It simply makes our life much easier, doing so many
X * comparisong and such.
X */
Xfill_in_sparse_array()
X{
X	int 	ind;
X
X	/*
X	 * allocate space for our scratch space; it's initially
X	 * 10 elements long, but can change in this routine if
X	 * necessary
X	 */
X	sp_array_size = 10;
X	sparsearray = (struct sp_array *) malloc(sp_array_size * sizeof(struct sp_array));
X
X	/*
X	 * there are at most five of these structures in the header
X	 * itself; read these in first
X	 */
X	for (ind = 0; ind < SPARSE_IN_HDR; ind++) {
X		if (!head->header.sp[ind].numbytes)
X			break;
X		sparsearray[ind].offset =
X			from_oct(1+12, head->header.sp[ind].offset);
X		sparsearray[ind].numbytes =
X			from_oct(1+12, head->header.sp[ind].numbytes);
X	}
X	/*
X	 * if the header's extended, we gotta read in exhdr's till
X	 * we're done
X	 */
X	if (head->header.isextended) {
X 	    /* how far into the sparsearray we are 'so far' */
X	    static int so_far_ind = SPARSE_IN_HDR;	
X	    union record *exhdr;
X   	    
X	    for (;;) {
X		exhdr = findrec();
X		for (ind = 0; ind < SPARSE_EXT_HDR; ind++) {
X			if (ind+so_far_ind > sp_array_size-1) {
X				/*
X 				 * we just ran out of room in our
X				 *  scratch area - realloc it
X 				 */
X				sparsearray = (struct sp_array *)
X					realloc(sparsearray, 
X						sp_array_size*2*sizeof(struct sp_array));
X				sp_array_size *= 2;
X			}
X			/*
X			 * convert the character strings into longs
X			 */
X			sparsearray[ind+so_far_ind].offset = 
X			    from_oct(1+12, exhdr->ext_hdr.sp[ind].offset);
X			sparsearray[ind+so_far_ind].numbytes =
X			    from_oct(1+12, exhdr->ext_hdr.sp[ind].numbytes);
X		}
X		/* 
X		 * if this is the last extended header for this
X		 * file, we can stop
X		 */
X		if (!exhdr->ext_hdr.isextended)
X			break;
X		else {
X			so_far_ind += SPARSE_EXT_HDR;
X			userec(exhdr);
X		}
X	    }
X	    /* be sure to skip past the last one  */
X	    userec(exhdr);
X	}
X}
END_OF_FILE
if test 15348 -ne `wc -c <'diffarch.c'`; then
    echo shar: \"'diffarch.c'\" unpacked with wrong size!
fi
# end of 'diffarch.c'
fi
if test -f 'port.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'port.c'\"
else
echo shar: Extracting \"'port.c'\" \(27532 characters\)
sed "s/^X//" >'port.c' <<'END_OF_FILE'
X/* Supporting routines which may sometimes be missing.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/*
X * @(#)port.c 1.15	87/11/05	by John Gilmore, 1986
X *
X * These are routines not available in all environments.
X *
X * I know this introduces an extra level of subroutine calls and is
X * slightly slower.  Frankly, my dear, I don't give a damn.  Let the
X * Missed-Em Vee losers suffer a little.  This software is proud to
X * have been written on a BSD system.
X */
X#include <stdio.h>
X#include <sys/types.h>
X#include <sys/stat.h>
X#include <signal.h>
X#include <errno.h>
X
X#if	defined(__MSDOS__) || defined(USG)
X#include <fcntl.h>
X#else
X#include <sys/file.h>
X#endif
X
X#include "tar.h"
X#include "port.h"
X
X#ifdef USG
X#include <string.h>
X#else
Xextern size_t strlen();
X#endif
X
Xextern long baserec;
X/*
X * Some people (e.g. V7) don't have a #define for these.
X */
X#ifndef	O_BINARY
X#define	O_BINARY	0
X#endif
X#ifndef	O_RDONLY
X#define	O_RDONLY	0
X#endif
X#ifndef NULL
X#define NULL 0
X#endif
X
X/* JF: modified so all configuration information can appear here, instead of
X   being scattered through the file.  Add all the machine-dependent #ifdefs
X   here */
X#undef WANT_DUMB_GET_DATE/* WANT_DUMB_GET_DATE --> get_date() */
X#undef WANT_VALLOC	/* WANT_VALLOC --> valloc() */
X#undef WANT_MKDIR	/* WANT_MKDIR --> mkdir() rmdir() */
X#undef WANT_STRING	/* WANT_STRING --> index() bcopy() bzero() bcmp() */
X#undef WANT_BZERO	/* WANT_BZERO --> bzero() bcmp() execlp() */
X			/* EMUL_OPEN3 --> open3() */
X#undef WANT_MKNOD	/* WANT_MKNOD --> mknod() link() chown() geteuid() */
X#undef WANT_UTILS	/* WANT_UTILS --> panic() ck_*() *_buffer()
X			   merge_sort() quote_copy_string() un_quote_string() */
X#undef WANT_CK_PIPE	/* WANT_CK_PIPE --> ck_pipe() */
X#undef WANT_GETWD	/* WANT_GETWD --> getwd() */
X#undef WANT_STRSTR	/* WANT_STRSTR --> strstr() */
X#undef WANT_FTRUNCATE	/* WANT_FTRUNCATE --> frtruncate() */
X
X/* Define only ONE of these four . . . */
X/* #undef DOPRNT_MSG	/* Define this one if you have _doprnt() and
X			   no varargs support */
X/* #undef VARARGS_MSG	/* Define this one if you have varargs.h and
X			   vfprintf() */
X/* #undef STDC_MSG 	/* Define this one if you are using ANSI C and
X			   and have vfprintf() */
X/* #undef LOSING_MSG	/* Define this one if you don't have any of the
X			   above */
X#ifdef USG
X#define WANT_STRING
X#define WANT_VALLOC
X
X#if defined(sgi) && defined(mips)
X#define WANT_GETWD
X#endif
X
X#if defined(i386)
X#define WANT_FTRUNCATE
X#endif
X
X#endif
X
X#ifdef hpux
X#define WANT_VALLOC
X#endif
X
X#ifdef MINIX
X#define WANT_BZERO
X#endif
X
X#ifdef __MSDOS__
Xchar TTY_NAME[] = "con";
X
X#define WANT_STRING
X#define WANT_MKNOD
X#define WANT_UTILS
X#define WANT_VALLOC
X
X#if (!defined(STDC_MSG) && !defined(DOPRNT_MSG) && !defined(VARARGS_MSG) && !defined(LOSING_MSG))
X#ifdef __STDC__
X#define STDC_MSG
X#else
X#define LOSING_MSG
X#endif
X#endif
X
X#else /* not MSDOS */
Xchar TTY_NAME[] ="/dev/tty";
X
X#define WANT_UTILS
X#define WANT_CK_PIPE
X#ifndef HAVE_STRSTR
X#define WANT_STRSTR
X#endif
X
X#if (!defined(STDC_MSG) && !defined(DOPRNT_MSG) && !defined(VARARGS_MSG) && !defined(LOSING_MSG))
X#ifdef BSD42
X/* BSD systems should do this even if __STDC__, because
X   we might be using an ANSI compiler without an ANSI library. (sigh) */
X#ifdef sparc
X#define LOSING_MSG
X#else
X#define DOPRNT_MSG
X#endif
X#else /* not BSD */
X#ifdef __STDC__
X#define STDC_MSG
X#else /* not ANSI C */
X#define LOSING_MSG
X#endif /* not ANSI C */
X#endif /* not BSD */
X#endif /* Need to define some form of _MSG */
X#endif /* not MSDOS */
X
X/* End of system-dependent #ifdefs */
X
X#ifdef WANT_DUMB_GET_DATE
X/* JF a get_date() routine takes a date/time/etc and turns it into a time_t */
X/* This one is a quick hack I wrote in about five minutes to see if the N
X   option works.  Someone should replace it with one that works */
X
X/* This get_date takes an arg of the form mm/dd/yyyy hh:mm:ss and turns it
X   into a time_t .  Its not well tested or anything. . .  */
X/* In general, you should use the get_date() supplied in getdate.y */
X
X#define OFF_FROM GMT 18000		/* Change for your time zone! */
X
Xtime_t
Xget_date(str)
Xchar *str;
X{
X	int month,day,year,hour,minute,second;
X	time_t ret;
X	int	n;
X
X#define SECS_PER_YEAR (365L*SECS_PER_DAY)
X#define SECS_PER_LEAP_YEAR (366L*SECS_PER_DAY)
X
X#define SECS_PER_DAY (24L*60*60)
X	static int days_per_month[2][12] = {
X		31,28,31,30,31,30,31,31,30,31,30,31,
X		31,29,31,30,31,30,31,31,30,31,30,31
X	};
X
X	static int days_per_year[2]={365,366};
X
X	month=day=year=hour=minute=second=0;
X	n=sscanf(str,"%d/%d/%d %d:%d:%d",&month,&day,&year,&hour,&minute,&second);
X	if(n<3)
X		return 0;
X	if(year<100)
X		year+=1900;
X	if(year<1970)
X		return 0;
X	ret=0;
X
X	ret+=OFF_FROM_GMT;
X
X	for(n=1970;n<year;n++)
X		if(n%4==0 && n%400!=0)
X			ret+=SECS_PER_LEAP_YEAR;
X		else
X			ret+=SECS_PER_YEAR;
X
X	month--;
X	for(n=0;n<month;n++) {
X		if(year%4==0 && year%400!=0)
X			ret+=SECS_PER_DAY*days_per_month[1][n];
X		else
X			ret+=SECS_PER_DAY*days_per_month[0][n];
X	}
X	ret+=SECS_PER_DAY*(day-1);
X	ret+=second+minute*60+hour*60*60;
X	return ret;
X}
X#endif
X
X#ifdef WANT_VALLOC
X/*
X * valloc() does a malloc() on a page boundary.  On some systems,
X * this can make large block I/O more efficient.
X */
Xchar *
Xvalloc (size)
X	unsigned size;
X{
X	extern char *malloc ();
X	return (malloc (size));
X}
X#endif
X/*
X *				NMKDIR.C
X *
X * Written by Robert Rother, Mariah Corporation, August 1985. 
X *
X * I wrote this out of shear disgust with myself because I couldn't
X * figure out how to do this in /bin/sh.
X *
X * If you want it, it's yours.  All I ask in return is that if you
X * figure out how to do this in a Bourne Shell script you send me
X * a copy.
X *					sdcsvax!rmr or rmr@uscd
X*
X* Severely hacked over by John Gilmore to make a 4.2BSD compatible
X* subroutine.	11Mar86; hoptoad!gnu
X*
X* Modified by rmtodd@uokmax 6-28-87 -- when making an already existing dir,
X* subroutine didn't return EEXIST.  It does now.
X*/
X
X/*
X * Make a directory.  Compatible with the mkdir() system call on 4.2BSD.
X */
X#ifdef WANT_MKDIR
Xint
Xmkdir(dpath, dmode)
X	char *dpath;
X	int dmode;
X{
X	int cpid, status;
X	struct stat statbuf;
X	extern int errno;
X
X	if (stat(dpath,&statbuf) == 0) {
X		errno = EEXIST;		/* Stat worked, so it already exists */
X		return -1;
X	}
X
X	/* If stat fails for a reason other than non-existence, return error */
X	if (errno != ENOENT) return -1; 
X
X	switch (cpid = fork()) {
X
X	case -1:			/* Error in fork() */
X		return(-1);		/* Errno is set already */
X
X	case 0:				/* Child process */
X		/*
X		 * Cheap hack to set mode of new directory.  Since this
X		 * child process is going away anyway, we zap its umask.
X		 * FIXME, this won't suffice to set SUID, SGID, etc. on this
X		 * directory.  Does anybody care?
X		 */
X		status = umask(0);	/* Get current umask */
X		status = umask(status | (0777 & ~dmode)); /* Set for mkdir */
X		execl("/bin/mkdir", "mkdir", dpath, (char *)0);
X		_exit(-1);		/* Can't exec /bin/mkdir */
X	
X	default:			/* Parent process */
X		while (cpid != wait(&status)) ;	/* Wait for kid to finish */
X	}
X
X	if (TERM_SIGNAL(status) != 0 || TERM_VALUE(status) != 0) {
X		errno = EIO;		/* We don't know why, but */
X		return -1;		/* /bin/mkdir failed */
X	}
X
X	return 0;
X}
Xint
Xrmdir(dpath)
X	char *dpath;
X{
X	int cpid, status;
X	struct stat statbuf;
X	extern int errno;
X
X	if (stat(dpath,&statbuf) != 0) {
X		/* Stat just set errno.  We don't have to */
X		return -1;
X	}
X
X	switch (cpid = fork()) {
X
X	case -1:			/* Error in fork() */
X		return(-1);		/* Errno is set already */
X
X	case 0:				/* Child process */
X		execl("/bin/rmdir", "rmdir", dpath, (char *)0);
X		_exit(-1);		/* Can't exec /bin/mkdir */
X	
X	default:			/* Parent process */
X		while (cpid != wait(&status)) ;	/* Wait for kid to finish */
X	}
X
X	if (TERM_SIGNAL(status) != 0 || TERM_VALUE(status) != 0) {
X		errno = EIO;		/* We don't know why, but */
X		return -1;		/* /bin/mkdir failed */
X	}
X
X	return 0;
X}
X#endif
X
X#ifdef WANT_STRING
X/*
X * Translate V7 style into Sys V style.
X */
X#include <string.h>
X#ifndef __MSDOS__
X#include <memory.h>
X#endif
X
Xchar *
Xindex (s, c)
X	char *s;
X	int c;
X{
X	return (strchr (s, c));
X}
X
Xchar *
Xrindex(s,c)
Xchar *s;
Xint c;
X{
X	return strrchr(s,c);
X}
X
Xvoid
Xbcopy (s1, s2, n)
X	char *s1, *s2;
X	int n;
X{
X	(void) memcpy (s2, s1, n);
X}
X
Xvoid
Xbzero (s1, n)
X	char *s1;
X	int n;
X{
X	(void) memset(s1, 0, n);
X}
X
Xint
Xbcmp(s1, s2, n)
X	char	*s1, *s2;
X	int	n;
X{
X	return memcmp(s1, s2, n);
X}
X#endif
X
X#ifdef WANT_BZERO
X/* Minix has bcopy but not bzero, and no memset.  Thanks, Andy. */
Xvoid
Xbzero (s1, n)
X	register char *s1;
X	register int n;
X{
X	while (n--) *s1++ = '\0';
X}
X
X/* It also has no bcmp() */
Xint
Xbcmp (s1, s2, n) 
X	register char *s1,*s2;
X	register int n;
X{
X	for ( ; n-- ; ++s1, ++s2) {
X		if (*s1 != *s2) return *s1 - *s2;
X	}
X	return 0;
X}
X
X/*
X * Groan, Minix doesn't have execlp either!
X *
X * execlp(file,arg0,arg1...argn,(char *)NULL)
X * exec a program, automatically searching for the program through
X * all the directories on the PATH.
X *
X * This version is naive about variable argument lists, it assumes
X * a straightforward C calling sequence.  If your system has odd stacks
X * *and* doesn't have execlp, YOU get to fix it.
X */
Xint
Xexeclp(filename, arg0)
X	char *filename, *arg0;
X{
X	register char *p, *path;    
X	register char *fnbuffer;
X	char **argstart = &arg0;
X	struct stat statbuf;
X	extern char **environ;
X	extern int errno;
X	extern char *malloc(), *getenv(), *index();
X
X	if ((p = getenv("PATH")) == NULL) {
X		/* couldn't find path variable -- try to exec given filename */
X		return execve(filename, argstart, environ);
X	}
X
X	/*
X	 * make a place to build the filename.  We malloc larger than we
X	 * need, but we know it will fit in this.
X	 */
X	fnbuffer = malloc( strlen(p) + 1 + strlen(filename) );
X	if (fnbuffer == NULL) {
X		errno = ENOMEM;
X		return -1;
X	}
X
X	/*
X	 * try each component of the path to see if the file's there
X	 * and executable.
X	 */
X	for (path = p ; path ; path = p) {
X		/* construct full path name to try */
X		if ((p = index(path,':')) == NULL) {
X			strcpy(fnbuffer, path);
X		} else {
X			strncpy(fnbuffer, path, p-path);
X			fnbuffer[p-path] = '\0';
X			p++;		/* Skip : for next time */
X		}
X		if (strlen(fnbuffer) != 0)
X			strcat(fnbuffer,"/");
X		strcat(fnbuffer,filename);
X
X		/* check to see if file is there and is a normal file */
X		if (stat(fnbuffer, &statbuf) < 0) {
X			if (errno == ENOENT)
X				continue; /* file not there,keep on looking */
X			else
X				goto fail; /* failed for some reason, return */
X		}
X		if ( (statbuf.st_mode & S_IFMT) != S_IFREG) continue;
X
X		if (execve(fnbuffer, argstart, environ) < 0
X		    && errno != ENOENT
X		    && errno != ENOEXEC) {
X			/* failed, for some other reason besides "file
X			 * not found" or "not a.out format"
X			 */
X			goto fail;
X		}
X
X		/*
X		 * If we got error ENOEXEC, the file is executable but is
X		 * not an object file.  Try to execute it as a shell script,
X		 * returning error if we can't execute /bin/sh.
X		 *
X		 * FIXME, this code is broken in several ways.  Shell
X		 * scripts should not in general be executed by the user's
X		 * SHELL variable program.  On more mature systems, the
X		 * script can specify with #!/bin/whatever.  Also, this
X		 * code clobbers argstart[-1] if the exec of the shell
X		 * fails.
X		 */
X		if (errno == ENOEXEC) {
X			char *shell;
X
X			/* Try to execute command "sh arg0 arg1 ..." */
X			if ((shell = getenv("SHELL")) == NULL)
X				shell = "/bin/sh";
X			argstart[-1] = shell;
X			argstart[0] = fnbuffer;
X			execve(shell, &argstart[-1], environ);
X			goto fail;	/* Exec didn't work */
X		}
X
X		/* 
X		 * If we succeeded, the execve() doesn't return, so we
X		 * can only be here is if the file hasn't been found yet.
X		 * Try the next place on the path.
X		 */
X	}
X
X	/* all attempts failed to locate the file.  Give up. */
X	errno = ENOENT;
X
Xfail:
X	free(fnbuffer);
X	return -1;
X}
X#endif
X
X
X#ifdef EMUL_OPEN3
X#include "open3.h"
X/*
X * open3 -- routine to emulate the 3-argument open system
X * call that is present in most modern Unix systems.
X * This version attempts to support all the flag bits except for O_NDELAY
X * and O_APPEND, which are silently ignored.  The emulation is not as efficient
X * as the real thing (at worst, 4 system calls instead of one), but there's
X * not much I can do about that.
X *
X * Written 6/10/87 by rmtodd@uokmax
X *
X * open3(path, flag, mode)
X * Attempts to open the file specified by
X * the given pathname.  The following flag bits (#defined in tar.h)
X * specify options to the routine:
X *	O_RDONLY	file open for read only
X *	O_WRONLY	file open for write only
X *	O_RDWR		file open for both read & write
X * (Needless to say, you should only specify one of the above).
X * 	O_CREAT		file is created with specified mode if it needs to be.
X *	O_TRUNC		if file exists, it is truncated to 0 bytes
X *	O_EXCL		used with O_CREAT--routine returns error if file exists
X * Function returns file descriptor if successful, -1 and errno if not.
X */
X
X/*
X * array to give arguments to access for various modes
X * FIXME, this table depends on the specific integer values of O_XXX,
X * and also contains integers (args to 'access') that should be #define's.
X */
Xstatic int modes[] =
X	{
X		04, /* O_RDONLY */
X		02, /* O_WRONLY */
X		06, /* O_RDWR */
X		06, /* invalid but we'd better cope -- O_WRONLY+O_RDWR */
X	};
X
X/* Shut off the automatic emulation of open(), we'll need it. */
X#undef open
X
Xint
Xopen3(path, flags, mode)
Xchar *path;
Xint flags, mode;
X{
X	extern int errno;
X	int exists = 1;
X	int call_creat = 0;
X	int fd;
X	/*
X	 * We actually do the work by calling the open() or creat() system
X	 * call, depending on the flags.  Call_creat is true if we will use 
X	 * creat(), false if we will use open().
X	 */
X
X	/*
X	 * See if the file exists and is accessible in the requested mode. 
X	 *
X	 * Strictly speaking we shouldn't be using access, since access checks
X	 * against real uid, and the open call should check against euid.
X	 * Most cases real uid == euid, so it won't matter.   FIXME.
X	 * FIXME, the construction "flags & 3" and the modes table depends
X	 * on the specific integer values of the O_XXX #define's.  Foo!
X	 */
X	if (access(path,modes[flags & 3]) < 0) {
X		if (errno == ENOENT) {
X			/* the file does not exist */
X			exists = 0;
X		} else {
X			/* probably permission violation */
X			if (flags & O_EXCL) {
X				/* Oops, the file exists, we didn't want it. */
X				/* No matter what the error, claim EEXIST. */
X				errno = EEXIST;
X			}
X			return -1;
X		}
X	}
X
X	/* if we have the O_CREAT bit set, check for O_EXCL */
X	if (flags & O_CREAT) {
X		if ((flags & O_EXCL) && exists) {
X			/* Oops, the file exists and we didn't want it to. */
X			errno = EEXIST;
X			return -1;
X		}
X		/*
X		 * If the file doesn't exist, be sure to call creat() so that
X		 * it will be created with the proper mode.
X		 */
X		if (!exists) call_creat = 1;
X	} else {
X		/* If O_CREAT isn't set and the file doesn't exist, error. */
X		if (!exists) {
X			errno = ENOENT;
X			return -1;
X		}
X	}
X
X	/*
X	 * If the O_TRUNC flag is set and the file exists, we want to call
X	 * creat() anyway, since creat() guarantees that the file will be
X	 * truncated and open()-for-writing doesn't.
X	 * (If the file doesn't exist, we're calling creat() anyway and the
X	 * file will be created with zero length.)
X	 */
X	if ((flags & O_TRUNC) && exists) call_creat = 1;
X	/* actually do the call */
X	if (call_creat) {
X		/*
X		 * call creat.  May have to close and reopen the file if we
X		 * want O_RDONLY or O_RDWR access -- creat() only gives
X		 * O_WRONLY.
X		 */
X		fd = creat(path,mode);
X		if (fd < 0 || (flags & O_WRONLY)) return fd;
X		if (close(fd) < 0) return -1;
X		/* Fall out to reopen the file we've created */
X	}
X
X	/*
X	 * calling old open, we strip most of the new flags just in case.
X	 */
X	return open(path, flags & (O_RDONLY|O_WRONLY|O_RDWR|O_BINARY));
X}
X#endif
X
X#ifdef	WANT_MKNOD
X#ifdef __MSDOS__
Xtypedef int dev_t;
X#endif
X/* Fake mknod by complaining */
Xint
Xmknod(path, mode, dev)
X	char		*path;
X	unsigned short	mode;
X	dev_t		dev;
X{
X	extern int	errno;
X	int		fd;
X	
X	errno = ENXIO;		/* No such device or address */
X	return -1;		/* Just give an error */
X}
X
X/* Fake links by copying */
Xint
Xlink(path1, path2)
X	char		*path1;
X	char		*path2;
X{
X	char	buf[256];
X	int	ifd, ofd;
X	int	nrbytes;
X	int	nwbytes;
X
X	fprintf(stderr, "%s: %s: cannot link to %s, copying instead\n",
X		tar, path1, path2);
X	if ((ifd = open(path1, O_RDONLY|O_BINARY)) < 0)
X		return -1;
X	if ((ofd = creat(path2, 0666)) < 0)
X		return -1;
X	setmode(ofd, O_BINARY);
X	while ((nrbytes = read(ifd, buf, sizeof(buf))) > 0) {
X		if ((nwbytes = write(ofd, buf, nrbytes)) != nrbytes) {
X			nrbytes = -1;
X			break;
X		}
X	}
X	/* Note use of "|" rather than "||" below: we want to close
X	 * the files even if an error occurs.
X	 */
X	if ((nrbytes < 0) | (0 != close(ifd)) | (0 != close(ofd))) {
X		unlink(path2);
X		return -1;
X	}
X	return 0;
X}
X
X/* everyone owns everything on MS-DOS (or is it no one owns anything?) */
Xint
Xchown(path, uid, gid)
X	char	*path;
X	int	uid;
X	int	gid;
X{
X	return 0;
X}
X
Xint
Xgeteuid()
X{
X	return 0;
X}
X#endif	/* WANT_MKNOD */
X
X#ifdef WANT_UTILS
X/* Stash argv[0] here so panic will know what the program is called */
Xchar *myname = 0;
X
Xvoid
Xpanic(s)
Xchar *s;
X{
X	if(myname)
X		fprintf(stderr,"%s:",myname);
X	fprintf(stderr,s);
X	putc('\n',stderr);
X	exit(12);
X}
X
X
Xchar *
Xck_malloc(size)
Xsize_t size;
X{
X	char *ret;
X	char *malloc();
X
X	if(!size)
X		size++;
X	ret=malloc(size);
X	if(ret==0)
X		panic("Couldn't allocate memory");
X	return ret;
X}
X
Xchar *
Xck_realloc(ptr,size)
Xchar *ptr;
Xsize_t size;
X{
X	char *ret;
X	char *realloc();
X
X	if(!ptr)
X		ret=ck_malloc(size);
X	else
X		ret=realloc(ptr,size);
X	if(ret==0)
X		panic("Couldn't re-allocate memory");
X	return ret;
X}
X
X/* Implement a variable sized buffer of 'stuff'.  We don't know what it is,
X   nor do we care, as long as it doesn't mind being aligned on a char boundry.
X */
X
Xstruct buffer {
X	int	allocated;
X	int	length;
X	char	*b;
X};
X
X#define MIN_ALLOCATE 50
X
Xchar *
Xinit_buffer()
X{
X	struct buffer *b;
X
X	b=(struct buffer *)ck_malloc(sizeof(struct buffer));
X	b->allocated=MIN_ALLOCATE;
X	b->b=(char *)ck_malloc(MIN_ALLOCATE);
X	b->length=0;
X	return (char *)b;
X}
X
Xvoid
Xflush_buffer(bb)
Xchar *bb;
X{
X	struct buffer *b;
X
X	b=(struct buffer *)bb;
X	free(b->b);
X	b->b=0;
X	b->allocated=0;
X	b->length=0;
X	free((void *)b);
X}
X
Xvoid
Xadd_buffer(bb,p,n)
Xchar *bb;
Xchar *p;
Xint n;
X{
X	struct buffer *b;
X
X	b=(struct buffer *)bb;
X	if(b->length+n>b->allocated) {
X		b->allocated=b->length+n+MIN_ALLOCATE;
X		b->b=(char *)ck_realloc(b->b,b->allocated);
X	}
X	bcopy(p,b->b+b->length,n);
X	b->length+=n;
X}
X
Xchar *
Xget_buffer(bb)
Xchar *bb;
X{
X	struct buffer *b;
X
X	b=(struct buffer *)bb;
X	return b->b;
X}
X
Xchar *
Xmerge_sort(list,n,off,cmp)
Xchar *list;
Xint (*cmp)();
Xunsigned n;
Xint off;
X{
X	char *ret;
X
X	char *alist,*blist;
X	unsigned alength,blength;
X
X	char *tptr;
X	int tmp;
X	char **prev;
X#define NEXTOF(ptr)	(* ((char **)(((char *)(ptr))+off) ) )
X	if(n==1)
X		return list;
X	if(n==2) {
X		if((*cmp)(list,NEXTOF(list))>0) {
X			ret=NEXTOF(list);
X			NEXTOF(ret)=list;
X			NEXTOF(list)=0;
X			return ret;
X		}
X		return list;
X	}
X	alist=list;
X	alength=(n+1)/2;
X	blength=n/2;
X	for(tptr=list,tmp=(n-1)/2;tmp;tptr=NEXTOF(tptr),tmp--)
X		;
X	blist=NEXTOF(tptr);
X	NEXTOF(tptr)=0;
X
X	alist=merge_sort(alist,alength,off,cmp);
X	blist=merge_sort(blist,blength,off,cmp);
X	prev = &ret;
X	for(;alist && blist;) {
X		if((*cmp)(alist,blist)<0) {
X			tptr=NEXTOF(alist);
X			*prev = alist;
X			prev = &(NEXTOF(alist));
X			alist=tptr;
X		} else {
X			tptr=NEXTOF(blist);
X			*prev = blist;
X			prev = &(NEXTOF(blist));
X			blist=tptr;
X		}
X	}
X	if(alist)
X		*prev = alist;
X	else
X		*prev = blist;
X
X	return ret;
X}
X
Xvoid
Xck_close(fd)
Xint fd;
X{
X	if(close(fd)<0) {
X		msg_perror("can't close a file #%d",fd);
X		exit(EX_SYSTEM);
X	}
X}
X
X#include <ctype.h>
X
X/* Quote_copy_string is like quote_string, but instead of modifying the
X   string in place, it malloc-s a copy  of the string, and returns that.
X   If the string does not have to be quoted, it returns the NULL string.
X   The allocated copy can, of course, be freed with free() after the
X   caller is done with it.
X */
Xchar *
Xquote_copy_string(string)
Xchar *string;
X{
X	char	*from_here;
X	char	*to_there = 0;
X	char	*copy_buf = 0;
X	int	c;
X	int	copying = 0;
X
X	from_here=string;
X	while(*from_here) {
X		c= *from_here++;
X		if(c=='\\') {
X			if(!copying) {
X				int n;
X
X				n=(from_here-string)-1;
X				copying++;
X				copy_buf=(char *)malloc(n+5+strlen(from_here)*4);
X				if(!copy_buf)
X					return 0;
X				bcopy(string,copy_buf,n);
X				to_there=copy_buf+n;
X			}
X			*to_there++='\\';
X			*to_there++='\\';
X		} else if(isprint(c)) {
X			if(copying)
X				*to_there++= c;
X		} else {
X			if(!copying) {
X				int	n;
X
X				n=(from_here-string)-1;
X				copying++;
X				copy_buf=(char *)malloc(n+5+strlen(from_here)*4);
X				if(!copy_buf)
X					return 0;
X				bcopy(string,copy_buf,n);
X				to_there=copy_buf+n;
X			}
X			*to_there++='\\';
X			if(c=='\n') *to_there++='n';
X			else if(c=='\t') *to_there++='t';
X			else if(c=='\f') *to_there++='f';
X			else if(c=='\b') *to_there++='b';
X			else if(c=='\r') *to_there++='r';
X			else if(c=='\177') *to_there++='?';
X			else {
X				to_there[0]=(c>>6)+'0';
X				to_there[1]=((c>>3)&07)+'0';
X				to_there[2]=(c&07)+'0';
X				to_there+=3;
X			}
X		}
X	}
X	if(copying) {
X		*to_there='\0';
X		return copy_buf;
X	}
X	return (char *)0;
X}
X
X
X/* Un_quote_string takes a quoted c-string (like those produced by
X   quote_string or quote_copy_string and turns it back into the
X   un-quoted original.  This is done in place.
X */
X
X/* There is no un-quote-copy-string.  Write it yourself */
X
Xchar *un_quote_string(string)
Xchar *string;
X{
X	char *ret;
X	char *from_here;
X	char *to_there;
X	int	tmp;
X
X	ret=string;
X	to_there=string;
X	from_here=string;
X	while(*from_here) {
X		if(*from_here!='\\') {
X			if(from_here!=to_there)
X				*to_there++= *from_here++;
X			else
X				from_here++,to_there++;
X			continue;
X		}
X		switch(*++from_here) {
X		case '\\':
X			*to_there++= *from_here++;
X			break;
X		case 'n':
X			*to_there++= '\n';
X			from_here++;
X			break;
X		case 't':
X			*to_there++= '\t';
X			from_here++;
X			break;
X		case 'f':
X			*to_there++= '\f';
X			from_here++;
X			break;
X		case 'b':
X			*to_there++= '\b';
X			from_here++;
X			break;
X		case 'r':
X			*to_there++= '\r';
X			from_here++;
X			break;
X		case '?':
X			*to_there++= 0177;
X			from_here++;
X			break;
X		case '0':
X		case '1':
X		case '2':
X		case '3':
X		case '4':
X		case '5':
X		case '6':
X		case '7':
X			tmp= *from_here - '0';
X			from_here++;
X			if(*from_here<'0' || *from_here>'7') {
X				*to_there++= tmp;
X				break;
X			}
X			tmp= tmp*8 + *from_here-'0';
X			from_here++;
X			if(*from_here<'0' || *from_here>'7') {
X				*to_there++= tmp;
X				break;
X			}
X			tmp=tmp*8 + *from_here-'0';
X			from_here++;
X			*to_there=tmp;
X			break;
X		default:
X			ret=0;
X			*to_there++='\\';
X			*to_there++= *from_here++;
X			break;
X		}
X	}
X	if(*to_there)
X		*to_there++='\0';
X	return ret;
X}
X#endif
X
X#ifdef WANT_CK_PIPE
Xvoid ck_pipe(pipes)
Xint *pipes;
X{
X	if(pipe(pipes)<0) {
X		msg_perror("can't open a pipe");
X		exit(EX_SYSTEM);
X	}
X}
X
X#endif
X
X#ifdef WANT_GETWD
Xchar *
Xgetwd(path)
Xchar *path;
X{
X	FILE *fp;
X	FILE *popen();
X
X	fp=popen("pwd","r");
X	if(!fp)
X		return 0;
X	if(!fgets(path,100,fp))
X		return 0;
X	if(!pclose(fp))
X		return 0;
X	return path;
X}
X#endif /* WANT_CK_PIPE */
X
X
X#ifdef WANT_STRSTR
X
X/*
X * strstr - find first occurrence of wanted in s
X */
X
Xchar *				/* found string, or NULL if none */
Xstrstr(s, wanted)
Xchar *s;
Xchar *wanted;
X{
X	register char *scan;
X	register size_t len;
X	register char firstc;
X	extern int strcmp();
X
X	if (*wanted == '\0')
X	  return (char *)0;
X	/*
X	 * The odd placement of the two tests is so "" is findable.
X	 * Also, we inline the first char for speed.
X	 * The ++ on scan has been moved down for optimization.
X	 */
X	firstc = *wanted;
X	len = strlen(wanted);
X	for (scan = s; *scan != firstc || strncmp(scan, wanted, len) != 0; )
X		if (*scan++ == '\0')
X			return (char *)0;
X	return scan;
X}
X#endif
X
X#ifdef WANT_FTRUNCATE
X
X#ifdef F_FREESP
X/* code courtesy of William Kucharski */
X
Xint
Xftruncate(fd, length)
Xint fd;                       /* file descriptor */
Xoff_t length;         /* length to set file to */
X{
X	struct flock fl;
X
X	fl.l_whence = 0;
X	fl.l_len = 0;
X	fl.l_start = length;
X	fl.l_type = F_WRLCK;    /* write lock on file space */
X
X	/*
X	 * This relies on the UNDOCUMENTED F_FREESP argument to
X	 * fcntl(2), which truncates the file so that it ends at the
X	 * position indicated by fl.l_start.
X	 *
X	 * Will minor miracles never cease?
X	 */
X
X	if (fcntl(fd, F_FREESP, &fl) < 0)
X	    return -1;
X
X	return 0;
X}
X
X
X#else
Xint
Xftruncate(fd, length)
Xint fd;
Xoff_t length;
X{
X	errno = EIO;
X	return -1;
X}
X#endif
X
X#endif
X
X
X
X
Xextern FILE *msg_file;
X
X#ifdef STDC_MSG
X#include <stdarg.h>
X
Xvoid
Xmsg(char *str,...)
X{
X	va_list args;
X
X	va_start(args,str);
X	fflush(msg_file);
X	fprintf(stderr,"%s: ",tar);
X	if(f_sayblock)
X		fprintf(stderr,"rec %d: ",baserec + (ar_record - ar_block));
X	vfprintf(stderr,str,args);
X	va_end(args);
X	putc('\n',stderr);
X	fflush(stderr);
X}
X
Xvoid
Xmsg_perror(char *str,...)
X{
X	va_list args;
X	int save_e;
X	extern int errno;
X
X	save_e=errno;
X	fflush(msg_file);
X	fprintf(stderr,"%s: ",tar);
X	if(f_sayblock)
X		fprintf(stderr,"rec %d: ",baserec + (ar_record - ar_block));
X	va_start(args,str);
X	vfprintf(stderr,str,args);
X	va_end(args);
X	errno=save_e;
X	perror(" ");
X	fflush(stderr);
X}
X#endif
X
X#ifdef VARARGS_MSG
X#include <varargs.h>
Xvoid msg(str,va_alist)
Xchar *str;
Xva_dcl
X{
X	va_list args;
X
X	fflush(msg_file);
X	fprintf(stderr,"%s: ",tar);
X	if(f_sayblock)
X		fprintf(stderr,"rec %d: ",baserec + (ar_record - ar_block));
X	va_start(args);
X	vfprintf(stderr,str,args);
X	va_end(args);
X	putc('\n',stderr);
X	fflush(stderr);
X}
X
Xvoid msg_perror(str,va_alist)
Xchar *str;
Xva_dcl
X{
X	va_list args;
X	int save_e;
X	extern int errno;
X
X	save_e=errno;
X	fflush(msg_file);
X	fprintf(stderr,"%s: ",tar);
X	if(f_sayblock)
X		fprintf(stderr,"rec %d: ",baserec + (ar_record - ar_block));
X	va_start(args);
X	vfprintf(stderr,str,args);
X	va_end(args);
X	errno=save_e;
X	perror(" ");
X	fflush(stderr);
X}
X#endif
X
X#ifdef DOPRNT_MSG
Xvoid msg(str,args)
Xchar *str;
Xint args;
X{
X	fflush(msg_file);
X	fprintf(stderr,"%s: ",tar);
X	if(f_sayblock)
X		fprintf(stderr,"rec %d: ",baserec + (ar_record - ar_block));
X	_doprnt(str, &args, stderr);
X	putc('\n',stderr);
X	fflush(stderr);
X}
X
Xvoid msg_perror(str,args)
Xchar *str;
X{
X	int save_e;
X	extern int errno;
X
X	save_e=errno;
X	fflush(msg_file);
X	fprintf(stderr,"%s: ",tar);
X	if(f_sayblock)
X		fprintf(stderr,"rec %d: ",baserec + (ar_record - ar_block));
X	_doprnt(str, &args, stderr);
X	errno=save_e;
X	perror(" ");
X	fflush(stderr);
X}
X
X#endif
X#ifdef LOSING_MSG
Xvoid msg(str,a1,a2,a3,a4,a5,a6)
Xchar *str;
X{
X	fflush(msg_file);
X	fprintf(stderr,"%s: ",tar);
X	if(f_sayblock)
X		fprintf(stderr,"rec %d: ",baserec + (ar_record - ar_block));
X	fprintf(stderr,str,a1,a2,a3,a4,a5,a6);
X	putc('\n',stderr);
X	fflush(stderr);
X}
X
Xvoid msg_perror(str,a1,a2,a3,a4,a5,a6)
Xchar *str;
X{
X	int save_e;
X	extern int errno;
X
X	save_e=errno;
X	fflush(msg_file);
X	fprintf(stderr,"%s: ",tar);
X	if(f_sayblock)
X		fprintf(stderr,"rec %d: ",baserec + (ar_record - ar_block));
X	fprintf(stderr,str,a1,a2,a3,a4,a5,a6);
X	fprintf(stderr,": ");
X	errno=save_e;
X	perror(" ");
X}
X
X#endif
END_OF_FILE
if test 27532 -ne `wc -c <'port.c'`; then
    echo shar: \"'port.c'\" unpacked with wrong size!
fi
# end of 'port.c'
fi
if test -f 'wildmat.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'wildmat.c'\"
else
echo shar: Extracting \"'wildmat.c'\" \(4206 characters\)
sed "s/^X//" >'wildmat.c' <<'END_OF_FILE'
X/* Wildcard matching routines.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/*
X * @(#)wildmat.c 1.3 87/11/06
X *
XFrom: rs@mirror.TMC.COM (Rich Salz)
XNewsgroups: net.sources
XSubject: Small shell-style pattern matcher
XMessage-ID: <596@mirror.TMC.COM>
XDate: 27 Nov 86 00:06:40 GMT
X
XThere have been several regular-expression subroutines and one or two
Xfilename-globbing routines in mod.sources.  They handle lots of
Xcomplicated patterns.  This small piece of code handles the *?[]\
Xwildcard characters the way the standard Unix(tm) shells do, with the
Xaddition that "[^.....]" is an inverse character class -- it matches
Xany character not in the range ".....".  Read the comments for more
Xinfo.
X
XFor my application, I had first ripped off a copy of the "glob" routine
Xfrom within the find source, but that code is bad news:  it recurses
Xon every character in the pattern.  I'm putting this replacement in the
Xpublic domain.  It's small, tight, and iterative.  Compile with -DTEST
Xto get a test driver.  After you're convinced it works, install in
Xwhatever way is appropriate for you.
X
XI would like to hear of bugs, but am not interested in additions; if I
Xwere, I'd use the code I mentioned above.
X*/
X/*
X**  Do shell-style pattern matching for ?, \, [], and * characters.
X**  Might not be robust in face of malformed patterns; e.g., "foo[a-"
X**  could cause a segmentation violation.
X**
X**  Written by Rich $alz, mirror!rs, Wed Nov 26 19:03:17 EST 1986.
X*/
X
X/*
X * Modified 6Nov87 by John Gilmore (hoptoad!gnu) to return a "match"
X * if the pattern is immediately followed by a "/", as well as \0.
X * This matches what "tar" does for matching whole subdirectories.
X *
X * The "*" code could be sped up by only recursing one level instead
X * of two for each trial pattern, perhaps, and not recursing at all
X * if a literal match of the next 2 chars would fail.
X */
X#define TRUE		1
X#define FALSE		0
X
X
Xstatic int
XStar(s, p)
X    register char	*s;
X    register char	*p;
X{
X    while (wildmat(s, p) == FALSE)
X	if (*++s == '\0')
X	    return(FALSE);
X    return(TRUE);
X}
X
X
Xint
Xwildmat(s, p)
X    register char	*s;
X    register char	*p;
X{
X    register int 	 last;
X    register int 	 matched;
X    register int 	 reverse;
X
X    for ( ; *p; s++, p++)
X	switch (*p) {
X	    case '\\':
X		/* Literal match with following character; fall through. */
X		p++;
X	    default:
X		if (*s != *p)
X		    return(FALSE);
X		continue;
X	    case '?':
X		/* Match anything. */
X		if (*s == '\0')
X		    return(FALSE);
X		continue;
X	    case '*':
X		/* Trailing star matches everything. */
X		return(*++p ? Star(s, p) : TRUE);
X	    case '[':
X		/* [^....] means inverse character class. */
X		if (reverse = p[1] == '^')
X		    p++;
X		for (last = 0400, matched = FALSE; *++p && *p != ']'; last = *p)
X		    /* This next line requires a good C compiler. */
X		    if (*p == '-' ? *s <= *++p && *s >= last : *s == *p)
X			matched = TRUE;
X		if (matched == reverse)
X		    return(FALSE);
X		continue;
X	}
X
X    /* For "tar" use, matches that end at a slash also work. --hoptoad!gnu */
X    return(*s == '\0' || *s == '/');
X}
X
X
X#ifdef	TEST
X#include <stdio.h>
X
Xextern char	*gets();
X
X
Xmain()
X{
X    char	 pattern[80];
X    char	 text[80];
X
X    while (TRUE) {
X	printf("Enter pattern:  ");
X	if (gets(pattern) == NULL)
X	    break;
X	while (TRUE) {
X	    printf("Enter text:  ");
X	    if (gets(text) == NULL)
X		exit(0);
X	    if (text[0] == '\0')
X		/* Blank line; go back and get a new pattern. */
X		break;
X	    printf("      %d\n", wildmat(text, pattern));
X	}
X    }
X    exit(0);
X}
X#endif	/* TEST */
END_OF_FILE
if test 4206 -ne `wc -c <'wildmat.c'`; then
    echo shar: \"'wildmat.c'\" unpacked with wrong size!
fi
# end of 'wildmat.c'
fi
if test -f 'getopt.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'getopt.c'\"
else
echo shar: Extracting \"'getopt.c'\" \(17079 characters\)
sed "s/^X//" >'getopt.c' <<'END_OF_FILE'
X/* Getopt for GNU.
X   Copyright (C) 1987, 1989, 1990, 1991 Free Software Foundation, Inc.
X
X   This program is free software; you can redistribute it and/or modify
X   it under the terms of the GNU General Public License as published by
X   the Free Software Foundation; either version 2, or (at your option)
X   any later version.
X
X   This program is distributed in the hope that it will be useful,
X   but WITHOUT ANY WARRANTY; without even the implied warranty of
X   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
X   GNU General Public License for more details.
X
X   You should have received a copy of the GNU General Public License
X   along with this program; if not, write to the Free Software
X   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X#ifdef __STDC__
X#define CONST const
X#else
X#define CONST
X#endif
X
X/* This version of `getopt' appears to the caller like standard Unix `getopt'
X   but it behaves differently for the user, since it allows the user
X   to intersperse the options with the other arguments.
X
X   As `getopt' works, it permutes the elements of `argv' so that,
X   when it is done, all the options precede everything else.  Thus
X   all application programs are extended to handle flexible argument order.
X
X   Setting the environment variable _POSIX_OPTION_ORDER disables permutation.
X   Then the behavior is completely standard.
X
X   GNU application programs can use a third alternative mode in which
X   they can distinguish the relative order of options and other arguments.  */
X
X#include <stdio.h>
X
X/* If compiled with GNU C, use the built-in alloca */
X#ifdef __GNUC__
X#define alloca __builtin_alloca
X#else /* not __GNUC__ */
X#ifdef sparc
X#include <alloca.h>
X#else
X#ifdef _AIX
X#pragma alloca
X#else
Xchar *alloca ();
X#endif
X#endif /* sparc */
X#endif /* not __GNUC__ */
X
X#if defined(STDC_HEADERS) || defined(__GNU_LIBRARY__)
X#include <stdlib.h>
X#else /* STDC_HEADERS or __GNU_LIBRARY__ */
Xchar *getenv ();
Xchar *malloc ();
X#endif /* STDC_HEADERS or __GNU_LIBRARY__ */
X
X#if defined(USG) || defined(STDC_HEADERS) || defined(__GNU_LIBRARY__)
X#include <string.h>
X#define bcopy(s, d, n) memcpy ((d), (s), (n))
X#define index strchr
X#else /* USG or STDC_HEADERS or __GNU_LIBRARY__ */
X#ifdef VMS
X#include <string.h>
X#else /* VMS */
X#include <strings.h>
X#endif /* VMS */
X/* Declaring bcopy causes errors on systems whose declarations are different.
X   If the declaration is omitted, everything works fine.  */
X#endif /* USG or STDC_HEADERS or __GNU_LIBRARY__ */
X
X/* For communication from `getopt' to the caller.
X   When `getopt' finds an option that takes an argument,
X   the argument value is returned here.
X   Also, when `ordering' is RETURN_IN_ORDER,
X   each non-option ARGV-element is returned here.  */
X
Xchar *optarg = 0;
X
X/* Index in ARGV of the next element to be scanned.
X   This is used for communication to and from the caller
X   and for communication between successive calls to `getopt'.
X
X   On entry to `getopt', zero means this is the first call; initialize.
X
X   When `getopt' returns EOF, this is the index of the first of the
X   non-option elements that the caller should itself scan.
X
X   Otherwise, `optind' communicates from one call to the next
X   how much of ARGV has been scanned so far.  */
X
Xint optind = 0;
X
X/* The next char to be scanned in the option-element
X   in which the last option character we returned was found.
X   This allows us to pick up the scan where we left off.
X
X   If this is zero, or a null string, it means resume the scan
X   by advancing to the next ARGV-element.  */
X
Xstatic char *nextchar;
X
X/* Callers store zero here to inhibit the error message
X   for unrecognized options.  */
X
Xint opterr = 1;
X
X/* Describe how to deal with options that follow non-option ARGV-elements.
X
X   If the caller did not specify anything,
X   the default is REQUIRE_ORDER if the environment variable
X   _POSIX_OPTION_ORDER is defined, PERMUTE otherwise.
X
X   REQUIRE_ORDER means don't recognize them as options;
X   stop option processing when the first non-option is seen.
X   This is what Unix does.
X   This mode of operation is selected by either setting the environment
X   variable _POSIX_OPTION_ORDER, or using `+' as the first character
X   of the list of option characters.
X
X   PERMUTE is the default.  We permute the contents of ARGV as we scan,
X   so that eventually all the non-options are at the end.  This allows options
X   to be given in any order, even with programs that were not written to
X   expect this.
X
X   RETURN_IN_ORDER is an option available to programs that were written
X   to expect options and other ARGV-elements in any order and that care about
X   the ordering of the two.  We describe each non-option ARGV-element
X   as if it were the argument of an option with character code 1.
X   Using `-' as the first character of the list of option characters
X   selects this mode of operation.
X
X   The special argument `--' forces an end of option-scanning regardless
X   of the value of `ordering'.  In the case of RETURN_IN_ORDER, only
X   `--' can cause `getopt' to return EOF with `optind' != ARGC.  */
X
Xstatic enum
X{
X  REQUIRE_ORDER, PERMUTE, RETURN_IN_ORDER
X} ordering;
X
X/* Describe the long-named options requested by the application.
X   _GETOPT_LONG_OPTIONS is a vector of `struct option' terminated by an
X   element containing a name which is zero.
X   The field `has_arg' is 1 if the option takes an argument,
X   2 if it takes an optional argument.  */
X
Xstruct option
X{
X  char *name;
X  int has_arg;
X  int *flag;
X  int val;
X};
X
XCONST struct option *_getopt_long_options;
X
Xint _getopt_long_only = 0;
X
X/* Index in _GETOPT_LONG_OPTIONS of the long-named option actually found.
X   Only valid when a long-named option was found. */
X
Xint option_index;
X
X/* Handle permutation of arguments.  */
X
X/* Describe the part of ARGV that contains non-options that have
X   been skipped.  `first_nonopt' is the index in ARGV of the first of them;
X   `last_nonopt' is the index after the last of them.  */
X
Xstatic int first_nonopt;
Xstatic int last_nonopt;
X
X/* Exchange two adjacent subsequences of ARGV.
X   One subsequence is elements [first_nonopt,last_nonopt)
X    which contains all the non-options that have been skipped so far.
X   The other is elements [last_nonopt,optind), which contains all
X    the options processed since those non-options were skipped.
X
X   `first_nonopt' and `last_nonopt' are relocated so that they describe
X    the new indices of the non-options in ARGV after they are moved.  */
X
Xstatic void
Xexchange (argv)
X     char **argv;
X{
X  int nonopts_size = (last_nonopt - first_nonopt) * sizeof (char *);
X  char **temp = (char **) alloca (nonopts_size);
X
X  /* Interchange the two blocks of data in ARGV.  */
X
X  bcopy (&argv[first_nonopt], temp, nonopts_size);
X  bcopy (&argv[last_nonopt], &argv[first_nonopt],
X	 (optind - last_nonopt) * sizeof (char *));
X  bcopy (temp, &argv[first_nonopt + optind - last_nonopt], nonopts_size);
X
X  /* Update records for the slots the non-options now occupy.  */
X
X  first_nonopt += (optind - last_nonopt);
X  last_nonopt = optind;
X}
X
X/* Scan elements of ARGV (whose length is ARGC) for option characters
X   given in OPTSTRING.
X
X   If an element of ARGV starts with '-', and is not exactly "-" or "--",
X   then it is an option element.  The characters of this element
X   (aside from the initial '-') are option characters.  If `getopt'
X   is called repeatedly, it returns successively each of the option characters
X   from each of the option elements.
X
X   If `getopt' finds another option character, it returns that character,
X   updating `optind' and `nextchar' so that the next call to `getopt' can
X   resume the scan with the following option character or ARGV-element.
X
X   If there are no more option characters, `getopt' returns `EOF'.
X   Then `optind' is the index in ARGV of the first ARGV-element
X   that is not an option.  (The ARGV-elements have been permuted
X   so that those that are not options now come last.)
X
X   OPTSTRING is a string containing the legitimate option characters.
X   If an option character is seen that is not listed in OPTSTRING,
X   return '?' after printing an error message.  If you set `opterr' to
X   zero, the error message is suppressed but we still return '?'.
X
X   If a char in OPTSTRING is followed by a colon, that means it wants an arg,
X   so the following text in the same ARGV-element, or the text of the following
X   ARGV-element, is returned in `optarg'.  Two colons mean an option that
X   wants an optional arg; if there is text in the current ARGV-element,
X   it is returned in `optarg', otherwise `optarg' is set to zero.
X
X   If OPTSTRING starts with `-' or `+', it requests different methods of
X   handling the non-option ARGV-elements.
X   See the comments about RETURN_IN_ORDER and REQUIRE_ORDER, above.
X
X   Long-named options begin with `+' instead of `-'.
X   Their names may be abbreviated as long as the abbreviation is unique
X   or is an exact match for some defined option.  If they have an
X   argument, it follows the option name in the same ARGV-element, separated
X   from the option name by a `=', or else the in next ARGV-element.
X   When `getopt' finds a long-named option, it returns 0 if that option's
X   `flag' field is nonzero, the value of the option's `val' field
X   otherwise.  */
X
Xint
Xgetopt (argc, argv, optstring)
X     int argc;
X     char **argv;
X     CONST char *optstring;
X{
X  optarg = 0;
X
X  /* Initialize the internal data when the first call is made.
X     Start processing options with ARGV-element 1 (since ARGV-element 0
X     is the program name); the sequence of previously skipped
X     non-option ARGV-elements is empty.  */
X
X  if (optind == 0)
X    {
X      first_nonopt = last_nonopt = optind = 1;
X
X      nextchar = 0;
X
X      /* Determine how to handle the ordering of options and nonoptions.  */
X
X      if (optstring[0] == '-')
X	{
X	  ordering = RETURN_IN_ORDER;
X	  ++optstring;
X	}
X      else if (optstring[0] == '+')
X	{
X	  ordering = REQUIRE_ORDER;
X	  ++optstring;
X	}
X      else if (getenv ("_POSIX_OPTION_ORDER") != 0)
X	ordering = REQUIRE_ORDER;
X      else
X	ordering = PERMUTE;
X    }
X
X  if (nextchar == 0 || *nextchar == 0)
X    {
X      if (ordering == PERMUTE)
X	{
X	  /* If we have just processed some options following some non-options,
X	     exchange them so that the options come first.  */
X
X	  if (first_nonopt != last_nonopt && last_nonopt != optind)
X	    exchange (argv);
X	  else if (last_nonopt != optind)
X	    first_nonopt = optind;
X
X	  /* Now skip any additional non-options
X	     and extend the range of non-options previously skipped.  */
X
X	  while (optind < argc
X		 && (argv[optind][0] != '-'
X		     || argv[optind][1] == 0)
X		 && (_getopt_long_options == 0
X		     || argv[optind][0] != '+'
X		     || argv[optind][1] == 0))
X	    optind++;
X	  last_nonopt = optind;
X	}
X
X      /* Special ARGV-element `--' means premature end of options.
X	 Skip it like a null option,
X	 then exchange with previous non-options as if it were an option,
X	 then skip everything else like a non-option.  */
X
X      if (optind != argc && !strcmp (argv[optind], "--"))
X	{
X	  optind++;
X
X	  if (first_nonopt != last_nonopt && last_nonopt != optind)
X	    exchange (argv);
X	  else if (first_nonopt == last_nonopt)
X	    first_nonopt = optind;
X	  last_nonopt = argc;
X
X	  optind = argc;
X	}
X
X      /* If we have done all the ARGV-elements, stop the scan
X	 and back over any non-options that we skipped and permuted.  */
X
X      if (optind == argc)
X	{
X	  /* Set the next-arg-index to point at the non-options
X	     that we previously skipped, so the caller will digest them.  */
X	  if (first_nonopt != last_nonopt)
X	    optind = first_nonopt;
X	  return EOF;
X	}
X
X      /* If we have come to a non-option and did not permute it,
X	 either stop the scan or describe it to the caller and pass it by.  */
X
X      if ((argv[optind][0] != '-' || argv[optind][1] == 0)
X	  && (_getopt_long_options == 0
X	      || argv[optind][0] != '+' || argv[optind][1] == 0))
X	{
X	  if (ordering == REQUIRE_ORDER)
X	    return EOF;
X	  optarg = argv[optind++];
X	  return 1;
X	}
X
X      /* We have found another option-ARGV-element.
X	 Start decoding its characters.  */
X
X      nextchar = argv[optind] + 1;
X    }
X
X  if (_getopt_long_options != 0
X      && (argv[optind][0] == '+'
X	  || (_getopt_long_only && argv[optind][0] == '-'))
X    )
X    {
X      CONST struct option *p;
X      char *s = nextchar;
X      int exact = 0;
X      int ambig = 0;
X      CONST struct option *pfound = 0;
X      int indfound;
X
X      while (*s && *s != '=')
X	s++;
X
X      /* Test all options for either exact match or abbreviated matches.  */
X      for (p = _getopt_long_options, option_index = 0; p->name;
X	   p++, option_index++)
X	if (!strncmp (p->name, nextchar, s - nextchar))
X	  {
X	    if (s - nextchar == strlen (p->name))
X	      {
X		/* Exact match found.  */
X		pfound = p;
X		indfound = option_index;
X		exact = 1;
X		break;
X	      }
X	    else if (pfound == 0)
X	      {
X		/* First nonexact match found.  */
X		pfound = p;
X		indfound = option_index;
X	      }
X	    else
X	      /* Second nonexact match found.  */
X	      ambig = 1;
X	  }
X
X      if (ambig && !exact)
X	{
X	  fprintf (stderr, "%s: option `%s' is ambiguous\n",
X		   argv[0], argv[optind]);
X	  nextchar += strlen (nextchar);
X	  optind++;
X	  return '?';
X	}
X
X      if (pfound != 0)
X	{
X	  option_index = indfound;
X	  optind++;
X	  if (*s)
X	    {
X	      if (pfound->has_arg > 0)
X		optarg = s + 1;
X	      else
X		{
X		  fprintf (stderr,
X			   "%s: option `%c%s' doesn't allow an argument\n",
X			   argv[0], argv[optind - 1][0], pfound->name);
X		  nextchar += strlen (nextchar);
X		  return '?';
X		}
X	    }
X	  else if (pfound->has_arg == 1)
X	    {
X	      if (optind < argc)
X		optarg = argv[optind++];
X	      else
X		{
X		  fprintf (stderr, "%s: option `%s' requires an argument\n",
X			   argv[0], argv[optind - 1]);
X		  nextchar += strlen (nextchar);
X		  return '?';
X		}
X	    }
X	  nextchar += strlen (nextchar);
X	  if (pfound->flag)
X	    {
X	      *(pfound->flag) = pfound->val;
X	      return 0;
X	    }
X	  return pfound->val;
X	}
X      /* Can't find it as a long option.  If this is getopt_long_only,
X	 and the option starts with '-' and is a valid short
X	 option, then interpret it as a short option.  Otherwise it's
X	 an error.  */
X      if (_getopt_long_only == 0 || argv[optind][0] == '+' ||
X	  index (optstring, *nextchar) == 0)
X	{
X	  if (opterr != 0)
X	    fprintf (stderr, "%s: unrecognized option `%c%s'\n",
X		     argv[0], argv[optind][0], nextchar);
X	  nextchar += strlen (nextchar);
X	  optind++;
X	  return '?';
X	}
X    }
X
X  /* Look at and handle the next option-character.  */
X
X  {
X    char c = *nextchar++;
X    char *temp = index (optstring, c);
X
X    /* Increment `optind' when we start to process its last character.  */
X    if (*nextchar == 0)
X      optind++;
X
X    if (temp == 0 || c == ':')
X      {
X	if (opterr != 0)
X	  {
X	    if (c < 040 || c >= 0177)
X	      fprintf (stderr, "%s: unrecognized option, character code 0%o\n",
X		       argv[0], c);
X	    else
X	      fprintf (stderr, "%s: unrecognized option `-%c'\n",
X		       argv[0], c);
X	  }
X	return '?';
X      }
X    if (temp[1] == ':')
X      {
X	if (temp[2] == ':')
X	  {
X	    /* This is an option that accepts an argument optionally.  */
X	    if (*nextchar != 0)
X	      {
X		optarg = nextchar;
X		optind++;
X	      }
X	    else
X	      optarg = 0;
X	    nextchar = 0;
X	  }
X	else
X	  {
X	    /* This is an option that requires an argument.  */
X	    if (*nextchar != 0)
X	      {
X		optarg = nextchar;
X		/* If we end this ARGV-element by taking the rest as an arg,
X		   we must advance to the next element now.  */
X		optind++;
X	      }
X	    else if (optind == argc)
X	      {
X		if (opterr != 0)
X		  fprintf (stderr, "%s: option `-%c' requires an argument\n",
X			   argv[0], c);
X		c = '?';
X	      }
X	    else
X	      /* We already incremented `optind' once;
X		 increment it again when taking next ARGV-elt as argument.  */
X	      optarg = argv[optind++];
X	    nextchar = 0;
X	  }
X      }
X    return c;
X  }
X}
X
X#ifdef TEST
X
X/* Compile with -DTEST to make an executable for use in testing
X   the above definition of `getopt'.  */
X
Xint
Xmain (argc, argv)
X     int argc;
X     char **argv;
X{
X  int c;
X  int digit_optind = 0;
X
X  while (1)
X    {
X      int this_option_optind = optind ? optind : 1;
X
X      c = getopt (argc, argv, "abc:d:0123456789");
X      if (c == EOF)
X	break;
X
X      switch (c)
X	{
X	case '0':
X	case '1':
X	case '2':
X	case '3':
X	case '4':
X	case '5':
X	case '6':
X	case '7':
X	case '8':
X	case '9':
X	  if (digit_optind != 0 && digit_optind != this_option_optind)
X	    printf ("digits occur in two different argv-elements.\n");
X	  digit_optind = this_option_optind;
X	  printf ("option %c\n", c);
X	  break;
X
X	case 'a':
X	  printf ("option a\n");
X	  break;
X
X	case 'b':
X	  printf ("option b\n");
X	  break;
X
X	case 'c':
X	  printf ("option c with value `%s'\n", optarg);
X	  break;
X
X	case '?':
X	  break;
X
X	default:
X	  printf ("?? getopt returned character code 0%o ??\n", c);
X	}
X    }
X
X  if (optind < argc)
X    {
X      printf ("non-option ARGV-elements: ");
X      while (optind < argc)
X	printf ("%s ", argv[optind++]);
X      printf ("\n");
X    }
X
X  exit (0);
X}
X
X#endif /* TEST */
END_OF_FILE
if test 17079 -ne `wc -c <'getopt.c'`; then
    echo shar: \"'getopt.c'\" unpacked with wrong size!
fi
# end of 'getopt.c'
fi
if test -f 'getopt1.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'getopt1.c'\"
else
echo shar: Extracting \"'getopt1.c'\" \(3394 characters\)
sed "s/^X//" >'getopt1.c' <<'END_OF_FILE'
X/* Getopt for GNU.
X   Copyright (C) 1987, 1989, 1991 Free Software Foundation, Inc.
X
X   This program is free software; you can redistribute it and/or modify
X   it under the terms of the GNU General Public License as published by
X   the Free Software Foundation; either version 2, or (at your option)
X   any later version.
X
X   This program is distributed in the hope that it will be useful,
X   but WITHOUT ANY WARRANTY; without even the implied warranty of
X   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
X   GNU General Public License for more details.
X
X   You should have received a copy of the GNU General Public License
X   along with this program; if not, write to the Free Software
X   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X#include "getopt.h"
X
X#ifdef __STDC__
X#define CONST const
X#else
X#define CONST
X#endif
X
X#if !defined (NULL)
X#define NULL 0
X#endif
X
Xint
Xgetopt_long (argc, argv, options, long_options, opt_index)
X     int argc;
X     char **argv;
X     CONST char *options;
X     CONST struct option *long_options;
X     int *opt_index;
X{
X  int val;
X
X  _getopt_long_options = long_options;
X  val = getopt (argc, argv, options);
X  if (val == 0 && opt_index != NULL)
X    *opt_index = option_index;
X  return val;
X}
X
X/* Like getopt_long, but '-' as well as '+' can indicate a long option.
X   If an option that starts with '-' doesn't match a long option,
X   but does match a short option, it is parsed as a short option
X   instead. */
X
Xint 
Xgetopt_long_only (argc, argv, options, long_options, opt_index)
X     int argc;
X     char **argv;
X     CONST char *options;
X     CONST struct option *long_options;
X     int *opt_index;
X{
X  int val;
X
X  _getopt_long_options = long_options;
X  _getopt_long_only = 1;
X  val = getopt (argc, argv, options);
X  if (val == 0 && opt_index != NULL)
X    *opt_index = option_index;
X  return val;
X}
X
X
X#ifdef TEST
X
X#include <stdio.h>
X
Xint
Xmain (argc, argv)
X     int argc;
X     char **argv;
X{
X  int c;
X  int digit_optind = 0;
X
X  while (1)
X    {
X      int this_option_optind = optind ? optind : 1;
X      char *name = '\0';
X      int option_index = 0;
X      static struct option long_options[] =
X      {
X	{"add", 1, 0, 0},
X	{"append", 0, 0, 0},
X	{"delete", 1, 0, 0},
X	{"verbose", 0, 0, 0},
X	{"create", 0, 0, 0},
X	{"file", 1, 0, 0},
X	{0, 0, 0, 0}
X      };
X
X      c = getopt_long (argc, argv, "abc:d:0123456789",
X		       long_options, &option_index);
X      if (c == EOF)
X	break;
X
X      switch (c)
X	{
X	case 0:
X	  printf ("option %s", (long_options[option_index]).name);
X	  if (optarg)
X	    printf (" with arg %s", optarg);
X	  printf ("\n");
X	  break;
X
X	case '0':
X	case '1':
X	case '2':
X	case '3':
X	case '4':
X	case '5':
X	case '6':
X	case '7':
X	case '8':
X	case '9':
X	  if (digit_optind != 0 && digit_optind != this_option_optind)
X	    printf ("digits occur in two different argv-elements.\n");
X	  digit_optind = this_option_optind;
X	  printf ("option %c\n", c);
X	  break;
X
X	case 'a':
X	  printf ("option a\n");
X	  break;
X
X	case 'b':
X	  printf ("option b\n");
X	  break;
X
X	case 'c':
X	  printf ("option c with value `%s'\n", optarg);
X	  break;
X
X	case '?':
X	  break;
X
X	default:
X	  printf ("?? getopt returned character code 0%o ??\n", c);
X	}
X    }
X
X  if (optind < argc)
X    {
X      printf ("non-option ARGV-elements: ");
X      while (optind < argc)
X	printf ("%s ", argv[optind++]);
X      printf ("\n");
X    }
X
X  exit (0);
X}
X
X#endif /* TEST */
END_OF_FILE
if test 3394 -ne `wc -c <'getopt1.c'`; then
    echo shar: \"'getopt1.c'\" unpacked with wrong size!
fi
# end of 'getopt1.c'
fi
if test -f 'regex.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'regex.c'\"
else
echo shar: Extracting \"'regex.c'\" \(83766 characters\)
sed "s/^X//" >'regex.c' <<'END_OF_FILE'
X/* Extended regular expression matching and search library.
X   Copyright (C) 1985, 1989-90 Free Software Foundation, Inc.
X
X   This program is free software; you can redistribute it and/or modify
X   it under the terms of the GNU General Public License as published by
X   the Free Software Foundation; either version 2, or (at your option)
X   any later version.
X
X   This program is distributed in the hope that it will be useful,
X   but WITHOUT ANY WARRANTY; without even the implied warranty of
X   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
X   GNU General Public License for more details.
X
X   You should have received a copy of the GNU General Public License
X   along with this program; if not, write to the Free Software
X   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X
X/* To test, compile with -Dtest.  This Dtestable feature turns this into
X   a self-contained program which reads a pattern, describes how it
X   compiles, then reads a string and searches for it.
X   
X   On the other hand, if you compile with both -Dtest and -Dcanned you
X   can run some tests we've already thought of.  */
X
X
X#ifdef emacs
X
X/* The `emacs' switch turns on certain special matching commands
X  that make sense only in emacs. */
X
X#include "config.h"
X#include "lisp.h"
X#include "buffer.h"
X#include "syntax.h"
X
X#else  /* not emacs */
X
X#if defined (USG) || defined (STDC_HEADERS)
X#ifndef BSTRING
X#include <string.h>
X#define bcopy(s,d,n)	memcpy((d),(s),(n))
X#define bcmp(s1,s2,n)	memcmp((s1),(s2),(n))
X#define bzero(s,n)	memset((s),0,(n))
X#endif
X#endif
X
X#ifdef STDC_HEADERS
X#include <stdlib.h>
X#else
Xchar *malloc ();
Xchar *realloc ();
X#endif
X
X/* Make alloca work the best possible way.  */
X#ifdef __GNUC__
X#define alloca __builtin_alloca
X#else
X#ifdef sparc
X#include <alloca.h>
X#else
X#ifdef _AIX
X#pragma alloca
X#else
Xchar *alloca ();
X#endif
X#endif
X#endif
X
X
X/* Define the syntax stuff, so we can do the \<, \>, etc.  */
X
X/* This must be nonzero for the wordchar and notwordchar pattern
X   commands in re_match_2.  */
X#ifndef Sword 
X#define Sword 1
X#endif
X
X#define SYNTAX(c) re_syntax_table[c]
X
X
X#ifdef SYNTAX_TABLE
X
Xchar *re_syntax_table;
X
X#else /* not SYNTAX_TABLE */
X
Xstatic char re_syntax_table[256];
X
X
Xstatic void
Xinit_syntax_once ()
X{
X   register int c;
X   static int done = 0;
X
X   if (done)
X     return;
X
X   bzero (re_syntax_table, sizeof re_syntax_table);
X
X   for (c = 'a'; c <= 'z'; c++)
X     re_syntax_table[c] = Sword;
X
X   for (c = 'A'; c <= 'Z'; c++)
X     re_syntax_table[c] = Sword;
X
X   for (c = '0'; c <= '9'; c++)
X     re_syntax_table[c] = Sword;
X
X   done = 1;
X}
X
X#endif /* SYNTAX_TABLE */
X#endif /* emacs */
X
X/* We write fatal error messages on standard error.  */
X#include <stdio.h>
X
X/* isalpha(3) etc. are used for the character classes.  */
X#include <ctype.h>
X/* Sequents are missing isgraph.  */
X#ifndef isgraph
X#define isgraph(c) (isprint((c)) && !isspace((c)))
X#endif
X
X/* Get the interface, including the syntax bits.  */
X#include "regex.h"
X
X
X/* These are the command codes that appear in compiled regular
X   expressions, one per byte.  Some command codes are followed by
X   argument bytes.  A command code can specify any interpretation
X   whatsoever for its arguments.  Zero-bytes may appear in the compiled
X   regular expression.
X   
X   The value of `exactn' is needed in search.c (search_buffer) in emacs.
X   So regex.h defines a symbol `RE_EXACTN_VALUE' to be 1; the value of
X   `exactn' we use here must also be 1.  */
X
Xenum regexpcode
X  {
X    unused=0,
X    exactn=1, /* Followed by one byte giving n, then by n literal bytes.  */
X    begline,  /* Fail unless at beginning of line.  */
X    endline,  /* Fail unless at end of line.  */
X    jump,     /* Followed by two bytes giving relative address to jump to.  */
X    on_failure_jump,	 /* Followed by two bytes giving relative address of 
X			    place to resume at in case of failure.  */
X    finalize_jump,	 /* Throw away latest failure point and then jump to 
X			    address.  */
X    maybe_finalize_jump, /* Like jump but finalize if safe to do so.
X			    This is used to jump back to the beginning
X			    of a repeat.  If the command that follows
X			    this jump is clearly incompatible with the
X			    one at the beginning of the repeat, such that
X			    we can be sure that there is no use backtracking
X			    out of repetitions already completed,
X			    then we finalize.  */
X    dummy_failure_jump,  /* Jump, and push a dummy failure point. This 
X			    failure point will be thrown away if an attempt 
X                            is made to use it for a failure. A + construct 
X                            makes this before the first repeat.  Also
X                            use it as an intermediary kind of jump when
X                            compiling an or construct.  */
X    succeed_n,	 /* Used like on_failure_jump except has to succeed n times;
X		    then gets turned into an on_failure_jump. The relative
X                    address following it is useless until then.  The
X                    address is followed by two bytes containing n.  */
X    jump_n,	 /* Similar to jump, but jump n times only; also the relative
X		    address following is in turn followed by yet two more bytes
X                    containing n.  */
X    set_number_at,	/* Set the following relative location to the
X			   subsequent number.  */
X    anychar,	 /* Matches any (more or less) one character.  */
X    charset,     /* Matches any one char belonging to specified set.
X		    First following byte is number of bitmap bytes.
X		    Then come bytes for a bitmap saying which chars are in.
X		    Bits in each byte are ordered low-bit-first.
X		    A character is in the set if its bit is 1.
X		    A character too large to have a bit in the map
X		    is automatically not in the set.  */
X    charset_not, /* Same parameters as charset, but match any character
X                    that is not one of those specified.  */
X    start_memory, /* Start remembering the text that is matched, for
X		    storing in a memory register.  Followed by one
X                    byte containing the register number.  Register numbers
X                    must be in the range 0 through RE_NREGS.  */
X    stop_memory, /* Stop remembering the text that is matched
X		    and store it in a memory register.  Followed by
X                    one byte containing the register number. Register
X                    numbers must be in the range 0 through RE_NREGS.  */
X    duplicate,   /* Match a duplicate of something remembered.
X		    Followed by one byte containing the index of the memory 
X                    register.  */
X    before_dot,	 /* Succeeds if before point.  */
X    at_dot,	 /* Succeeds if at point.  */
X    after_dot,	 /* Succeeds if after point.  */
X    begbuf,      /* Succeeds if at beginning of buffer.  */
X    endbuf,      /* Succeeds if at end of buffer.  */
X    wordchar,    /* Matches any word-constituent character.  */
X    notwordchar, /* Matches any char that is not a word-constituent.  */
X    wordbeg,	 /* Succeeds if at word beginning.  */
X    wordend,	 /* Succeeds if at word end.  */
X    wordbound,   /* Succeeds if at a word boundary.  */
X    notwordbound,/* Succeeds if not at a word boundary.  */
X    syntaxspec,  /* Matches any character whose syntax is specified.
X		    followed by a byte which contains a syntax code,
X                    e.g., Sword.  */
X    notsyntaxspec /* Matches any character whose syntax differs from
X                     that specified.  */
X  };
X
X 
X/* Number of failure points to allocate space for initially,
X   when matching.  If this number is exceeded, more space is allocated,
X   so it is not a hard limit.  */
X
X#ifndef NFAILURES
X#define NFAILURES 80
X#endif
X
X#ifdef CHAR_UNSIGNED
X#define SIGN_EXTEND_CHAR(c) ((c)>(char)127?(c)-256:(c)) /* for IBM RT */
X#endif
X#ifndef SIGN_EXTEND_CHAR
X#define SIGN_EXTEND_CHAR(x) (x)
X#endif
X 
X
X/* Store NUMBER in two contiguous bytes starting at DESTINATION.  */
X#define STORE_NUMBER(destination, number)				\
X  { (destination)[0] = (number) & 0377;					\
X    (destination)[1] = (number) >> 8; }
X  
X/* Same as STORE_NUMBER, except increment the destination pointer to
X   the byte after where the number is stored.  Watch out that values for
X   DESTINATION such as p + 1 won't work, whereas p will.  */
X#define STORE_NUMBER_AND_INCR(destination, number)			\
X  { STORE_NUMBER(destination, number);					\
X    (destination) += 2; }
X
X
X/* Put into DESTINATION a number stored in two contingous bytes starting
X   at SOURCE.  */
X#define EXTRACT_NUMBER(destination, source)				\
X  { (destination) = *(source) & 0377;					\
X    (destination) += SIGN_EXTEND_CHAR (*(char *)((source) + 1)) << 8; }
X
X/* Same as EXTRACT_NUMBER, except increment the pointer for source to
X   point to second byte of SOURCE.  Note that SOURCE has to be a value
X   such as p, not, e.g., p + 1. */
X#define EXTRACT_NUMBER_AND_INCR(destination, source)			\
X  { EXTRACT_NUMBER (destination, source);				\
X    (source) += 2; }
X
X
X/* Specify the precise syntax of regexps for compilation.  This provides
X   for compatibility for various utilities which historically have
X   different, incompatible syntaxes.
X   
X   The argument SYNTAX is a bit-mask comprised of the various bits
X   defined in regex.h.  */
X
Xint
Xre_set_syntax (syntax)
X  int syntax;
X{
X  int ret;
X
X  ret = obscure_syntax;
X  obscure_syntax = syntax;
X  return ret;
X}
X
X/* Set by re_set_syntax to the current regexp syntax to recognize.  */
Xint obscure_syntax = 0;
X
X
X
X/* Macros for re_compile_pattern, which is found below these definitions.  */
X
X#define CHAR_CLASS_MAX_LENGTH  6
X
X/* Fetch the next character in the uncompiled pattern, translating it if
X   necessary.  */
X#define PATFETCH(c)							\
X  {if (p == pend) goto end_of_pattern;					\
X  c = * (unsigned char *) p++;						\
X  if (translate) c = translate[c]; }
X
X/* Fetch the next character in the uncompiled pattern, with no
X   translation.  */
X#define PATFETCH_RAW(c)							\
X {if (p == pend) goto end_of_pattern;					\
X  c = * (unsigned char *) p++; }
X
X#define PATUNFETCH p--
X
X
X/* If the buffer isn't allocated when it comes in, use this.  */
X#define INIT_BUF_SIZE  28
X
X/* Make sure we have at least N more bytes of space in buffer.  */
X#define GET_BUFFER_SPACE(n)						\
X  {								        \
X    while (b - bufp->buffer + (n) >= bufp->allocated)			\
X      EXTEND_BUFFER;							\
X  }
X
X/* Make sure we have one more byte of buffer space and then add CH to it.  */
X#define BUFPUSH(ch)							\
X  {									\
X    GET_BUFFER_SPACE (1);						\
X    *b++ = (char) (ch);							\
X  }
X  
X/* Extend the buffer by twice its current size via reallociation and
X   reset the pointers that pointed into the old allocation to point to
X   the correct places in the new allocation.  If extending the buffer
X   results in it being larger than 1 << 16, then flag memory exhausted.  */
X#define EXTEND_BUFFER							\
X  { char *old_buffer = bufp->buffer;					\
X    if (bufp->allocated == (1L<<16)) goto too_big;			\
X    bufp->allocated *= 2;						\
X    if (bufp->allocated > (1L<<16)) bufp->allocated = (1L<<16);		\
X    bufp->buffer = (char *) realloc (bufp->buffer, bufp->allocated);	\
X    if (bufp->buffer == 0)						\
X      goto memory_exhausted;						\
X    b = (b - old_buffer) + bufp->buffer;				\
X    if (fixup_jump)							\
X      fixup_jump = (fixup_jump - old_buffer) + bufp->buffer;		\
X    if (laststart)							\
X      laststart = (laststart - old_buffer) + bufp->buffer;		\
X    begalt = (begalt - old_buffer) + bufp->buffer;			\
X    if (pending_exact)							\
X      pending_exact = (pending_exact - old_buffer) + bufp->buffer;	\
X  }
X
X/* Set the bit for character C in a character set list.  */
X#define SET_LIST_BIT(c)  (b[(c) / BYTEWIDTH] |= 1 << ((c) % BYTEWIDTH))
X
X/* Get the next unsigned number in the uncompiled pattern.  */
X#define GET_UNSIGNED_NUMBER(num) 					\
X  { if (p != pend) 							\
X      { 								\
X        PATFETCH (c); 							\
X	while (isdigit (c)) 						\
X	  { 								\
X	    if (num < 0) 						\
X	       num = 0; 						\
X            num = num * 10 + c - '0'; 					\
X	    if (p == pend) 						\
X	       break; 							\
X	    PATFETCH (c); 						\
X	  } 								\
X        } 								\
X  }
X
X/* Subroutines for re_compile_pattern.  */
Xstatic void store_jump (), insert_jump (), store_jump_n (),
X	    insert_jump_n (), insert_op_2 ();
X
X
X/* re_compile_pattern takes a regular-expression string
X   and converts it into a buffer full of byte commands for matching.
X
X   PATTERN   is the address of the pattern string
X   SIZE      is the length of it.
X   BUFP	    is a  struct re_pattern_buffer *  which points to the info
X	     on where to store the byte commands.
X	     This structure contains a  char *  which points to the
X	     actual space, which should have been obtained with malloc.
X	     re_compile_pattern may use realloc to grow the buffer space.
X
X   The number of bytes of commands can be found out by looking in
X   the `struct re_pattern_buffer' that bufp pointed to, after
X   re_compile_pattern returns. */
X
Xchar *
Xre_compile_pattern (pattern, size, bufp)
X     char *pattern;
X     int size;
X     struct re_pattern_buffer *bufp;
X{
X  register char *b = bufp->buffer;
X  register char *p = pattern;
X  char *pend = pattern + size;
X  register unsigned c, c1;
X  char *p1;
X  unsigned char *translate = (unsigned char *) bufp->translate;
X
X  /* Address of the count-byte of the most recently inserted `exactn'
X     command.  This makes it possible to tell whether a new exact-match
X     character can be added to that command or requires a new `exactn'
X     command.  */
X     
X  char *pending_exact = 0;
X
X  /* Address of the place where a forward-jump should go to the end of
X     the containing expression.  Each alternative of an `or', except the
X     last, ends with a forward-jump of this sort.  */
X
X  char *fixup_jump = 0;
X
X  /* Address of start of the most recently finished expression.
X     This tells postfix * where to find the start of its operand.  */
X
X  char *laststart = 0;
X
X  /* In processing a repeat, 1 means zero matches is allowed.  */
X
X  char zero_times_ok;
X
X  /* In processing a repeat, 1 means many matches is allowed.  */
X
X  char many_times_ok;
X
X  /* Address of beginning of regexp, or inside of last \(.  */
X
X  char *begalt = b;
X
X  /* In processing an interval, at least this many matches must be made.  */
X  int lower_bound;
X
X  /* In processing an interval, at most this many matches can be made.  */
X  int upper_bound;
X
X  /* Place in pattern (i.e., the {) to which to go back if the interval
X     is invalid.  */
X  char *beg_interval = 0;
X  
X  /* Stack of information saved by \( and restored by \).
X     Four stack elements are pushed by each \(:
X       First, the value of b.
X       Second, the value of fixup_jump.
X       Third, the value of regnum.
X       Fourth, the value of begalt.  */
X
X  int stackb[40];
X  int *stackp = stackb;
X  int *stacke = stackb + 40;
X  int *stackt;
X
X  /* Counts \('s as they are encountered.  Remembered for the matching \),
X     where it becomes the register number to put in the stop_memory
X     command.  */
X
X  int regnum = 1;
X
X  bufp->fastmap_accurate = 0;
X
X#ifndef emacs
X#ifndef SYNTAX_TABLE
X  /* Initialize the syntax table.  */
X   init_syntax_once();
X#endif
X#endif
X
X  if (bufp->allocated == 0)
X    {
X      bufp->allocated = INIT_BUF_SIZE;
X      if (bufp->buffer)
X	/* EXTEND_BUFFER loses when bufp->allocated is 0.  */
X	bufp->buffer = (char *) realloc (bufp->buffer, INIT_BUF_SIZE);
X      else
X	/* Caller did not allocate a buffer.  Do it for them.  */
X	bufp->buffer = (char *) malloc (INIT_BUF_SIZE);
X      if (!bufp->buffer) goto memory_exhausted;
X      begalt = b = bufp->buffer;
X    }
X
X  while (p != pend)
X    {
X      PATFETCH (c);
X
X      switch (c)
X	{
X	case '$':
X	  {
X	    char *p1 = p;
X	    /* When testing what follows the $,
X	       look past the \-constructs that don't consume anything.  */
X	    if (! (obscure_syntax & RE_CONTEXT_INDEP_OPS))
X	      while (p1 != pend)
X		{
X		  if (*p1 == '\\' && p1 + 1 != pend
X		      && (p1[1] == '<' || p1[1] == '>'
X			  || p1[1] == '`' || p1[1] == '\''
X#ifdef emacs
X			  || p1[1] == '='
X#endif
X			  || p1[1] == 'b' || p1[1] == 'B'))
X		    p1 += 2;
X		  else
X		    break;
X		}
X            if (obscure_syntax & RE_TIGHT_VBAR)
X	      {
X		if (! (obscure_syntax & RE_CONTEXT_INDEP_OPS) && p1 != pend)
X		  goto normal_char;
X		/* Make operand of last vbar end before this `$'.  */
X		if (fixup_jump)
X		  store_jump (fixup_jump, jump, b);
X		fixup_jump = 0;
X		BUFPUSH (endline);
X		break;
X	      }
X	    /* $ means succeed if at end of line, but only in special contexts.
X	      If validly in the middle of a pattern, it is a normal character. */
X
X            if ((obscure_syntax & RE_CONTEXTUAL_INVALID_OPS) && p1 != pend)
X	      goto invalid_pattern;
X	    if (p1 == pend || *p1 == '\n'
X		|| (obscure_syntax & RE_CONTEXT_INDEP_OPS)
X		|| (obscure_syntax & RE_NO_BK_PARENS
X		    ? *p1 == ')'
X		    : *p1 == '\\' && p1[1] == ')')
X		|| (obscure_syntax & RE_NO_BK_VBAR
X		    ? *p1 == '|'
X		    : *p1 == '\\' && p1[1] == '|'))
X	      {
X		BUFPUSH (endline);
X		break;
X	      }
X	    goto normal_char;
X          }
X	case '^':
X	  /* ^ means succeed if at beg of line, but only if no preceding 
X             pattern.  */
X             
X          if ((obscure_syntax & RE_CONTEXTUAL_INVALID_OPS) && laststart)
X            goto invalid_pattern;
X          if (laststart && p - 2 >= pattern && p[-2] != '\n'
X	       && !(obscure_syntax & RE_CONTEXT_INDEP_OPS))
X	    goto normal_char;
X	  if (obscure_syntax & RE_TIGHT_VBAR)
X	    {
X	      if (p != pattern + 1
X		  && ! (obscure_syntax & RE_CONTEXT_INDEP_OPS))
X		goto normal_char;
X	      BUFPUSH (begline);
X	      begalt = b;
X	    }
X	  else
X	    BUFPUSH (begline);
X	  break;
X
X	case '+':
X	case '?':
X	  if ((obscure_syntax & RE_BK_PLUS_QM)
X	      || (obscure_syntax & RE_LIMITED_OPS))
X	    goto normal_char;
X	handle_plus:
X	case '*':
X	  /* If there is no previous pattern, char not special. */
X	  if (!laststart)
X            {
X              if (obscure_syntax & RE_CONTEXTUAL_INVALID_OPS)
X                goto invalid_pattern;
X              else if (! (obscure_syntax & RE_CONTEXT_INDEP_OPS))
X		goto normal_char;
X            }
X	  /* If there is a sequence of repetition chars,
X	     collapse it down to just one.  */
X	  zero_times_ok = 0;
X	  many_times_ok = 0;
X	  while (1)
X	    {
X	      zero_times_ok |= c != '+';
X	      many_times_ok |= c != '?';
X	      if (p == pend)
X		break;
X	      PATFETCH (c);
X	      if (c == '*')
X		;
X	      else if (!(obscure_syntax & RE_BK_PLUS_QM)
X		       && (c == '+' || c == '?'))
X		;
X	      else if ((obscure_syntax & RE_BK_PLUS_QM)
X		       && c == '\\')
X		{
X		  int c1;
X		  PATFETCH (c1);
X		  if (!(c1 == '+' || c1 == '?'))
X		    {
X		      PATUNFETCH;
X		      PATUNFETCH;
X		      break;
X		    }
X		  c = c1;
X		}
X	      else
X		{
X		  PATUNFETCH;
X		  break;
X		}
X	    }
X
X	  /* Star, etc. applied to an empty pattern is equivalent
X	     to an empty pattern.  */
X	  if (!laststart)  
X	    break;
X
X	  /* Now we know whether or not zero matches is allowed
X	     and also whether or not two or more matches is allowed.  */
X	  if (many_times_ok)
X	    {
X	      /* If more than one repetition is allowed, put in at the
X                 end a backward relative jump from b to before the next
X                 jump we're going to put in below (which jumps from
X                 laststart to after this jump).  */
X              GET_BUFFER_SPACE (3);
X	      store_jump (b, maybe_finalize_jump, laststart - 3);
X	      b += 3;  	/* Because store_jump put stuff here.  */
X	    }
X          /* On failure, jump from laststart to b + 3, which will be the
X             end of the buffer after this jump is inserted.  */
X          GET_BUFFER_SPACE (3);
X	  insert_jump (on_failure_jump, laststart, b + 3, b);
X	  pending_exact = 0;
X	  b += 3;
X	  if (!zero_times_ok)
X	    {
X	      /* At least one repetition is required, so insert a
X                 dummy-failure before the initial on-failure-jump
X                 instruction of the loop. This effects a skip over that
X                 instruction the first time we hit that loop.  */
X              GET_BUFFER_SPACE (6);
X              insert_jump (dummy_failure_jump, laststart, laststart + 6, b);
X	      b += 3;
X	    }
X	  break;
X
X	case '.':
X	  laststart = b;
X	  BUFPUSH (anychar);
X	  break;
X
X        case '[':
X          if (p == pend)
X            goto invalid_pattern;
X	  while (b - bufp->buffer
X		 > bufp->allocated - 3 - (1 << BYTEWIDTH) / BYTEWIDTH)
X	    EXTEND_BUFFER;
X
X	  laststart = b;
X	  if (*p == '^')
X	    {
X              BUFPUSH (charset_not); 
X              p++;
X            }
X	  else
X	    BUFPUSH (charset);
X	  p1 = p;
X
X	  BUFPUSH ((1 << BYTEWIDTH) / BYTEWIDTH);
X	  /* Clear the whole map */
X	  bzero (b, (1 << BYTEWIDTH) / BYTEWIDTH);
X          
X	  if ((obscure_syntax & RE_HAT_NOT_NEWLINE) && b[-2] == charset_not)
X            SET_LIST_BIT ('\n');
X
X
X	  /* Read in characters and ranges, setting map bits.  */
X	  while (1)
X	    {
X	      /* Don't translate while fetching, in case it's a range bound.
X		 When we set the bit for the character, we translate it.  */
X	      PATFETCH_RAW (c);
X
X	      /* If set, \ escapes characters when inside [...].  */
X	      if ((obscure_syntax & RE_AWK_CLASS_HACK) && c == '\\')
X	        {
X	          PATFETCH(c1);
X                  SET_LIST_BIT (c1);
X	          continue;
X	        }
X              if (c == ']')
X                {
X                  if (p == p1 + 1)
X                    {
X		      /* If this is an empty bracket expression.  */
X                      if ((obscure_syntax & RE_NO_EMPTY_BRACKETS) 
X                          && p == pend)
X                        goto invalid_pattern;
X                    }
X                  else 
X		    /* Stop if this isn't merely a ] inside a bracket
X                       expression, but rather the end of a bracket
X                       expression.  */
X                    break;
X                }
X              /* Get a range.  */
X              if (p[0] == '-' && p[1] != ']')
X		{
X                  PATFETCH (c1);
X		  /* Don't translate the range bounds while fetching them.  */
X		  PATFETCH_RAW (c1);
X                  
X		  if ((obscure_syntax & RE_NO_EMPTY_RANGES) && c > c1)
X                    goto invalid_pattern;
X                    
X		  if ((obscure_syntax & RE_NO_HYPHEN_RANGE_END) 
X                      && c1 == '-' && *p != ']')
X                    goto invalid_pattern;
X                    
X                  while (c <= c1)
X		    {
X		      /* Translate each char that's in the range.  */
X		      if (translate)
X			SET_LIST_BIT (translate[c]);
X		      else
X			SET_LIST_BIT (c);
X                      c++;
X		    }
X                }
X	      else if ((obscure_syntax & RE_CHAR_CLASSES)
X			&&  c == '[' && p[0] == ':')
X                {
X		  /* Longest valid character class word has six characters.  */
X                  char str[CHAR_CLASS_MAX_LENGTH];
X		  PATFETCH (c);
X		  c1 = 0;
X		  /* If no ] at end.  */
X                  if (p == pend)
X                    goto invalid_pattern;
X		  while (1)
X		    {
X		      /* Don't translate the ``character class'' characters.  */
X                      PATFETCH_RAW (c);
X		      if (c == ':' || c == ']' || p == pend
X                          || c1 == CHAR_CLASS_MAX_LENGTH)
X		        break;
X		      str[c1++] = c;
X		    }
X		  str[c1] = '\0';
X		  if (p == pend 	
X		      || c == ']'	/* End of the bracket expression.  */
X                      || p[0] != ']'
X		      || p + 1 == pend
X                      || (strcmp (str, "alpha") != 0 
X                          && strcmp (str, "upper") != 0
X			  && strcmp (str, "lower") != 0 
X                          && strcmp (str, "digit") != 0
X			  && strcmp (str, "alnum") != 0 
X                          && strcmp (str, "xdigit") != 0
X			  && strcmp (str, "space") != 0 
X                          && strcmp (str, "print") != 0
X			  && strcmp (str, "punct") != 0 
X                          && strcmp (str, "graph") != 0
X			  && strcmp (str, "cntrl") != 0))
X		    {
X		       /* Undo the ending character, the letters, and leave 
X                          the leading : and [ (but set bits for them).  */
X                      c1++;
X		      while (c1--)    
X			PATUNFETCH;
X		      SET_LIST_BIT ('[');
X		      SET_LIST_BIT (':');
X	            }
X                  else
X                    {
X                      /* The ] at the end of the character class.  */
X                      PATFETCH (c);					
X                      if (c != ']')
X                        goto invalid_pattern;
X		      for (c = 0; c < (1 << BYTEWIDTH); c++)
X			{
X			  if ((strcmp (str, "alpha") == 0  && isalpha (c))
X			       || (strcmp (str, "upper") == 0  && isupper (c))
X			       || (strcmp (str, "lower") == 0  && islower (c))
X			       || (strcmp (str, "digit") == 0  && isdigit (c))
X			       || (strcmp (str, "alnum") == 0  && isalnum (c))
X			       || (strcmp (str, "xdigit") == 0  && isxdigit (c))
X			       || (strcmp (str, "space") == 0  && isspace (c))
X			       || (strcmp (str, "print") == 0  && isprint (c))
X			       || (strcmp (str, "punct") == 0  && ispunct (c))
X			       || (strcmp (str, "graph") == 0  && isgraph (c))
X			       || (strcmp (str, "cntrl") == 0  && iscntrl (c)))
X			    SET_LIST_BIT (c);
X			}
X		    }
X                }
X              else if (translate)
X		SET_LIST_BIT (translate[c]);
X	      else
X                SET_LIST_BIT (c);
X	    }
X
X          /* Discard any character set/class bitmap bytes that are all
X             0 at the end of the map. Decrement the map-length byte too.  */
X          while ((int) b[-1] > 0 && b[b[-1] - 1] == 0) 
X            b[-1]--; 
X          b += b[-1];
X          break;
X
X	case '(':
X	  if (! (obscure_syntax & RE_NO_BK_PARENS))
X	    goto normal_char;
X	  else
X	    goto handle_open;
X
X	case ')':
X	  if (! (obscure_syntax & RE_NO_BK_PARENS))
X	    goto normal_char;
X	  else
X	    goto handle_close;
X
X        case '\n':
X	  if (! (obscure_syntax & RE_NEWLINE_OR))
X	    goto normal_char;
X	  else
X	    goto handle_bar;
X
X	case '|':
X	  if ((obscure_syntax & RE_CONTEXTUAL_INVALID_OPS)
X              && (! laststart  ||  p == pend))
X	    goto invalid_pattern;
X          else if (! (obscure_syntax & RE_NO_BK_VBAR))
X	    goto normal_char;
X	  else
X	    goto handle_bar;
X
X	case '{':
X           if (! ((obscure_syntax & RE_NO_BK_CURLY_BRACES)
X                  && (obscure_syntax & RE_INTERVALS)))
X             goto normal_char;
X           else
X             goto handle_interval;
X             
X        case '\\':
X	  if (p == pend) goto invalid_pattern;
X	  PATFETCH_RAW (c);
X	  switch (c)
X	    {
X	    case '(':
X	      if (obscure_syntax & RE_NO_BK_PARENS)
X		goto normal_backsl;
X	    handle_open:
X	      if (stackp == stacke) goto nesting_too_deep;
X
X              /* Laststart should point to the start_memory that we are about
X                 to push (unless the pattern has RE_NREGS or more ('s).  */
X              *stackp++ = b - bufp->buffer;    
X	      if (regnum < RE_NREGS)
X	        {
X		  BUFPUSH (start_memory);
X		  BUFPUSH (regnum);
X	        }
X	      *stackp++ = fixup_jump ? fixup_jump - bufp->buffer + 1 : 0;
X	      *stackp++ = regnum++;
X	      *stackp++ = begalt - bufp->buffer;
X	      fixup_jump = 0;
X	      laststart = 0;
X	      begalt = b;
X	      break;
X
X	    case ')':
X	      if (obscure_syntax & RE_NO_BK_PARENS)
X		goto normal_backsl;
X	    handle_close:
X	      if (stackp == stackb) goto unmatched_close;
X	      begalt = *--stackp + bufp->buffer;
X	      if (fixup_jump)
X		store_jump (fixup_jump, jump, b);
X	      if (stackp[-1] < RE_NREGS)
X		{
X		  BUFPUSH (stop_memory);
X		  BUFPUSH (stackp[-1]);
X		}
X	      stackp -= 2;
X              fixup_jump = *stackp ? *stackp + bufp->buffer - 1 : 0;
X              laststart = *--stackp + bufp->buffer;
X	      break;
X
X	    case '|':
X              if ((obscure_syntax & RE_LIMITED_OPS)
X	          || (obscure_syntax & RE_NO_BK_VBAR))
X		goto normal_backsl;
X	    handle_bar:
X              if (obscure_syntax & RE_LIMITED_OPS)
X                goto normal_char;
X	      /* Insert before the previous alternative a jump which
X                 jumps to this alternative if the former fails.  */
X              GET_BUFFER_SPACE (6);
X              insert_jump (on_failure_jump, begalt, b + 6, b);
X	      pending_exact = 0;
X	      b += 3;
X	      /* The alternative before the previous alternative has a
X                 jump after it which gets executed if it gets matched.
X                 Adjust that jump so it will jump to the previous
X                 alternative's analogous jump (put in below, which in
X                 turn will jump to the next (if any) alternative's such
X                 jump, etc.).  The last such jump jumps to the correct
X                 final destination.  */
X              if (fixup_jump)
X		store_jump (fixup_jump, jump, b);
X                
X	      /* Leave space for a jump after previous alternative---to be 
X                 filled in later.  */
X              fixup_jump = b;
X              b += 3;
X
X              laststart = 0;
X	      begalt = b;
X	      break;
X
X            case '{': 
X              if (! (obscure_syntax & RE_INTERVALS)
X		  /* Let \{ be a literal.  */
X                  || ((obscure_syntax & RE_INTERVALS)
X                      && (obscure_syntax & RE_NO_BK_CURLY_BRACES))
X		  /* If it's the string "\{".  */
X		  || (p - 2 == pattern  &&  p == pend))
X                goto normal_backsl;
X            handle_interval:
X	      beg_interval = p - 1;		/* The {.  */
X              /* If there is no previous pattern, this isn't an interval.  */
X	      if (!laststart)
X	        {
X                  if (obscure_syntax & RE_CONTEXTUAL_INVALID_OPS)
X		    goto invalid_pattern;
X                  else
X                    goto normal_backsl;
X                }
X              /* It also isn't an interval if not preceded by an re
X                 matching a single character or subexpression, or if
X                 the current type of intervals can't handle back
X                 references and the previous thing is a back reference.  */
X              if (! (*laststart == anychar
X		     || *laststart == charset
X		     || *laststart == charset_not
X		     || *laststart == start_memory
X		     || (*laststart == exactn  &&  laststart[1] == 1)
X		     || (! (obscure_syntax & RE_NO_BK_REFS)
X                         && *laststart == duplicate)))
X                {
X                  if (obscure_syntax & RE_NO_BK_CURLY_BRACES)
X                    goto normal_char;
X                    
X		  /* Posix extended syntax is handled in previous
X                     statement; this is for Posix basic syntax.  */
X                  if (obscure_syntax & RE_INTERVALS)
X                    goto invalid_pattern;
X                    
X                  goto normal_backsl;
X		}
X              lower_bound = -1;			/* So can see if are set.  */
X	      upper_bound = -1;
X              GET_UNSIGNED_NUMBER (lower_bound);
X	      if (c == ',')
X		{
X		  GET_UNSIGNED_NUMBER (upper_bound);
X		  if (upper_bound < 0)
X		    upper_bound = RE_DUP_MAX;
X		}
X	      if (upper_bound < 0)
X		upper_bound = lower_bound;
X              if (! (obscure_syntax & RE_NO_BK_CURLY_BRACES)) 
X                {
X                  if (c != '\\')
X                    goto invalid_pattern;
X                  PATFETCH (c);
X                }
X	      if (c != '}' || lower_bound < 0 || upper_bound > RE_DUP_MAX
X		  || lower_bound > upper_bound 
X                  || ((obscure_syntax & RE_NO_BK_CURLY_BRACES) 
X		      && p != pend  && *p == '{')) 
X	        {
X		  if (obscure_syntax & RE_NO_BK_CURLY_BRACES)
X                    goto unfetch_interval;
X                  else
X                    goto invalid_pattern;
X		}
X
X	      /* If upper_bound is zero, don't want to succeed at all; 
X 		 jump from laststart to b + 3, which will be the end of
X                 the buffer after this jump is inserted.  */
X                 
X               if (upper_bound == 0)
X                 {
X                   GET_BUFFER_SPACE (3);
X                   insert_jump (jump, laststart, b + 3, b);
X                   b += 3;
X                 }
X
X               /* Otherwise, after lower_bound number of succeeds, jump
X                  to after the jump_n which will be inserted at the end
X                  of the buffer, and insert that jump_n.  */
X               else 
X		 { /* Set to 5 if only one repetition is allowed and
X	              hence no jump_n is inserted at the current end of
X                      the buffer; then only space for the succeed_n is
X                      needed.  Otherwise, need space for both the
X                      succeed_n and the jump_n.  */
X                      
X                   unsigned slots_needed = upper_bound == 1 ? 5 : 10;
X                     
X                   GET_BUFFER_SPACE (slots_needed);
X                   /* Initialize the succeed_n to n, even though it will
X                      be set by its attendant set_number_at, because
X                      re_compile_fastmap will need to know it.  Jump to
X                      what the end of buffer will be after inserting
X                      this succeed_n and possibly appending a jump_n.  */
X                   insert_jump_n (succeed_n, laststart, b + slots_needed, 
X		                  b, lower_bound);
X                   b += 5; 	/* Just increment for the succeed_n here.  */
X
X		  /* More than one repetition is allowed, so put in at
X		     the end of the buffer a backward jump from b to the
X                     succeed_n we put in above.  By the time we've gotten
X                     to this jump when matching, we'll have matched once
X                     already, so jump back only upper_bound - 1 times.  */
X
X                   if (upper_bound > 1)
X                     {
X                       store_jump_n (b, jump_n, laststart, upper_bound - 1);
X                       b += 5;
X                       /* When hit this when matching, reset the
X                          preceding jump_n's n to upper_bound - 1.  */
X                       BUFPUSH (set_number_at);
X		       GET_BUFFER_SPACE (2);
X                       STORE_NUMBER_AND_INCR (b, -5);
X                       STORE_NUMBER_AND_INCR (b, upper_bound - 1);
X                     }
X		   /* When hit this when matching, set the succeed_n's n.  */
X                   GET_BUFFER_SPACE (5);
X		   insert_op_2 (set_number_at, laststart, b, 5, lower_bound);
X                   b += 5;
X                 }
X              pending_exact = 0;
X	      beg_interval = 0;
X              break;
X
X
X            unfetch_interval:
X	      /* If an invalid interval, match the characters as literals.  */
X	       if (beg_interval)
X                 p = beg_interval;
X  	       else
X                 {
X                   fprintf (stderr, 
X		      "regex: no interval beginning to which to backtrack.\n");
X		   exit (1);
X                 }
X                 
X               beg_interval = 0;
X               PATFETCH (c);		/* normal_char expects char in `c'.  */
X	       goto normal_char;
X	       break;
X
X#ifdef emacs
X	    case '=':
X	      BUFPUSH (at_dot);
X	      break;
X
X	    case 's':	
X	      laststart = b;
X	      BUFPUSH (syntaxspec);
X	      PATFETCH (c);
X	      BUFPUSH (syntax_spec_code[c]);
X	      break;
X
X	    case 'S':
X	      laststart = b;
X	      BUFPUSH (notsyntaxspec);
X	      PATFETCH (c);
X	      BUFPUSH (syntax_spec_code[c]);
X	      break;
X#endif /* emacs */
X
X	    case 'w':
X	      laststart = b;
X	      BUFPUSH (wordchar);
X	      break;
X
X	    case 'W':
X	      laststart = b;
X	      BUFPUSH (notwordchar);
X	      break;
X
X	    case '<':
X	      BUFPUSH (wordbeg);
X	      break;
X
X	    case '>':
X	      BUFPUSH (wordend);
X	      break;
X
X	    case 'b':
X	      BUFPUSH (wordbound);
X	      break;
X
X	    case 'B':
X	      BUFPUSH (notwordbound);
X	      break;
X
X	    case '`':
X	      BUFPUSH (begbuf);
X	      break;
X
X	    case '\'':
X	      BUFPUSH (endbuf);
X	      break;
X
X	    case '1':
X	    case '2':
X	    case '3':
X	    case '4':
X	    case '5':
X	    case '6':
X	    case '7':
X	    case '8':
X	    case '9':
X	      if (obscure_syntax & RE_NO_BK_REFS)
X                goto normal_char;
X              c1 = c - '0';
X	      if (c1 >= regnum)
X		{
X  		  if (obscure_syntax & RE_NO_EMPTY_BK_REF)
X                    goto invalid_pattern;
X                  else
X                    goto normal_char;
X                }
X              /* Can't back reference to a subexpression if inside of it.  */
X              for (stackt = stackp - 2;  stackt > stackb;  stackt -= 4)
X 		if (*stackt == c1)
X		  goto normal_char;
X	      laststart = b;
X	      BUFPUSH (duplicate);
X	      BUFPUSH (c1);
X	      break;
X
X	    case '+':
X	    case '?':
X	      if (obscure_syntax & RE_BK_PLUS_QM)
X		goto handle_plus;
X	      else
X                goto normal_backsl;
X              break;
X
X            default:
X	    normal_backsl:
X	      /* You might think it would be useful for \ to mean
X		 not to translate; but if we don't translate it
X		 it will never match anything.  */
X	      if (translate) c = translate[c];
X	      goto normal_char;
X	    }
X	  break;
X
X	default:
X	normal_char:		/* Expects the character in `c'.  */
X	  if (!pending_exact || pending_exact + *pending_exact + 1 != b
X	      || *pending_exact == 0177 || *p == '*' || *p == '^'
X	      || ((obscure_syntax & RE_BK_PLUS_QM)
X		  ? *p == '\\' && (p[1] == '+' || p[1] == '?')
X		  : (*p == '+' || *p == '?'))
X	      || ((obscure_syntax & RE_INTERVALS) 
X                  && ((obscure_syntax & RE_NO_BK_CURLY_BRACES)
X		      ? *p == '{'
X                      : (p[0] == '\\' && p[1] == '{'))))
X	    {
X	      laststart = b;
X	      BUFPUSH (exactn);
X	      pending_exact = b;
X	      BUFPUSH (0);
X	    }
X	  BUFPUSH (c);
X	  (*pending_exact)++;
X	}
X    }
X
X  if (fixup_jump)
X    store_jump (fixup_jump, jump, b);
X
X  if (stackp != stackb) goto unmatched_open;
X
X  bufp->used = b - bufp->buffer;
X  return 0;
X
X invalid_pattern:
X  return "Invalid regular expression";
X
X unmatched_open:
X  return "Unmatched \\(";
X
X unmatched_close:
X  return "Unmatched \\)";
X
X end_of_pattern:
X  return "Premature end of regular expression";
X
X nesting_too_deep:
X  return "Nesting too deep";
X
X too_big:
X  return "Regular expression too big";
X
X memory_exhausted:
X  return "Memory exhausted";
X}
X
X
X/* Store a jump of the form <OPCODE> <relative address>.
X   Store in the location FROM a jump operation to jump to relative
X   address FROM - TO.  OPCODE is the opcode to store.  */
X
Xstatic void
Xstore_jump (from, opcode, to)
X     char *from, *to;
X     char opcode;
X{
X  from[0] = opcode;
X  STORE_NUMBER(from + 1, to - (from + 3));
X}
X
X
X/* Open up space before char FROM, and insert there a jump to TO.
X   CURRENT_END gives the end of the storage not in use, so we know 
X   how much data to copy up. OP is the opcode of the jump to insert.
X
X   If you call this function, you must zero out pending_exact.  */
X
Xstatic void
Xinsert_jump (op, from, to, current_end)
X     char op;
X     char *from, *to, *current_end;
X{
X  register char *pfrom = current_end;		/* Copy from here...  */
X  register char *pto = current_end + 3;		/* ...to here.  */
X
X  while (pfrom != from)			       
X    *--pto = *--pfrom;
X  store_jump (from, op, to);
X}
X
X
X/* Store a jump of the form <opcode> <relative address> <n> .
X
X   Store in the location FROM a jump operation to jump to relative
X   address FROM - TO.  OPCODE is the opcode to store, N is a number the
X   jump uses, say, to decide how many times to jump.
X   
X   If you call this function, you must zero out pending_exact.  */
X
Xstatic void
Xstore_jump_n (from, opcode, to, n)
X     char *from, *to;
X     char opcode;
X     unsigned n;
X{
X  from[0] = opcode;
X  STORE_NUMBER (from + 1, to - (from + 3));
X  STORE_NUMBER (from + 3, n);
X}
X
X
X/* Similar to insert_jump, but handles a jump which needs an extra
X   number to handle minimum and maximum cases.  Open up space at
X   location FROM, and insert there a jump to TO.  CURRENT_END gives the
X   end of the storage in use, so we know how much data to copy up. OP is
X   the opcode of the jump to insert.
X
X   If you call this function, you must zero out pending_exact.  */
X
Xstatic void
Xinsert_jump_n (op, from, to, current_end, n)
X     char op;
X     char *from, *to, *current_end;
X     unsigned n;
X{
X  register char *pfrom = current_end;		/* Copy from here...  */
X  register char *pto = current_end + 5;		/* ...to here.  */
X
X  while (pfrom != from)			       
X    *--pto = *--pfrom;
X  store_jump_n (from, op, to, n);
X}
X
X
X/* Open up space at location THERE, and insert operation OP followed by
X   NUM_1 and NUM_2.  CURRENT_END gives the end of the storage in use, so
X   we know how much data to copy up.
X
X   If you call this function, you must zero out pending_exact.  */
X
Xstatic void
Xinsert_op_2 (op, there, current_end, num_1, num_2)
X     char op;
X     char *there, *current_end;
X     int num_1, num_2;
X{
X  register char *pfrom = current_end;		/* Copy from here...  */
X  register char *pto = current_end + 5;		/* ...to here.  */
X
X  while (pfrom != there)			       
X    *--pto = *--pfrom;
X  
X  there[0] = op;
X  STORE_NUMBER (there + 1, num_1);
X  STORE_NUMBER (there + 3, num_2);
X}
X
X
X
X/* Given a pattern, compute a fastmap from it.  The fastmap records
X   which of the (1 << BYTEWIDTH) possible characters can start a string
X   that matches the pattern.  This fastmap is used by re_search to skip
X   quickly over totally implausible text.
X
X   The caller must supply the address of a (1 << BYTEWIDTH)-byte data 
X   area as bufp->fastmap.
X   The other components of bufp describe the pattern to be used.  */
X
Xvoid
Xre_compile_fastmap (bufp)
X     struct re_pattern_buffer *bufp;
X{
X  unsigned char *pattern = (unsigned char *) bufp->buffer;
X  int size = bufp->used;
X  register char *fastmap = bufp->fastmap;
X  register unsigned char *p = pattern;
X  register unsigned char *pend = pattern + size;
X  register int j, k;
X  unsigned char *translate = (unsigned char *) bufp->translate;
X
X  unsigned char *stackb[NFAILURES];
X  unsigned char **stackp = stackb;
X
X  unsigned is_a_succeed_n;
X
X  bzero (fastmap, (1 << BYTEWIDTH));
X  bufp->fastmap_accurate = 1;
X  bufp->can_be_null = 0;
X      
X  while (p)
X    {
X      is_a_succeed_n = 0;
X      if (p == pend)
X	{
X	  bufp->can_be_null = 1;
X	  break;
X	}
X#ifdef SWITCH_ENUM_BUG
X      switch ((int) ((enum regexpcode) *p++))
X#else
X      switch ((enum regexpcode) *p++)
X#endif
X	{
X	case exactn:
X	  if (translate)
X	    fastmap[translate[p[1]]] = 1;
X	  else
X	    fastmap[p[1]] = 1;
X	  break;
X
X        case begline:
X        case before_dot:
X	case at_dot:
X	case after_dot:
X	case begbuf:
X	case endbuf:
X	case wordbound:
X	case notwordbound:
X	case wordbeg:
X	case wordend:
X          continue;
X
X	case endline:
X	  if (translate)
X	    fastmap[translate['\n']] = 1;
X	  else
X	    fastmap['\n'] = 1;
X            
X	  if (bufp->can_be_null != 1)
X	    bufp->can_be_null = 2;
X	  break;
X
X	case jump_n:
X        case finalize_jump:
X	case maybe_finalize_jump:
X	case jump:
X	case dummy_failure_jump:
X          EXTRACT_NUMBER_AND_INCR (j, p);
X	  p += j;	
X	  if (j > 0)
X	    continue;
X          /* Jump backward reached implies we just went through
X	     the body of a loop and matched nothing.
X	     Opcode jumped to should be an on_failure_jump.
X	     Just treat it like an ordinary jump.
X	     For a * loop, it has pushed its failure point already;
X	     If so, discard that as redundant.  */
X
X          if ((enum regexpcode) *p != on_failure_jump
X	      && (enum regexpcode) *p != succeed_n)
X	    continue;
X          p++;
X          EXTRACT_NUMBER_AND_INCR (j, p);
X          p += j;		
X          if (stackp != stackb && *stackp == p)
X            stackp--;
X          continue;
X	  
X        case on_failure_jump:
X	handle_on_failure_jump:
X          EXTRACT_NUMBER_AND_INCR (j, p);
X          *++stackp = p + j;
X	  if (is_a_succeed_n)
X            EXTRACT_NUMBER_AND_INCR (k, p);	/* Skip the n.  */
X	  continue;
X
X	case succeed_n:
X	  is_a_succeed_n = 1;
X          /* Get to the number of times to succeed.  */
X          p += 2;		
X	  /* Increment p past the n for when k != 0.  */
X          EXTRACT_NUMBER_AND_INCR (k, p);
X          if (k == 0)
X	    {
X              p -= 4;
X              goto handle_on_failure_jump;
X            }
X          continue;
X          
X	case set_number_at:
X          p += 4;
X          continue;
X
X        case start_memory:
X	case stop_memory:
X	  p++;
X	  continue;
X
X	case duplicate:
X	  bufp->can_be_null = 1;
X	  fastmap['\n'] = 1;
X	case anychar:
X	  for (j = 0; j < (1 << BYTEWIDTH); j++)
X	    if (j != '\n')
X	      fastmap[j] = 1;
X	  if (bufp->can_be_null)
X	    return;
X	  /* Don't return; check the alternative paths
X	     so we can set can_be_null if appropriate.  */
X	  break;
X
X	case wordchar:
X	  for (j = 0; j < (1 << BYTEWIDTH); j++)
X	    if (SYNTAX (j) == Sword)
X	      fastmap[j] = 1;
X	  break;
X
X	case notwordchar:
X	  for (j = 0; j < (1 << BYTEWIDTH); j++)
X	    if (SYNTAX (j) != Sword)
X	      fastmap[j] = 1;
X	  break;
X
X#ifdef emacs
X	case syntaxspec:
X	  k = *p++;
X	  for (j = 0; j < (1 << BYTEWIDTH); j++)
X	    if (SYNTAX (j) == (enum syntaxcode) k)
X	      fastmap[j] = 1;
X	  break;
X
X	case notsyntaxspec:
X	  k = *p++;
X	  for (j = 0; j < (1 << BYTEWIDTH); j++)
X	    if (SYNTAX (j) != (enum syntaxcode) k)
X	      fastmap[j] = 1;
X	  break;
X#endif /* not emacs */
X
X	case charset:
X	  for (j = *p++ * BYTEWIDTH - 1; j >= 0; j--)
X	    if (p[j / BYTEWIDTH] & (1 << (j % BYTEWIDTH)))
X	      {
X		if (translate)
X		  fastmap[translate[j]] = 1;
X		else
X		  fastmap[j] = 1;
X	      }
X	  break;
X
X	case charset_not:
X	  /* Chars beyond end of map must be allowed */
X	  for (j = *p * BYTEWIDTH; j < (1 << BYTEWIDTH); j++)
X	    if (translate)
X	      fastmap[translate[j]] = 1;
X	    else
X	      fastmap[j] = 1;
X
X	  for (j = *p++ * BYTEWIDTH - 1; j >= 0; j--)
X	    if (!(p[j / BYTEWIDTH] & (1 << (j % BYTEWIDTH))))
X	      {
X		if (translate)
X		  fastmap[translate[j]] = 1;
X		else
X		  fastmap[j] = 1;
X	      }
X	  break;
X	}
X
X      /* Get here means we have successfully found the possible starting
X         characters of one path of the pattern.  We need not follow this
X         path any farther.  Instead, look at the next alternative
X         remembered in the stack.  */
X   if (stackp != stackb)
X	p = *stackp--;
X      else
X	break;
X    }
X}
X
X
X
X/* Like re_search_2, below, but only one string is specified, and
X   doesn't let you say where to stop matching. */
X
Xint
Xre_search (pbufp, string, size, startpos, range, regs)
X     struct re_pattern_buffer *pbufp;
X     char *string;
X     int size, startpos, range;
X     struct re_registers *regs;
X{
X  return re_search_2 (pbufp, (char *) 0, 0, string, size, startpos, range, 
X		      regs, size);
X}
X
X
X/* Using the compiled pattern in PBUFP->buffer, first tries to match the
X   virtual concatenation of STRING1 and STRING2, starting first at index
X   STARTPOS, then at STARTPOS + 1, and so on.  RANGE is the number of
X   places to try before giving up.  If RANGE is negative, it searches
X   backwards, i.e., the starting positions tried are STARTPOS, STARTPOS
X   - 1, etc.  STRING1 and STRING2 are of SIZE1 and SIZE2, respectively.
X   In REGS, return the indices of the virtual concatenation of STRING1
X   and STRING2 that matched the entire PBUFP->buffer and its contained
X   subexpressions.  Do not consider matching one past the index MSTOP in
X   the virtual concatenation of STRING1 and STRING2.
X
X   The value returned is the position in the strings at which the match
X   was found, or -1 if no match was found, or -2 if error (such as
X   failure stack overflow).  */
X
Xint
Xre_search_2 (pbufp, string1, size1, string2, size2, startpos, range,
X	     regs, mstop)
X     struct re_pattern_buffer *pbufp;
X     char *string1, *string2;
X     int size1, size2;
X     int startpos;
X     register int range;
X     struct re_registers *regs;
X     int mstop;
X{
X  register char *fastmap = pbufp->fastmap;
X  register unsigned char *translate = (unsigned char *) pbufp->translate;
X  int total_size = size1 + size2;
X  int endpos = startpos + range;
X  int val;
X
X  /* Check for out-of-range starting position.  */
X  if (startpos < 0  ||  startpos > total_size)
X    return -1;
X    
X  /* Fix up range if it would eventually take startpos outside of the
X     virtual concatenation of string1 and string2.  */
X  if (endpos < -1)
X    range = -1 - startpos;
X  else if (endpos > total_size)
X    range = total_size - startpos;
X
X  /* Update the fastmap now if not correct already.  */
X  if (fastmap && !pbufp->fastmap_accurate)
X    re_compile_fastmap (pbufp);
X  
X  /* If the search isn't to be a backwards one, don't waste time in a
X     long search for a pattern that says it is anchored.  */
X  if (pbufp->used > 0 && (enum regexpcode) pbufp->buffer[0] == begbuf
X      && range > 0)
X    {
X      if (startpos > 0)
X	return -1;
X      else
X	range = 1;
X    }
X
X  while (1)
X    { 
X      /* If a fastmap is supplied, skip quickly over characters that
X         cannot possibly be the start of a match.  Note, however, that
X         if the pattern can possibly match the null string, we must
X         test it at each starting point so that we take the first null
X         string we get.  */
X
X      if (fastmap && startpos < total_size && pbufp->can_be_null != 1)
X	{
X	  if (range > 0)	/* Searching forwards.  */
X	    {
X	      register int lim = 0;
X	      register unsigned char *p;
X	      int irange = range;
X	      if (startpos < size1 && startpos + range >= size1)
X		lim = range - (size1 - startpos);
X
X	      p = ((unsigned char *)
X		   &(startpos >= size1 ? string2 - size1 : string1)[startpos]);
X
X              while (range > lim && !fastmap[translate 
X                                             ? translate[*p++]
X                                             : *p++])
X		    range--;
X	      startpos += irange - range;
X	    }
X	  else				/* Searching backwards.  */
X	    {
X	      register unsigned char c;
X
X              if (string1 == 0 || startpos >= size1)
X		c = string2[startpos - size1];
X	      else 
X		c = string1[startpos];
X
X              c &= 0xff;
X	      if (translate ? !fastmap[translate[c]] : !fastmap[c])
X		goto advance;
X	    }
X	}
X
X      if (range >= 0 && startpos == total_size
X	  && fastmap && pbufp->can_be_null == 0)
X	return -1;
X
X      val = re_match_2 (pbufp, string1, size1, string2, size2, startpos,
X			regs, mstop);
X      if (val >= 0)
X	return startpos;
X      if (val == -2)
X	return -2;
X
X#ifdef C_ALLOCA
X      alloca (0);
X#endif /* C_ALLOCA */
X
X    advance:
X      if (!range) 
X        break;
X      else if (range > 0) 
X        {
X          range--; 
X          startpos++;
X        }
X      else
X        {
X          range++; 
X          startpos--;
X        }
X    }
X  return -1;
X}
X
X
X
X#ifndef emacs   /* emacs never uses this.  */
Xint
Xre_match (pbufp, string, size, pos, regs)
X     struct re_pattern_buffer *pbufp;
X     char *string;
X     int size, pos;
X     struct re_registers *regs;
X{
X  return re_match_2 (pbufp, (char *) 0, 0, string, size, pos, regs, size); 
X}
X#endif /* not emacs */
X
X
X/* The following are used for re_match_2, defined below:  */
X
X/* Roughly the maximum number of failure points on the stack.  Would be
X   exactly that if always pushed MAX_NUM_FAILURE_ITEMS each time we failed.  */
X   
Xint re_max_failures = 2000;
X
X/* Routine used by re_match_2.  */
Xstatic int bcmp_translate ();
X
X
X/* Structure and accessing macros used in re_match_2:  */
X
Xstruct register_info
X{
X  unsigned is_active : 1;
X  unsigned matched_something : 1;
X};
X
X#define IS_ACTIVE(R)  ((R).is_active)
X#define MATCHED_SOMETHING(R)  ((R).matched_something)
X
X
X/* Macros used by re_match_2:  */
X
X
X/* I.e., regstart, regend, and reg_info.  */
X
X#define NUM_REG_ITEMS  3
X
X/* We push at most this many things on the stack whenever we
X   fail.  The `+ 2' refers to PATTERN_PLACE and STRING_PLACE, which are
X   arguments to the PUSH_FAILURE_POINT macro.  */
X
X#define MAX_NUM_FAILURE_ITEMS   (RE_NREGS * NUM_REG_ITEMS + 2)
X
X
X/* We push this many things on the stack whenever we fail.  */
X
X#define NUM_FAILURE_ITEMS  (last_used_reg * NUM_REG_ITEMS + 2)
X
X
X/* This pushes most of the information about the current state we will want
X   if we ever fail back to it.  */
X
X#define PUSH_FAILURE_POINT(pattern_place, string_place)			\
X  {									\
X    short last_used_reg, this_reg;					\
X									\
X    /* Find out how many registers are active or have been matched.	\
X       (Aside from register zero, which is only set at the end.)  */	\
X    for (last_used_reg = RE_NREGS - 1; last_used_reg > 0; last_used_reg--)\
X      if (regstart[last_used_reg] != (unsigned char *) -1)		\
X        break;								\
X									\
X    if (stacke - stackp < NUM_FAILURE_ITEMS)				\
X      {									\
X	unsigned char **stackx;						\
X	unsigned int len = stacke - stackb;				\
X	if (len > re_max_failures * MAX_NUM_FAILURE_ITEMS)		\
X	  return -2;							\
X									\
X        /* Roughly double the size of the stack.  */			\
X        stackx = (unsigned char **) alloca (2 * len			\
X                                            * sizeof (unsigned char *));\
X	/* Only copy what is in use.  */				\
X        bcopy (stackb, stackx, len * sizeof (char *));			\
X	stackp = stackx + (stackp - stackb);				\
X	stackb = stackx;						\
X	stacke = stackb + 2 * len;					\
X      }									\
X									\
X    /* Now push the info for each of those registers.  */		\
X    for (this_reg = 1; this_reg <= last_used_reg; this_reg++)		\
X      {									\
X        *stackp++ = regstart[this_reg];					\
X        *stackp++ = regend[this_reg];					\
X        *stackp++ = (unsigned char *) &reg_info[this_reg];		\
X      }									\
X									\
X    /* Push how many registers we saved.  */				\
X    *stackp++ = (unsigned char *) last_used_reg;			\
X									\
X    *stackp++ = pattern_place;                                          \
X    *stackp++ = string_place;                                           \
X  }
X  
X
X/* This pops what PUSH_FAILURE_POINT pushes.  */
X
X#define POP_FAILURE_POINT()						\
X  {									\
X    int temp;								\
X    stackp -= 2;		/* Remove failure points.  */		\
X    temp = (int) *--stackp;	/* How many regs pushed.  */	        \
X    temp *= NUM_REG_ITEMS;	/* How much to take off the stack.  */	\
X    stackp -= temp; 		/* Remove the register info.  */	\
X  }
X
X
X#define MATCHING_IN_FIRST_STRING  (dend == end_match_1)
X
X/* Is true if there is a first string and if PTR is pointing anywhere
X   inside it or just past the end.  */
X   
X#define IS_IN_FIRST_STRING(ptr) 					\
X	(size1 && string1 <= (ptr) && (ptr) <= string1 + size1)
X
X/* Call before fetching a character with *d.  This switches over to
X   string2 if necessary.  */
X
X#define PREFETCH							\
X while (d == dend)						    	\
X  {									\
X    /* end of string2 => fail.  */					\
X    if (dend == end_match_2) 						\
X      goto fail;							\
X    /* end of string1 => advance to string2.  */ 			\
X    d = string2;						        \
X    dend = end_match_2;							\
X  }
X
X
X/* Call this when have matched something; it sets `matched' flags for the
X   registers corresponding to the subexpressions of which we currently
X   are inside.  */
X#define SET_REGS_MATCHED 						\
X  { unsigned this_reg; 							\
X    for (this_reg = 0; this_reg < RE_NREGS; this_reg++) 		\
X      { 								\
X        if (IS_ACTIVE(reg_info[this_reg]))				\
X          MATCHED_SOMETHING(reg_info[this_reg]) = 1;			\
X        else								\
X          MATCHED_SOMETHING(reg_info[this_reg]) = 0;			\
X      } 								\
X  }
X
X/* Test if at very beginning or at very end of the virtual concatenation
X   of string1 and string2.  If there is only one string, we've put it in
X   string2.  */
X
X#define AT_STRINGS_BEG  (d == (size1 ? string1 : string2)  ||  !size2)
X#define AT_STRINGS_END  (d == end2)	
X
X#define AT_WORD_BOUNDARY						\
X  (AT_STRINGS_BEG || AT_STRINGS_END || IS_A_LETTER (d - 1) != IS_A_LETTER (d))
X
X/* We have two special cases to check for: 
X     1) if we're past the end of string1, we have to look at the first
X        character in string2;
X     2) if we're before the beginning of string2, we have to look at the
X        last character in string1; we assume there is a string1, so use
X        this in conjunction with AT_STRINGS_BEG.  */
X#define IS_A_LETTER(d)							\
X  (SYNTAX ((d) == end1 ? *string2 : (d) == string2 - 1 ? *(end1 - 1) : *(d))\
X   == Sword)
X
X
X/* Match the pattern described by PBUFP against the virtual
X   concatenation of STRING1 and STRING2, which are of SIZE1 and SIZE2,
X   respectively.  Start the match at index POS in the virtual
X   concatenation of STRING1 and STRING2.  In REGS, return the indices of
X   the virtual concatenation of STRING1 and STRING2 that matched the
X   entire PBUFP->buffer and its contained subexpressions.  Do not
X   consider matching one past the index MSTOP in the virtual
X   concatenation of STRING1 and STRING2.
X
X   If pbufp->fastmap is nonzero, then it had better be up to date.
X
X   The reason that the data to match are specified as two components
X   which are to be regarded as concatenated is so this function can be
X   used directly on the contents of an Emacs buffer.
X
X   -1 is returned if there is no match.  -2 is returned if there is an
X   error (such as match stack overflow).  Otherwise the value is the
X   length of the substring which was matched.  */
X
Xint
Xre_match_2 (pbufp, string1_arg, size1, string2_arg, size2, pos, regs, mstop)
X     struct re_pattern_buffer *pbufp;
X     char *string1_arg, *string2_arg;
X     int size1, size2;
X     int pos;
X     struct re_registers *regs;
X     int mstop;
X{
X  register unsigned char *p = (unsigned char *) pbufp->buffer;
X
X  /* Pointer to beyond end of buffer.  */
X  register unsigned char *pend = p + pbufp->used;
X
X  unsigned char *string1 = (unsigned char *) string1_arg;
X  unsigned char *string2 = (unsigned char *) string2_arg;
X  unsigned char *end1;		/* Just past end of first string.  */
X  unsigned char *end2;		/* Just past end of second string.  */
X
X  /* Pointers into string1 and string2, just past the last characters in
X     each to consider matching.  */
X  unsigned char *end_match_1, *end_match_2;
X
X  register unsigned char *d, *dend;
X  register int mcnt;			/* Multipurpose.  */
X  unsigned char *translate = (unsigned char *) pbufp->translate;
X  unsigned is_a_jump_n = 0;
X
X /* Failure point stack.  Each place that can handle a failure further
X    down the line pushes a failure point on this stack.  It consists of
X    restart, regend, and reg_info for all registers corresponding to the
X    subexpressions we're currently inside, plus the number of such
X    registers, and, finally, two char *'s.  The first char * is where to
X    resume scanning the pattern; the second one is where to resume
X    scanning the strings.  If the latter is zero, the failure point is a
X    ``dummy''; if a failure happens and the failure point is a dummy, it
X    gets discarded and the next next one is tried.  */
X
X  unsigned char *initial_stack[MAX_NUM_FAILURE_ITEMS * NFAILURES];
X  unsigned char **stackb = initial_stack;
X  unsigned char **stackp = stackb;
X  unsigned char **stacke = &stackb[MAX_NUM_FAILURE_ITEMS * NFAILURES];
X
X
X  /* Information on the contents of registers. These are pointers into
X     the input strings; they record just what was matched (on this
X     attempt) by a subexpression part of the pattern, that is, the
X     regnum-th regstart pointer points to where in the pattern we began
X     matching and the regnum-th regend points to right after where we
X     stopped matching the regnum-th subexpression.  (The zeroth register
X     keeps track of what the whole pattern matches.)  */
X     
X  unsigned char *regstart[RE_NREGS];
X  unsigned char *regend[RE_NREGS];
X
X  /* The is_active field of reg_info helps us keep track of which (possibly
X     nested) subexpressions we are currently in. The matched_something
X     field of reg_info[reg_num] helps us tell whether or not we have
X     matched any of the pattern so far this time through the reg_num-th
X     subexpression.  These two fields get reset each time through any
X     loop their register is in.  */
X
X  struct register_info reg_info[RE_NREGS];
X
X
X  /* The following record the register info as found in the above
X     variables when we find a match better than any we've seen before. 
X     This happens as we backtrack through the failure points, which in
X     turn happens only if we have not yet matched the entire string.  */
X
X  unsigned best_regs_set = 0;
X  unsigned char *best_regstart[RE_NREGS];
X  unsigned char *best_regend[RE_NREGS];
X
X  /* Initialize subexpression text positions to -1 to mark ones that no
X     \( or ( and \) or ) has been seen for. Also set all registers to
X     inactive and mark them as not having matched anything or ever
X     failed.  */
X  for (mcnt = 0; mcnt < RE_NREGS; mcnt++)
X    {
X      regstart[mcnt] = regend[mcnt] = (unsigned char *) -1;
X      IS_ACTIVE (reg_info[mcnt]) = 0;
X      MATCHED_SOMETHING (reg_info[mcnt]) = 0;
X    }
X  
X  if (regs)
X    for (mcnt = 0; mcnt < RE_NREGS; mcnt++)
X      regs->start[mcnt] = regs->end[mcnt] = -1;
X
X  /* Set up pointers to ends of strings.
X     Don't allow the second string to be empty unless both are empty.  */
X  if (size2 == 0)
X    {
X      string2 = string1;
X      size2 = size1;
X      string1 = 0;
X      size1 = 0;
X    }
X  end1 = string1 + size1;
X  end2 = string2 + size2;
X
X  /* Compute where to stop matching, within the two strings.  */
X  if (mstop <= size1)
X    {
X      end_match_1 = string1 + mstop;
X      end_match_2 = string2;
X    }
X  else
X    {
X      end_match_1 = end1;
X      end_match_2 = string2 + mstop - size1;
X    }
X
X  /* `p' scans through the pattern as `d' scans through the data. `dend'
X     is the end of the input string that `d' points within. `d' is
X     advanced into the following input string whenever necessary, but
X     this happens before fetching; therefore, at the beginning of the
X     loop, `d' can be pointing at the end of a string, but it cannot
X     equal string2.  */
X
X  if (size1 != 0 && pos <= size1)
X    d = string1 + pos, dend = end_match_1;
X  else
X    d = string2 + pos - size1, dend = end_match_2;
X
X
X  /* This loops over pattern commands.  It exits by returning from the
X     function if match is complete, or it drops through if match fails
X     at this starting point in the input data.  */
X
X  while (1)
X    {
X      is_a_jump_n = 0;
X      /* End of pattern means we might have succeeded.  */
X      if (p == pend)
X	{
X	  /* If not end of string, try backtracking.  Otherwise done.  */
X          if (d != end_match_2)
X	    {
X              if (stackp != stackb)
X                {
X                  /* More failure points to try.  */
X
X                  unsigned in_same_string = 
X        	          	IS_IN_FIRST_STRING (best_regend[0]) 
X	        	        == MATCHING_IN_FIRST_STRING;
X
X                  /* If exceeds best match so far, save it.  */
X                  if (! best_regs_set
X                      || (in_same_string && d > best_regend[0])
X                      || (! in_same_string && ! MATCHING_IN_FIRST_STRING))
X                    {
X                      best_regs_set = 1;
X                      best_regend[0] = d;	/* Never use regstart[0].  */
X                      
X                      for (mcnt = 1; mcnt < RE_NREGS; mcnt++)
X                        {
X                          best_regstart[mcnt] = regstart[mcnt];
X                          best_regend[mcnt] = regend[mcnt];
X                        }
X                    }
X                  goto fail;	       
X                }
X              /* If no failure points, don't restore garbage.  */
X              else if (best_regs_set)   
X                {
X	      restore_best_regs:
X                  /* Restore best match.  */
X                  d = best_regend[0];
X                  
X		  for (mcnt = 0; mcnt < RE_NREGS; mcnt++)
X		    {
X		      regstart[mcnt] = best_regstart[mcnt];
X		      regend[mcnt] = best_regend[mcnt];
X		    }
X                }
X            }
X
X	  /* If caller wants register contents data back, convert it 
X	     to indices.  */
X	  if (regs)
X	    {
X	      regs->start[0] = pos;
X	      if (MATCHING_IN_FIRST_STRING)
X		regs->end[0] = d - string1;
X	      else
X		regs->end[0] = d - string2 + size1;
X	      for (mcnt = 1; mcnt < RE_NREGS; mcnt++)
X		{
X		  if (regend[mcnt] == (unsigned char *) -1)
X		    {
X		      regs->start[mcnt] = -1;
X		      regs->end[mcnt] = -1;
X		      continue;
X		    }
X		  if (IS_IN_FIRST_STRING (regstart[mcnt]))
X		    regs->start[mcnt] = regstart[mcnt] - string1;
X		  else
X		    regs->start[mcnt] = regstart[mcnt] - string2 + size1;
X                    
X		  if (IS_IN_FIRST_STRING (regend[mcnt]))
X		    regs->end[mcnt] = regend[mcnt] - string1;
X		  else
X		    regs->end[mcnt] = regend[mcnt] - string2 + size1;
X		}
X	    }
X	  return d - pos - (MATCHING_IN_FIRST_STRING 
X			    ? string1 
X			    : string2 - size1);
X        }
X
X      /* Otherwise match next pattern command.  */
X#ifdef SWITCH_ENUM_BUG
X      switch ((int) ((enum regexpcode) *p++))
X#else
X      switch ((enum regexpcode) *p++)
X#endif
X	{
X
X	/* \( [or `(', as appropriate] is represented by start_memory,
X           \) by stop_memory.  Both of those commands are followed by
X           a register number in the next byte.  The text matched
X           within the \( and \) is recorded under that number.  */
X	case start_memory:
X          regstart[*p] = d;
X          IS_ACTIVE (reg_info[*p]) = 1;
X          MATCHED_SOMETHING (reg_info[*p]) = 0;
X          p++;
X          break;
X
X	case stop_memory:
X          regend[*p] = d;
X          IS_ACTIVE (reg_info[*p]) = 0;
X
X          /* If just failed to match something this time around with a sub-
X	     expression that's in a loop, try to force exit from the loop.  */
X          if ((! MATCHED_SOMETHING (reg_info[*p])
X	       || (enum regexpcode) p[-3] == start_memory)
X	      && (p + 1) != pend)              
X            {
X	      register unsigned char *p2 = p + 1;
X              mcnt = 0;
X              switch (*p2++)
X                {
X                  case jump_n:
X		    is_a_jump_n = 1;
X                  case finalize_jump:
X		  case maybe_finalize_jump:
X		  case jump:
X		  case dummy_failure_jump:
X                    EXTRACT_NUMBER_AND_INCR (mcnt, p2);
X		    if (is_a_jump_n)
X		      p2 += 2;
X                    break;
X                }
X	      p2 += mcnt;
X        
X              /* If the next operation is a jump backwards in the pattern
X	         to an on_failure_jump, exit from the loop by forcing a
X                 failure after pushing on the stack the on_failure_jump's 
X                 jump in the pattern, and d.  */
X	      if (mcnt < 0 && (enum regexpcode) *p2++ == on_failure_jump)
X		{
X                  EXTRACT_NUMBER_AND_INCR (mcnt, p2);
X                  PUSH_FAILURE_POINT (p2 + mcnt, d);
X                  goto fail;
X                }
X            }
X          p++;
X          break;
X
X	/* \<digit> has been turned into a `duplicate' command which is
X           followed by the numeric value of <digit> as the register number.  */
X        case duplicate:
X	  {
X	    int regno = *p++;   /* Get which register to match against */
X	    register unsigned char *d2, *dend2;
X
X	    /* Where in input to try to start matching.  */
X            d2 = regstart[regno];
X            
X            /* Where to stop matching; if both the place to start and
X               the place to stop matching are in the same string, then
X               set to the place to stop, otherwise, for now have to use
X               the end of the first string.  */
X
X            dend2 = ((IS_IN_FIRST_STRING (regstart[regno]) 
X		      == IS_IN_FIRST_STRING (regend[regno]))
X		     ? regend[regno] : end_match_1);
X	    while (1)
X	      {
X		/* If necessary, advance to next segment in register
X                   contents.  */
X		while (d2 == dend2)
X		  {
X		    if (dend2 == end_match_2) break;
X		    if (dend2 == regend[regno]) break;
X		    d2 = string2, dend2 = regend[regno];  /* end of string1 => advance to string2. */
X		  }
X		/* At end of register contents => success */
X		if (d2 == dend2) break;
X
X		/* If necessary, advance to next segment in data.  */
X		PREFETCH;
X
X		/* How many characters left in this segment to match.  */
X		mcnt = dend - d;
X                
X		/* Want how many consecutive characters we can match in
X                   one shot, so, if necessary, adjust the count.  */
X                if (mcnt > dend2 - d2)
X		  mcnt = dend2 - d2;
X                  
X		/* Compare that many; failure if mismatch, else move
X                   past them.  */
X		if (translate 
X                    ? bcmp_translate (d, d2, mcnt, translate) 
X                    : bcmp (d, d2, mcnt))
X		  goto fail;
X		d += mcnt, d2 += mcnt;
X	      }
X	  }
X	  break;
X
X	case anychar:
X	  PREFETCH;	  /* Fetch a data character. */
X	  /* Match anything but a newline, maybe even a null.  */
X	  if ((translate ? translate[*d] : *d) == '\n'
X              || ((obscure_syntax & RE_DOT_NOT_NULL) 
X                  && (translate ? translate[*d] : *d) == '\000'))
X	    goto fail;
X	  SET_REGS_MATCHED;
X          d++;
X	  break;
X
X	case charset:
X	case charset_not:
X	  {
X	    int not = 0;	    /* Nonzero for charset_not.  */
X	    register int c;
X	    if (*(p - 1) == (unsigned char) charset_not)
X	      not = 1;
X
X	    PREFETCH;	    /* Fetch a data character. */
X
X	    if (translate)
X	      c = translate[*d];
X	    else
X	      c = *d;
X
X	    if (c < *p * BYTEWIDTH
X		&& p[1 + c / BYTEWIDTH] & (1 << (c % BYTEWIDTH)))
X	      not = !not;
X
X	    p += 1 + *p;
X
X	    if (!not) goto fail;
X	    SET_REGS_MATCHED;
X            d++;
X	    break;
X	  }
X
X	case begline:
X          if ((size1 != 0 && d == string1)
X              || (size1 == 0 && size2 != 0 && d == string2)
X              || (d && d[-1] == '\n')
X              || (size1 == 0 && size2 == 0))
X            break;
X          else
X            goto fail;
X            
X	case endline:
X	  if (d == end2
X	      || (d == end1 ? (size2 == 0 || *string2 == '\n') : *d == '\n'))
X	    break;
X	  goto fail;
X
X	/* `or' constructs are handled by starting each alternative with
X           an on_failure_jump that points to the start of the next
X           alternative.  Each alternative except the last ends with a
X           jump to the joining point.  (Actually, each jump except for
X           the last one really jumps to the following jump, because
X           tensioning the jumps is a hassle.)  */
X
X	/* The start of a stupid repeat has an on_failure_jump that points
X	   past the end of the repeat text. This makes a failure point so 
X           that on failure to match a repetition, matching restarts past
X           as many repetitions have been found with no way to fail and
X           look for another one.  */
X
X	/* A smart repeat is similar but loops back to the on_failure_jump
X	   so that each repetition makes another failure point.  */
X
X	case on_failure_jump:
X        on_failure:
X          EXTRACT_NUMBER_AND_INCR (mcnt, p);
X          PUSH_FAILURE_POINT (p + mcnt, d);
X          break;
X
X	/* The end of a smart repeat has a maybe_finalize_jump back.
X	   Change it either to a finalize_jump or an ordinary jump.  */
X	case maybe_finalize_jump:
X          EXTRACT_NUMBER_AND_INCR (mcnt, p);
X	  {
X	    register unsigned char *p2 = p;
X	    /* Compare what follows with the beginning of the repeat.
X	       If we can establish that there is nothing that they would
X	       both match, we can change to finalize_jump.  */
X	    while (p2 + 1 != pend
X		   && (*p2 == (unsigned char) stop_memory
X		       || *p2 == (unsigned char) start_memory))
X	      p2 += 2;				/* Skip over reg number.  */
X	    if (p2 == pend)
X	      p[-3] = (unsigned char) finalize_jump;
X	    else if (*p2 == (unsigned char) exactn
X		     || *p2 == (unsigned char) endline)
X	      {
X		register int c = *p2 == (unsigned char) endline ? '\n' : p2[2];
X		register unsigned char *p1 = p + mcnt;
X		/* p1[0] ... p1[2] are an on_failure_jump.
X		   Examine what follows that.  */
X		if (p1[3] == (unsigned char) exactn && p1[5] != c)
X		  p[-3] = (unsigned char) finalize_jump;
X		else if (p1[3] == (unsigned char) charset
X			 || p1[3] == (unsigned char) charset_not)
X		  {
X		    int not = p1[3] == (unsigned char) charset_not;
X		    if (c < p1[4] * BYTEWIDTH
X			&& p1[5 + c / BYTEWIDTH] & (1 << (c % BYTEWIDTH)))
X		      not = !not;
X		    /* `not' is 1 if c would match.  */
X		    /* That means it is not safe to finalize.  */
X		    if (!not)
X		      p[-3] = (unsigned char) finalize_jump;
X		  }
X	      }
X	  }
X	  p -= 2;		/* Point at relative address again.  */
X	  if (p[-1] != (unsigned char) finalize_jump)
X	    {
X	      p[-1] = (unsigned char) jump;	
X	      goto nofinalize;
X	    }
X        /* Note fall through.  */
X
X	/* The end of a stupid repeat has a finalize_jump back to the
X           start, where another failure point will be made which will
X           point to after all the repetitions found so far.  */
X
X        /* Take off failure points put on by matching on_failure_jump 
X           because didn't fail.  Also remove the register information
X           put on by the on_failure_jump.  */
X        case finalize_jump:
X          POP_FAILURE_POINT ();
X        /* Note fall through.  */
X        
X	/* Jump without taking off any failure points.  */
X        case jump:
X	nofinalize:
X	  EXTRACT_NUMBER_AND_INCR (mcnt, p);
X	  p += mcnt;
X	  break;
X
X        case dummy_failure_jump:
X          /* Normally, the on_failure_jump pushes a failure point, which
X             then gets popped at finalize_jump.  We will end up at
X             finalize_jump, also, and with a pattern of, say, `a+', we
X             are skipping over the on_failure_jump, so we have to push
X             something meaningless for finalize_jump to pop.  */
X          PUSH_FAILURE_POINT (0, 0);
X          goto nofinalize;
X
X
X        /* Have to succeed matching what follows at least n times.  Then
X          just handle like an on_failure_jump.  */
X        case succeed_n: 
X          EXTRACT_NUMBER (mcnt, p + 2);
X          /* Originally, this is how many times we HAVE to succeed.  */
X          if (mcnt)
X            {
X               mcnt--;
X	       p += 2;
X               STORE_NUMBER_AND_INCR (p, mcnt);
X            }
X	  else if (mcnt == 0)
X            {
X	      p[2] = unused;
X              p[3] = unused;
X              goto on_failure;
X            }
X          else
X	    { 
X              fprintf (stderr, "regex: the succeed_n's n is not set.\n");
X              exit (1);
X	    }
X          break;
X        
X        case jump_n: 
X          EXTRACT_NUMBER (mcnt, p + 2);
X          /* Originally, this is how many times we CAN jump.  */
X          if (mcnt)
X            {
X               mcnt--;
X               STORE_NUMBER(p + 2, mcnt);
X	       goto nofinalize;	     /* Do the jump without taking off
X			                any failure points.  */
X            }
X          /* If don't have to jump any more, skip over the rest of command.  */
X	  else      
X	    p += 4;		     
X          break;
X        
X	case set_number_at:
X	  {
X  	    register unsigned char *p1;
X
X            EXTRACT_NUMBER_AND_INCR (mcnt, p);
X            p1 = p + mcnt;
X            EXTRACT_NUMBER_AND_INCR (mcnt, p);
X	    STORE_NUMBER (p1, mcnt);
X            break;
X          }
X
X        /* Ignore these.  Used to ignore the n of succeed_n's which
X           currently have n == 0.  */
X        case unused:
X          break;
X
X        case wordbound:
X	  if (AT_WORD_BOUNDARY)
X	    break;
X	  goto fail;
X
X	case notwordbound:
X	  if (AT_WORD_BOUNDARY)
X	    goto fail;
X	  break;
X
X	case wordbeg:
X          /* Have to check if AT_STRINGS_BEG before looking at d - 1.  */
X	  if (IS_A_LETTER (d) && (AT_STRINGS_BEG || !IS_A_LETTER (d - 1)))
X	    break;
X	  goto fail;
X
X	case wordend:
X          /* Have to check if AT_STRINGS_BEG before looking at d - 1.  */
X	  if (!AT_STRINGS_BEG && IS_A_LETTER (d - 1) 
X              && (!IS_A_LETTER (d) || AT_STRINGS_END))
X	    break;
X	  goto fail;
X
X#ifdef emacs
X	case before_dot:
X	  if (PTR_CHAR_POS (d) >= point)
X	    goto fail;
X	  break;
X
X	case at_dot:
X	  if (PTR_CHAR_POS (d) != point)
X	    goto fail;
X	  break;
X
X	case after_dot:
X	  if (PTR_CHAR_POS (d) <= point)
X	    goto fail;
X	  break;
X
X	case wordchar:
X	  mcnt = (int) Sword;
X	  goto matchsyntax;
X
X	case syntaxspec:
X	  mcnt = *p++;
X	matchsyntax:
X	  PREFETCH;
X	  if (SYNTAX (*d++) != (enum syntaxcode) mcnt) goto fail;
X          SET_REGS_MATCHED;
X	  break;
X	  
X	case notwordchar:
X	  mcnt = (int) Sword;
X	  goto matchnotsyntax;
X
X	case notsyntaxspec:
X	  mcnt = *p++;
X	matchnotsyntax:
X	  PREFETCH;
X	  if (SYNTAX (*d++) == (enum syntaxcode) mcnt) goto fail;
X	  SET_REGS_MATCHED;
X          break;
X
X#else /* not emacs */
X
X	case wordchar:
X	  PREFETCH;
X          if (!IS_A_LETTER (d))
X            goto fail;
X	  SET_REGS_MATCHED;
X	  break;
X	  
X	case notwordchar:
X	  PREFETCH;
X	  if (IS_A_LETTER (d))
X            goto fail;
X          SET_REGS_MATCHED;
X	  break;
X
X#endif /* not emacs */
X
X	case begbuf:
X          if (AT_STRINGS_BEG)
X            break;
X          goto fail;
X
X        case endbuf:
X	  if (AT_STRINGS_END)
X	    break;
X	  goto fail;
X
X	case exactn:
X	  /* Match the next few pattern characters exactly.
X	     mcnt is how many characters to match.  */
X	  mcnt = *p++;
X	  /* This is written out as an if-else so we don't waste time
X             testing `translate' inside the loop.  */
X          if (translate)
X	    {
X	      do
X		{
X		  PREFETCH;
X		  if (translate[*d++] != *p++) goto fail;
X		}
X	      while (--mcnt);
X	    }
X	  else
X	    {
X	      do
X		{
X		  PREFETCH;
X		  if (*d++ != *p++) goto fail;
X		}
X	      while (--mcnt);
X	    }
X	  SET_REGS_MATCHED;
X          break;
X	}
X      continue;  /* Successfully executed one pattern command; keep going.  */
X
X    /* Jump here if any matching operation fails. */
X    fail:
X      if (stackp != stackb)
X	/* A restart point is known.  Restart there and pop it. */
X	{
X          short last_used_reg, this_reg;
X          
X          /* If this failure point is from a dummy_failure_point, just
X             skip it.  */
X	  if (!stackp[-2])
X            {
X              POP_FAILURE_POINT ();
X              goto fail;
X            }
X
X          d = *--stackp;
X	  p = *--stackp;
X          if (d >= string1 && d <= end1)
X	    dend = end_match_1;
X          /* Restore register info.  */
X          last_used_reg = (short) *--stackp;
X          
X          /* Make the ones that weren't saved -1 or 0 again.  */
X          for (this_reg = RE_NREGS - 1; this_reg > last_used_reg; this_reg--)
X            {
X              regend[this_reg] = (unsigned char *) -1;
X              regstart[this_reg] = (unsigned char *) -1;
X              IS_ACTIVE (reg_info[this_reg]) = 0;
X              MATCHED_SOMETHING (reg_info[this_reg]) = 0;
X            }
X          
X          /* And restore the rest from the stack.  */
X          for ( ; this_reg > 0; this_reg--)
X            {
X              reg_info[this_reg] = *(struct register_info *) *--stackp;
X              regend[this_reg] = *--stackp;
X              regstart[this_reg] = *--stackp;
X            }
X	}
X      else
X        break;   /* Matching at this starting point really fails.  */
X    }
X
X  if (best_regs_set)
X    goto restore_best_regs;
X  return -1;         			/* Failure to match.  */
X}
X
X
Xstatic int
Xbcmp_translate (s1, s2, len, translate)
X     unsigned char *s1, *s2;
X     register int len;
X     unsigned char *translate;
X{
X  register unsigned char *p1 = s1, *p2 = s2;
X  while (len)
X    {
X      if (translate [*p1++] != translate [*p2++]) return 1;
X      len--;
X    }
X  return 0;
X}
X
X
X
X/* Entry points compatible with 4.2 BSD regex library.  */
X
X#ifndef emacs
X
Xstatic struct re_pattern_buffer re_comp_buf;
X
Xchar *
Xre_comp (s)
X     char *s;
X{
X  if (!s)
X    {
X      if (!re_comp_buf.buffer)
X	return "No previous regular expression";
X      return 0;
X    }
X
X  if (!re_comp_buf.buffer)
X    {
X      if (!(re_comp_buf.buffer = (char *) malloc (200)))
X	return "Memory exhausted";
X      re_comp_buf.allocated = 200;
X      if (!(re_comp_buf.fastmap = (char *) malloc (1 << BYTEWIDTH)))
X	return "Memory exhausted";
X    }
X  return re_compile_pattern (s, strlen (s), &re_comp_buf);
X}
X
Xint
Xre_exec (s)
X     char *s;
X{
X  int len = strlen (s);
X  return 0 <= re_search (&re_comp_buf, s, len, 0, len,
X			 (struct re_registers *) 0);
X}
X#endif /* not emacs */
X
X
X
X#ifdef test
X
X#include <stdio.h>
X
X/* Indexed by a character, gives the upper case equivalent of the
X   character.  */
X
Xchar upcase[0400] = 
X  { 000, 001, 002, 003, 004, 005, 006, 007,
X    010, 011, 012, 013, 014, 015, 016, 017,
X    020, 021, 022, 023, 024, 025, 026, 027,
X    030, 031, 032, 033, 034, 035, 036, 037,
X    040, 041, 042, 043, 044, 045, 046, 047,
X    050, 051, 052, 053, 054, 055, 056, 057,
X    060, 061, 062, 063, 064, 065, 066, 067,
X    070, 071, 072, 073, 074, 075, 076, 077,
X    0100, 0101, 0102, 0103, 0104, 0105, 0106, 0107,
X    0110, 0111, 0112, 0113, 0114, 0115, 0116, 0117,
X    0120, 0121, 0122, 0123, 0124, 0125, 0126, 0127,
X    0130, 0131, 0132, 0133, 0134, 0135, 0136, 0137,
X    0140, 0101, 0102, 0103, 0104, 0105, 0106, 0107,
X    0110, 0111, 0112, 0113, 0114, 0115, 0116, 0117,
X    0120, 0121, 0122, 0123, 0124, 0125, 0126, 0127,
X    0130, 0131, 0132, 0173, 0174, 0175, 0176, 0177,
X    0200, 0201, 0202, 0203, 0204, 0205, 0206, 0207,
X    0210, 0211, 0212, 0213, 0214, 0215, 0216, 0217,
X    0220, 0221, 0222, 0223, 0224, 0225, 0226, 0227,
X    0230, 0231, 0232, 0233, 0234, 0235, 0236, 0237,
X    0240, 0241, 0242, 0243, 0244, 0245, 0246, 0247,
X    0250, 0251, 0252, 0253, 0254, 0255, 0256, 0257,
X    0260, 0261, 0262, 0263, 0264, 0265, 0266, 0267,
X    0270, 0271, 0272, 0273, 0274, 0275, 0276, 0277,
X    0300, 0301, 0302, 0303, 0304, 0305, 0306, 0307,
X    0310, 0311, 0312, 0313, 0314, 0315, 0316, 0317,
X    0320, 0321, 0322, 0323, 0324, 0325, 0326, 0327,
X    0330, 0331, 0332, 0333, 0334, 0335, 0336, 0337,
X    0340, 0341, 0342, 0343, 0344, 0345, 0346, 0347,
X    0350, 0351, 0352, 0353, 0354, 0355, 0356, 0357,
X    0360, 0361, 0362, 0363, 0364, 0365, 0366, 0367,
X    0370, 0371, 0372, 0373, 0374, 0375, 0376, 0377
X  };
X
X#ifdef canned
X
X#include "tests.h"
X
Xtypedef enum { extended_test, basic_test } test_type;
X
X/* Use this to run the tests we've thought of.  */
X
Xvoid
Xmain ()
X{
X  test_type t = extended_test;
X
X  if (t == basic_test)
X    {
X      printf ("Running basic tests:\n\n");
X      test_posix_basic ();
X    }
X  else if (t == extended_test)
X    {
X      printf ("Running extended tests:\n\n");
X      test_posix_extended (); 
X    }
X}
X
X#else /* not canned */
X
X/* Use this to run interactive tests.  */
X
Xvoid
Xmain (argc, argv)
X     int argc;
X     char **argv;
X{
X  char pat[80];
X  struct re_pattern_buffer buf;
X  int i;
X  char c;
X  char fastmap[(1 << BYTEWIDTH)];
X
X  /* Allow a command argument to specify the style of syntax.  */
X  if (argc > 1)
X    obscure_syntax = atoi (argv[1]);
X
X  buf.allocated = 40;
X  buf.buffer = (char *) malloc (buf.allocated);
X  buf.fastmap = fastmap;
X  buf.translate = upcase;
X
X  while (1)
X    {
X      gets (pat);
X
X      if (*pat)
X	{
X          re_compile_pattern (pat, strlen(pat), &buf);
X
X	  for (i = 0; i < buf.used; i++)
X	    printchar (buf.buffer[i]);
X
X	  putchar ('\n');
X
X	  printf ("%d allocated, %d used.\n", buf.allocated, buf.used);
X
X	  re_compile_fastmap (&buf);
X	  printf ("Allowed by fastmap: ");
X	  for (i = 0; i < (1 << BYTEWIDTH); i++)
X	    if (fastmap[i]) printchar (i);
X	  putchar ('\n');
X	}
X
X      gets (pat);	/* Now read the string to match against */
X
X      i = re_match (&buf, pat, strlen (pat), 0, 0);
X      printf ("Match value %d.\n", i);
X    }
X}
X
X#endif
X
X
X#ifdef NOTDEF
Xprint_buf (bufp)
X     struct re_pattern_buffer *bufp;
X{
X  int i;
X
X  printf ("buf is :\n----------------\n");
X  for (i = 0; i < bufp->used; i++)
X    printchar (bufp->buffer[i]);
X  
X  printf ("\n%d allocated, %d used.\n", bufp->allocated, bufp->used);
X  
X  printf ("Allowed by fastmap: ");
X  for (i = 0; i < (1 << BYTEWIDTH); i++)
X    if (bufp->fastmap[i])
X      printchar (i);
X  printf ("\nAllowed by translate: ");
X  if (bufp->translate)
X    for (i = 0; i < (1 << BYTEWIDTH); i++)
X      if (bufp->translate[i])
X	printchar (i);
X  printf ("\nfastmap is%s accurate\n", bufp->fastmap_accurate ? "" : "n't");
X  printf ("can %s be null\n----------", bufp->can_be_null ? "" : "not");
X}
X#endif /* NOTDEF */
X
Xprintchar (c)
X     char c;
X{
X  if (c < 040 || c >= 0177)
X    {
X      putchar ('\\');
X      putchar (((c >> 6) & 3) + '0');
X      putchar (((c >> 3) & 7) + '0');
X      putchar ((c & 7) + '0');
X    }
X  else
X    putchar (c);
X}
X
Xerror (string)
X     char *string;
X{
X  puts (string);
X  exit (1);
X}
X#endif /* test */
END_OF_FILE
if test 83766 -ne `wc -c <'regex.c'`; then
    echo shar: \"'regex.c'\" unpacked with wrong size!
fi
# end of 'regex.c'
fi
if test -f 'getdate.y' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'getdate.y'\"
else
echo shar: Extracting \"'getdate.y'\" \(21433 characters\)
sed "s/^X//" >'getdate.y' <<'END_OF_FILE'
X%{
X/* $Revision: 2.1 $
X**
X**  Originally written by Steven M. Bellovin <smb@research.att.com> while
X**  at the University of North Carolina at Chapel Hill.  Later tweaked by
X**  a couple of people on Usenet.  Completely overhauled by Rich $alz
X**  <rsalz@bbn.com> and Jim Berets <jberets@bbn.com> in August, 1990;
X**  send any email to Rich.
X**
X**  This grammar has eight shift/reduce conflicts.
X**
X**  This code is in the public domain and has no copyright.
X*/
X/* SUPPRESS 287 on yaccpar_sccsid *//* Unusd static variable */
X/* SUPPRESS 288 on yyerrlab *//* Label unused */
X
X#ifdef __GNUC__
X#define alloca __builtin_alloca
X#else
X#ifdef sparc
X#include <alloca.h>
X#else
X#ifdef _AIX /* for Bison */
X#pragma alloca
X#else
Xchar *alloca ();
X#endif
X#endif
X#endif
X
X#include <stdio.h>
X#include <ctype.h>
X
X#if	defined(vms)
X#include <types.h>
X#include <time.h>
X#else
X#include <sys/types.h>
X#if	defined(USG)
X/*
X**  Uncomment the next line if you need to do a tzset() call to set the
X**  timezone, and don't have ftime().  Some SystemV releases, I think.
X*/
X/*#define NEED_TZSET */
Xstruct timeb {
X    time_t		time;		/* Seconds since the epoch	*/
X    unsigned short	millitm;	/* Field not used		*/
X    short		timezone;
X    short		dstflag;	/* Field not used		*/
X};
X#else
X#include <sys/timeb.h>
X#endif	/* defined(USG) */
X#if	defined(BSD4_2) || defined(BSD4_1C)
X#include <sys/time.h>
X#else
X#include <time.h>
X#endif	/* defined(BSD4_2) */
X#endif	/* defined(vms) */
X
X#if defined (STDC_HEADERS) || defined (USG)
X#include <string.h>
X#endif
X
Xextern struct tm	*localtime();
X
X#define yyparse getdate_yyparse
X#define yylex getdate_yylex
X#define yyerror getdate_yyerror
X
X#if	!defined(lint) && !defined(SABER)
Xstatic char RCS[] =
X	"$Header: str2date.y,v 2.1 90/09/06 08:15:06 cronan Exp $";
X#endif	/* !defined(lint) && !defined(SABER) */
X
X
X#define EPOCH		1970
X#define HOUR(x)		(x * 60)
X#define SECSPERDAY	(24L * 60L * 60L)
X
X
X/*
X**  An entry in the lexical lookup table.
X*/
Xtypedef struct _TABLE {
X    char	*name;
X    int		type;
X    time_t	value;
X} TABLE;
X
X
X/*
X**  Daylight-savings mode:  on, off, or not yet known.
X*/
Xtypedef enum _DSTMODE {
X    DSTon, DSToff, DSTmaybe
X} DSTMODE;
X
X/*
X**  Meridian:  am, pm, or 24-hour style.
X*/
Xtypedef enum _MERIDIAN {
X    MERam, MERpm, MER24
X} MERIDIAN;
X
X
X/*
X**  Global variables.  We could get rid of most of these by using a good
X**  union as the yacc stack.  (This routine was originally written before
X**  yacc had the %union construct.)  Maybe someday; right now we only use
X**  the %union very rarely.
X*/
Xstatic char	*yyInput;
Xstatic DSTMODE	yyDSTmode;
Xstatic time_t	yyDayOrdinal;
Xstatic time_t	yyDayNumber;
Xstatic int	yyHaveDate;
Xstatic int	yyHaveDay;
Xstatic int	yyHaveRel;
Xstatic int	yyHaveTime;
Xstatic int	yyHaveZone;
Xstatic time_t	yyTimezone;
Xstatic time_t	yyDay;
Xstatic time_t	yyHour;
Xstatic time_t	yyMinutes;
Xstatic time_t	yyMonth;
Xstatic time_t	yySeconds;
Xstatic time_t	yyYear;
Xstatic MERIDIAN	yyMeridian;
Xstatic time_t	yyRelMonth;
Xstatic time_t	yyRelSeconds;
X
X%}
X
X%union {
X    time_t		Number;
X    enum _MERIDIAN	Meridian;
X}
X
X%token	tAGO tDAY tDAYZONE tID tMERIDIAN tMINUTE_UNIT tMONTH tMONTH_UNIT
X%token	tSEC_UNIT tSNUMBER tUNUMBER tZONE
X
X%type	<Number>	tDAY tDAYZONE tMINUTE_UNIT tMONTH tMONTH_UNIT
X%type	<Number>	tSEC_UNIT tSNUMBER tUNUMBER tZONE
X%type	<Meridian>	tMERIDIAN o_merid
X
X%%
X
Xspec	: /* NULL */
X	| spec item
X	;
X
Xitem	: time {
X	    yyHaveTime++;
X	}
X	| zone {
X	    yyHaveZone++;
X	}
X	| date {
X	    yyHaveDate++;
X	}
X	| day {
X	    yyHaveDay++;
X	}
X	| rel {
X	    yyHaveRel++;
X	}
X	| number
X	;
X
Xtime	: tUNUMBER tMERIDIAN {
X	    yyHour = $1;
X	    yyMinutes = 0;
X	    yySeconds = 0;
X	    yyMeridian = $2;
X	}
X	| tUNUMBER ':' tUNUMBER o_merid {
X	    yyHour = $1;
X	    yyMinutes = $3;
X	    yySeconds = 0;
X	    yyMeridian = $4;
X	}
X	| tUNUMBER ':' tUNUMBER tSNUMBER {
X	    yyHour = $1;
X	    yyMinutes = $3;
X	    yyMeridian = MER24;
X	    yyDSTmode = DSToff;
X	    yyTimezone = - ($4 % 100 + ($4 / 100) * 60);
X	}
X	| tUNUMBER ':' tUNUMBER ':' tUNUMBER o_merid {
X	    yyHour = $1;
X	    yyMinutes = $3;
X	    yySeconds = $5;
X	    yyMeridian = $6;
X	}
X	| tUNUMBER ':' tUNUMBER ':' tUNUMBER tSNUMBER {
X	    yyHour = $1;
X	    yyMinutes = $3;
X	    yySeconds = $5;
X	    yyMeridian = MER24;
X	    yyDSTmode = DSToff;
X	    yyTimezone = - ($6 % 100 + ($6 / 100) * 60);
X	}
X	;
X
Xzone	: tZONE {
X	    yyTimezone = $1;
X	    yyDSTmode = DSToff;
X	}
X	| tDAYZONE {
X	    yyTimezone = $1;
X	    yyDSTmode = DSTon;
X	}
X	;
X
Xday	: tDAY {
X	    yyDayOrdinal = 1;
X	    yyDayNumber = $1;
X	}
X	| tDAY ',' {
X	    yyDayOrdinal = 1;
X	    yyDayNumber = $1;
X	}
X	| tUNUMBER tDAY {
X	    yyDayOrdinal = $1;
X	    yyDayNumber = $2;
X	}
X	;
X
Xdate	: tUNUMBER '/' tUNUMBER {
X	    yyMonth = $1;
X	    yyDay = $3;
X	}
X	| tUNUMBER '/' tUNUMBER '/' tUNUMBER {
X	    yyMonth = $1;
X	    yyDay = $3;
X	    yyYear = $5;
X	}
X	| tMONTH tUNUMBER {
X	    yyMonth = $1;
X	    yyDay = $2;
X	}
X	| tMONTH tUNUMBER ',' tUNUMBER {
X	    yyMonth = $1;
X	    yyDay = $2;
X	    yyYear = $4;
X	}
X	| tUNUMBER tMONTH {
X	    yyMonth = $2;
X	    yyDay = $1;
X	}
X	| tUNUMBER tMONTH tUNUMBER {
X	    yyMonth = $2;
X	    yyDay = $1;
X	    yyYear = $3;
X	}
X	;
X
Xrel	: relunit tAGO {
X	    yyRelSeconds = -yyRelSeconds;
X	    yyRelMonth = -yyRelMonth;
X	}
X	| relunit
X	;
X
Xrelunit	: tUNUMBER tMINUTE_UNIT {
X	    yyRelSeconds += $1 * $2 * 60L;
X	}
X	| tSNUMBER tMINUTE_UNIT {
X	    yyRelSeconds += $1 * $2 * 60L;
X	}
X	| tMINUTE_UNIT {
X	    yyRelSeconds += $1 * 60L;
X	}
X	| tSNUMBER tSEC_UNIT {
X	    yyRelSeconds += $1;
X	}
X	| tUNUMBER tSEC_UNIT {
X	    yyRelSeconds += $1;
X	}
X	| tSEC_UNIT {
X	    yyRelSeconds++;
X	}
X	| tSNUMBER tMONTH_UNIT {
X	    yyRelMonth += $1 * $2;
X	}
X	| tUNUMBER tMONTH_UNIT {
X	    yyRelMonth += $1 * $2;
X	}
X	| tMONTH_UNIT {
X	    yyRelMonth += $1;
X	}
X	;
X
Xnumber	: tUNUMBER {
X	    if (yyHaveTime && yyHaveDate && !yyHaveRel)
X		yyYear = $1;
X	    else {
X		if($1>10000) {
X		    time_t date_part;
X
X		    date_part= $1/10000;
X		    yyHaveDate++;
X		    yyDay= (date_part)%100;
X		    yyMonth= (date_part/100)%100;
X		    yyYear = date_part/10000;
X		} 
X	        yyHaveTime++;
X		if ($1 < 100) {
X		    yyHour = $1;
X		    yyMinutes = 0;
X		}
X		else {
X		    yyHour = $1 / 100;
X		    yyMinutes = $1 % 100;
X		}
X		yySeconds = 0;
X		yyMeridian = MER24;
X	    }
X	}
X	;
X
Xo_merid	: /* NULL */ {
X	    $$ = MER24;
X	}
X	| tMERIDIAN {
X	    $$ = $1;
X	}
X	;
X
X%%
X
X/* Month and day table. */
Xstatic TABLE	MonthDayTable[] = {
X    { "january",	tMONTH,  1 },
X    { "february",	tMONTH,  2 },
X    { "march",		tMONTH,  3 },
X    { "april",		tMONTH,  4 },
X    { "may",		tMONTH,  5 },
X    { "june",		tMONTH,  6 },
X    { "july",		tMONTH,  7 },
X    { "august",		tMONTH,  8 },
X    { "september",	tMONTH,  9 },
X    { "sept",		tMONTH,  9 },
X    { "october",	tMONTH, 10 },
X    { "november",	tMONTH, 11 },
X    { "december",	tMONTH, 12 },
X    { "sunday",		tDAY, 0 },
X    { "monday",		tDAY, 1 },
X    { "tuesday",	tDAY, 2 },
X    { "tues",		tDAY, 2 },
X    { "wednesday",	tDAY, 3 },
X    { "wednes",		tDAY, 3 },
X    { "thursday",	tDAY, 4 },
X    { "thur",		tDAY, 4 },
X    { "thurs",		tDAY, 4 },
X    { "friday",		tDAY, 5 },
X    { "saturday",	tDAY, 6 },
X    { NULL }
X};
X
X/* Time units table. */
Xstatic TABLE	UnitsTable[] = {
X    { "year",		tMONTH_UNIT,	12 },
X    { "month",		tMONTH_UNIT,	1 },
X    { "fortnight",	tMINUTE_UNIT,	14 * 24 * 60 },
X    { "week",		tMINUTE_UNIT,	7 * 24 * 60 },
X    { "day",		tMINUTE_UNIT,	1 * 24 * 60 },
X    { "hour",		tMINUTE_UNIT,	60 },
X    { "minute",		tMINUTE_UNIT,	1 },
X    { "min",		tMINUTE_UNIT,	1 },
X    { "second",		tSEC_UNIT,	1 },
X    { "sec",		tSEC_UNIT,	1 },
X    { NULL }
X};
X
X/* Assorted relative-time words. */
Xstatic TABLE	OtherTable[] = {
X    { "tomorrow",	tMINUTE_UNIT,	1 * 24 * 60 },
X    { "yesterday",	tMINUTE_UNIT,	-1 * 24 * 60 },
X    { "today",		tMINUTE_UNIT,	0 },
X    { "now",		tMINUTE_UNIT,	0 },
X    { "last",		tUNUMBER,	-1 },
X    { "this",		tMINUTE_UNIT,	0 },
X    { "next",		tUNUMBER,	2 },
X    { "first",		tUNUMBER,	1 },
X/*  { "second",		tUNUMBER,	2 }, */
X    { "third",		tUNUMBER,	3 },
X    { "fourth",		tUNUMBER,	4 },
X    { "fifth",		tUNUMBER,	5 },
X    { "sixth",		tUNUMBER,	6 },
X    { "seventh",	tUNUMBER,	7 },
X    { "eighth",		tUNUMBER,	8 },
X    { "ninth",		tUNUMBER,	9 },
X    { "tenth",		tUNUMBER,	10 },
X    { "eleventh",	tUNUMBER,	11 },
X    { "twelfth",	tUNUMBER,	12 },
X    { "ago",		tAGO,	1 },
X    { NULL }
X};
X
X/* The timezone table. */
Xstatic TABLE	TimezoneTable[] = {
X    { "gmt",	tZONE,     HOUR( 0) },	/* Greenwich Mean */
X    { "ut",	tZONE,     HOUR( 0) },	/* Universal (Coordinated) */
X    { "utc",	tZONE,     HOUR( 0) },
X    { "wet",	tZONE,     HOUR( 0) },	/* Western European */
X    { "bst",	tDAYZONE,  HOUR( 0) },	/* British Summer */
X    { "wat",	tZONE,     HOUR( 1) },	/* West Africa */
X    { "at",	tZONE,     HOUR( 2) },	/* Azores */
X#if	0
X    /* For completeness.  BST is also British Summer, and GST is
X     * also Guam Standard. */
X    { "bst",	tZONE,     HOUR( 3) },	/* Brazil Standard */
X    { "gst",	tZONE,     HOUR( 3) },	/* Greenland Standard */
X#endif
X    { "nft",	tZONE,     HOUR(3.5) },	/* Newfoundland */
X    { "nst",	tZONE,     HOUR(3.5) },	/* Newfoundland Standard */
X    { "ndt",	tDAYZONE,  HOUR(3.5) },	/* Newfoundland Daylight */
X    { "ast",	tZONE,     HOUR( 4) },	/* Atlantic Standard */
X    { "adt",	tDAYZONE,  HOUR( 4) },	/* Atlantic Daylight */
X    { "est",	tZONE,     HOUR( 5) },	/* Eastern Standard */
X    { "edt",	tDAYZONE,  HOUR( 5) },	/* Eastern Daylight */
X    { "cst",	tZONE,     HOUR( 6) },	/* Central Standard */
X    { "cdt",	tDAYZONE,  HOUR( 6) },	/* Central Daylight */
X    { "mst",	tZONE,     HOUR( 7) },	/* Mountain Standard */
X    { "mdt",	tDAYZONE,  HOUR( 7) },	/* Mountain Daylight */
X    { "pst",	tZONE,     HOUR( 8) },	/* Pacific Standard */
X    { "pdt",	tDAYZONE,  HOUR( 8) },	/* Pacific Daylight */
X    { "yst",	tZONE,     HOUR( 9) },	/* Yukon Standard */
X    { "ydt",	tDAYZONE,  HOUR( 9) },	/* Yukon Daylight */
X    { "hst",	tZONE,     HOUR(10) },	/* Hawaii Standard */
X    { "hdt",	tDAYZONE,  HOUR(10) },	/* Hawaii Daylight */
X    { "cat",	tZONE,     HOUR(10) },	/* Central Alaska */
X    { "ahst",	tZONE,     HOUR(10) },	/* Alaska-Hawaii Standard */
X    { "nt",	tZONE,     HOUR(11) },	/* Nome */
X    { "idlw",	tZONE,     HOUR(12) },	/* International Date Line West */
X    { "cet",	tZONE,     -HOUR(1) },	/* Central European */
X    { "met",	tZONE,     -HOUR(1) },	/* Middle European */
X    { "mewt",	tZONE,     -HOUR(1) },	/* Middle European Winter */
X    { "mest",	tDAYZONE,  -HOUR(1) },	/* Middle European Summer */
X    { "swt",	tZONE,     -HOUR(1) },	/* Swedish Winter */
X    { "sst",	tDAYZONE,  -HOUR(1) },	/* Swedish Summer */
X    { "fwt",	tZONE,     -HOUR(1) },	/* French Winter */
X    { "fst",	tDAYZONE,  -HOUR(1) },	/* French Summer */
X    { "eet",	tZONE,     -HOUR(2) },	/* Eastern Europe, USSR Zone 1 */
X    { "bt",	tZONE,     -HOUR(3) },	/* Baghdad, USSR Zone 2 */
X    { "it",	tZONE,     -HOUR(3.5) },/* Iran */
X    { "zp4",	tZONE,     -HOUR(4) },	/* USSR Zone 3 */
X    { "zp5",	tZONE,     -HOUR(5) },	/* USSR Zone 4 */
X    { "ist",	tZONE,     -HOUR(5.5) },/* Indian Standard */
X    { "zp6",	tZONE,     -HOUR(6) },	/* USSR Zone 5 */
X#if	0
X    /* For completeness.  NST is also Newfoundland Stanard, nad SST is
X     * also Swedish Summer. */
X    { "nst",	tZONE,     -HOUR(6.5) },/* North Sumatra */
X    { "sst",	tZONE,     -HOUR(7) },	/* South Sumatra, USSR Zone 6 */
X#endif	/* 0 */
X    { "wast",	tZONE,     -HOUR(7) },	/* West Australian Standard */
X    { "wadt",	tDAYZONE,  -HOUR(7) },	/* West Australian Daylight */
X    { "jt",	tZONE,     -HOUR(7.5) },/* Java (3pm in Cronusland!) */
X    { "cct",	tZONE,     -HOUR(8) },	/* China Coast, USSR Zone 7 */
X    { "jst",	tZONE,     -HOUR(9) },	/* Japan Standard, USSR Zone 8 */
X    { "cast",	tZONE,     -HOUR(9.5) },/* Central Australian Standard */
X    { "cadt",	tDAYZONE,  -HOUR(9.5) },/* Central Australian Daylight */
X    { "east",	tZONE,     -HOUR(10) },	/* Eastern Australian Standard */
X    { "eadt",	tDAYZONE,  -HOUR(10) },	/* Eastern Australian Daylight */
X    { "gst",	tZONE,     -HOUR(10) },	/* Guam Standard, USSR Zone 9 */
X    { "nzt",	tZONE,     -HOUR(12) },	/* New Zealand */
X    { "nzst",	tZONE,     -HOUR(12) },	/* New Zealand Standard */
X    { "nzdt",	tDAYZONE,  -HOUR(12) },	/* New Zealand Daylight */
X    { "idle",	tZONE,     -HOUR(12) },	/* International Date Line East */
X    {  NULL  }
X};
X
X/* Military timezone table. */
Xstatic TABLE	MilitaryTable[] = {
X    { "a",	tZONE,	HOUR(  1) },
X    { "b",	tZONE,	HOUR(  2) },
X    { "c",	tZONE,	HOUR(  3) },
X    { "d",	tZONE,	HOUR(  4) },
X    { "e",	tZONE,	HOUR(  5) },
X    { "f",	tZONE,	HOUR(  6) },
X    { "g",	tZONE,	HOUR(  7) },
X    { "h",	tZONE,	HOUR(  8) },
X    { "i",	tZONE,	HOUR(  9) },
X    { "k",	tZONE,	HOUR( 10) },
X    { "l",	tZONE,	HOUR( 11) },
X    { "m",	tZONE,	HOUR( 12) },
X    { "n",	tZONE,	HOUR(- 1) },
X    { "o",	tZONE,	HOUR(- 2) },
X    { "p",	tZONE,	HOUR(- 3) },
X    { "q",	tZONE,	HOUR(- 4) },
X    { "r",	tZONE,	HOUR(- 5) },
X    { "s",	tZONE,	HOUR(- 6) },
X    { "t",	tZONE,	HOUR(- 7) },
X    { "u",	tZONE,	HOUR(- 8) },
X    { "v",	tZONE,	HOUR(- 9) },
X    { "w",	tZONE,	HOUR(-10) },
X    { "x",	tZONE,	HOUR(-11) },
X    { "y",	tZONE,	HOUR(-12) },
X    { "z",	tZONE,	HOUR(  0) },
X    { NULL }
X};
X
X
X
X
X/* ARGSUSED */
Xint
Xyyerror(s)
X    char	*s;
X{
X  return 0;
X}
X
X
Xstatic time_t
XToSeconds(Hours, Minutes, Seconds, Meridian)
X    time_t	Hours;
X    time_t	Minutes;
X    time_t	Seconds;
X    MERIDIAN	Meridian;
X{
X    if (Minutes < 0 || Minutes > 59 || Seconds < 0 || Seconds > 59)
X	return -1;
X    switch (Meridian) {
X    case MER24:
X	if (Hours < 0 || Hours > 23)
X	    return -1;
X	return (Hours * 60L + Minutes) * 60L + Seconds;
X    case MERam:
X	if (Hours < 1 || Hours > 12)
X	    return -1;
X	return (Hours * 60L + Minutes) * 60L + Seconds;
X    case MERpm:
X	if (Hours < 1 || Hours > 12)
X	    return -1;
X	return ((Hours + 12) * 60L + Minutes) * 60L + Seconds;
X    }
X    /* NOTREACHED */
X}
X
X
Xstatic time_t
XConvert(Month, Day, Year, Hours, Minutes, Seconds, Meridian, DSTmode)
X    time_t	Month;
X    time_t	Day;
X    time_t	Year;
X    time_t	Hours;
X    time_t	Minutes;
X    time_t	Seconds;
X    MERIDIAN	Meridian;
X    DSTMODE	DSTmode;
X{
X    static int	DaysInMonth[12] = {
X	31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
X    };
X    time_t	tod;
X    time_t	Julian;
X    int		i;
X
X    if (Year < 0)
X	Year = -Year;
X    if (Year < 100)
X	Year += 1900;
X    DaysInMonth[1] = Year % 4 == 0 && (Year % 100 != 0 || Year % 400 == 0)
X		    ? 29 : 28;
X    if (Year < EPOCH || Year > 1999
X     || Month < 1 || Month > 12
X     /* Lint fluff:  "conversion from long may lose accuracy" */
X     || Day < 1 || Day > DaysInMonth[(int)--Month])
X	return -1;
X
X    for (Julian = Day - 1, i = 0; i < Month; i++)
X	Julian += DaysInMonth[i];
X    for (i = EPOCH; i < Year; i++)
X	Julian += 365 + (i % 4 == 0);
X    Julian *= SECSPERDAY;
X    Julian += yyTimezone * 60L;
X    if ((tod = ToSeconds(Hours, Minutes, Seconds, Meridian)) < 0)
X	return -1;
X    Julian += tod;
X    if (DSTmode == DSTon
X     || (DSTmode == DSTmaybe && localtime(&Julian)->tm_isdst))
X	Julian -= 60 * 60;
X    return Julian;
X}
X
X
Xstatic time_t
XDSTcorrect(Start, Future)
X    time_t	Start;
X    time_t	Future;
X{
X    time_t	StartDay;
X    time_t	FutureDay;
X
X    StartDay = (localtime(&Start)->tm_hour + 1) % 24;
X    FutureDay = (localtime(&Future)->tm_hour + 1) % 24;
X    return (Future - Start) + (StartDay - FutureDay) * 60L * 60L;
X}
X
X
Xstatic time_t
XRelativeDate(Start, DayOrdinal, DayNumber)
X    time_t	Start;
X    time_t	DayOrdinal;
X    time_t	DayNumber;
X{
X    struct tm	*tm;
X    time_t	now;
X
X    now = Start;
X    tm = localtime(&now);
X    now += SECSPERDAY * ((DayNumber - tm->tm_wday + 7) % 7);
X    now += 7 * SECSPERDAY * (DayOrdinal <= 0 ? DayOrdinal : DayOrdinal - 1);
X    return DSTcorrect(Start, now);
X}
X
X
Xstatic time_t
XRelativeMonth(Start, RelMonth)
X    time_t	Start;
X    time_t	RelMonth;
X{
X    struct tm	*tm;
X    time_t	Month;
X    time_t	Year;
X
X    if (RelMonth == 0)
X	return 0;
X    tm = localtime(&Start);
X    Month = 12 * tm->tm_year + tm->tm_mon + RelMonth;
X    Year = Month / 12;
X    Month = Month % 12 + 1;
X    return DSTcorrect(Start,
X	    Convert(Month, (time_t)tm->tm_mday, Year,
X		(time_t)tm->tm_hour, (time_t)tm->tm_min, (time_t)tm->tm_sec,
X		MER24, DSTmaybe));
X}
X
X
Xstatic int
XLookupWord(buff)
X    char		*buff;
X{
X    register char	*p;
X    register char	*q;
X    register TABLE	*tp;
X    int			i;
X    int			abbrev;
X
X    /* Make it lowercase. */
X    for (p = buff; *p; p++)
X	if (isupper(*p))
X	    *p = tolower(*p);
X
X    if (strcmp(buff, "am") == 0 || strcmp(buff, "a.m.") == 0) {
X	yylval.Meridian = MERam;
X	return tMERIDIAN;
X    }
X    if (strcmp(buff, "pm") == 0 || strcmp(buff, "p.m.") == 0) {
X	yylval.Meridian = MERpm;
X	return tMERIDIAN;
X    }
X
X    /* See if we have an abbreviation for a month. */
X    if (strlen(buff) == 3)
X	abbrev = 1;
X    else if (strlen(buff) == 4 && buff[3] == '.') {
X	abbrev = 1;
X	buff[3] = '\0';
X    }
X    else
X	abbrev = 0;
X
X    for (tp = MonthDayTable; tp->name; tp++) {
X	if (abbrev) {
X	    if (strncmp(buff, tp->name, 3) == 0) {
X		yylval.Number = tp->value;
X		return tp->type;
X	    }
X	}
X	else if (strcmp(buff, tp->name) == 0) {
X	    yylval.Number = tp->value;
X	    return tp->type;
X	}
X    }
X
X    for (tp = TimezoneTable; tp->name; tp++)
X	if (strcmp(buff, tp->name) == 0) {
X	    yylval.Number = tp->value;
X	    return tp->type;
X	}
X
X    for (tp = UnitsTable; tp->name; tp++)
X	if (strcmp(buff, tp->name) == 0) {
X	    yylval.Number = tp->value;
X	    return tp->type;
X	}
X
X    /* Strip off any plural and try the units table again. */
X    i = strlen(buff) - 1;
X    if (buff[i] == 's') {
X	buff[i] = '\0';
X	for (tp = UnitsTable; tp->name; tp++)
X	    if (strcmp(buff, tp->name) == 0) {
X		yylval.Number = tp->value;
X		return tp->type;
X	    }
X	buff[i] = 's';		/* Put back for "this" in OtherTable. */
X    }
X
X    for (tp = OtherTable; tp->name; tp++)
X	if (strcmp(buff, tp->name) == 0) {
X	    yylval.Number = tp->value;
X	    return tp->type;
X	}
X
X    /* Military timezones. */
X    if (buff[1] == '\0' && isalpha(*buff)) {
X	for (tp = MilitaryTable; tp->name; tp++)
X	    if (strcmp(buff, tp->name) == 0) {
X		yylval.Number = tp->value;
X		return tp->type;
X	    }
X    }
X
X    /* Drop out any periods and try the timezone table again. */
X    for (i = 0, p = q = buff; *q; q++)
X	if (*q != '.')
X	    *p++ = *q;
X	else
X	    i++;
X    *p = '\0';
X    if (i)
X	for (tp = TimezoneTable; tp->name; tp++)
X	    if (strcmp(buff, tp->name) == 0) {
X		yylval.Number = tp->value;
X		return tp->type;
X	    }
X
X    return tID;
X}
X
X
Xint
Xyylex()
X{
X    register char	c;
X    register char	*p;
X    char		buff[20];
X    int			Count;
X    int			sign;
X
X    for ( ; ; ) {
X	while (isspace(*yyInput))
X	    yyInput++;
X
X	if (isdigit(c = *yyInput) || c == '-' || c == '+') {
X	    if (c == '-' || c == '+') {
X		sign = c == '-' ? -1 : 1;
X		if (!isdigit(*++yyInput))
X		    /* skip the '-' sign */
X		    continue;
X	    }
X	    else
X		sign = 0;
X	    for (yylval.Number = 0; isdigit(c = *yyInput++); )
X		yylval.Number = 10 * yylval.Number + c - '0';
X	    yyInput--;
X	    if (sign < 0)
X		yylval.Number = -yylval.Number;
X	    return sign ? tSNUMBER : tUNUMBER;
X	}
X	if (isalpha(c)) {
X	    for (p = buff; isalpha(c = *yyInput++) || c == '.'; )
X		if (p < &buff[sizeof buff - 1])
X		    *p++ = c;
X	    *p = '\0';
X	    yyInput--;
X	    return LookupWord(buff);
X	}
X	if (c != '(')
X	    return *yyInput++;
X	Count = 0;
X	do {
X	    c = *yyInput++;
X	    if (c == '\0')
X		return c;
X	    if (c == '(')
X		Count++;
X	    else if (c == ')')
X		Count--;
X	} while (Count > 0);
X    }
X}
X
X
Xtime_t
Xget_date(p, now)
X    char		*p;
X    struct timeb	*now;
X{
X    struct tm		*tm;
X    struct timeb	ftz;
X    time_t		Start;
X    time_t		tod;
X
X    yyInput = p;
X    if (now == NULL) {
X	now = &ftz;
X#if	defined(NEED_TZSET)
X	(void)time(&ftz.time);
X	/* Set the timezone global. */
X	tzset();
X	ftz.timezone = (int) timezone / 60;
X#else
X	(void)ftime(&ftz);
X#endif	/* defined(NEED_TZSET) */
X    }
X
X    tm = localtime(&now->time);
X    yyYear = tm->tm_year;
X    yyMonth = tm->tm_mon + 1;
X    yyDay = tm->tm_mday;
X    yyTimezone = now->timezone;
X    yyDSTmode = DSTmaybe;
X    yyHour = 0;
X    yyMinutes = 0;
X    yySeconds = 0;
X    yyMeridian = MER24;
X    yyRelSeconds = 0;
X    yyRelMonth = 0;
X    yyHaveDate = 0;
X    yyHaveDay = 0;
X    yyHaveRel = 0;
X    yyHaveTime = 0;
X    yyHaveZone = 0;
X
X    if (yyparse()
X     || yyHaveTime > 1 || yyHaveZone > 1 || yyHaveDate > 1 || yyHaveDay > 1)
X	return -1;
X
X    if (yyHaveDate || yyHaveTime || yyHaveDay) {
X	Start = Convert(yyMonth, yyDay, yyYear, yyHour, yyMinutes, yySeconds,
X		    yyMeridian, yyDSTmode);
X	if (Start < 0)
X	    return -1;
X    }
X    else {
X	Start = now->time;
X	if (!yyHaveRel)
X	    Start -= ((tm->tm_hour * 60L + tm->tm_min) * 60L) + tm->tm_sec;
X    }
X
X    Start += yyRelSeconds;
X    Start += RelativeMonth(Start, yyRelMonth);
X
X    if (yyHaveDay && !yyHaveDate) {
X	tod = RelativeDate(Start, yyDayOrdinal, yyDayNumber);
X	Start += tod;
X    }
X
X    /* Have to do *something* with a legitimate -1 so it's distinguishable
X     * from the error return value.  (Alternately could set errno on error.) */
X    return Start == -1 ? 0 : Start;
X}
X
X
X#if	defined(TEST)
X
X/* ARGSUSED */
Xmain(ac, av)
X    int		ac;
X    char	*av[];
X{
X    char	buff[128];
X    time_t	d;
X
X    (void)printf("Enter date, or blank line to exit.\n\t> ");
X    (void)fflush(stdout);
X    while (gets(buff) && buff[0]) {
X	d = get_date(buff, (struct timeb *)NULL);
X	if (d == -1)
X	    (void)printf("Bad format - couldn't convert.\n");
X	else
X	    (void)printf("%s", ctime(&d));
X	(void)printf("\t> ");
X	(void)fflush(stdout);
X    }
X    exit(0);
X    /* NOTREACHED */
X}
X#endif	/* defined(TEST) */
END_OF_FILE
if test 21433 -ne `wc -c <'getdate.y'`; then
    echo shar: \"'getdate.y'\" unpacked with wrong size!
fi
# end of 'getdate.y'
fi
if test -f 'rtape_lib.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'rtape_lib.c'\"
else
echo shar: Extracting \"'rtape_lib.c'\" \(13040 characters\)
sed "s/^X//" >'rtape_lib.c' <<'END_OF_FILE'
X/* Remote tape emulator subroutines.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/* JF: modified to make all rmtXXX calls into macros for speed */
X
X#ifndef lint
Xstatic char *RCSid = "$Header: /usr/src/local/usr.lib/librmt/RCS/rmtlib.c,v 1.7 89/03/23 14:09:51 root Exp Locker: root $";
X#endif
X
X/*
X * $Log:	rmtlib.c,v $
X * Revision 1.7  89/03/23  14:09:51  root
X * Fix from haynes@ucscc.ucsc.edu for use w/compat. ADR.
X * 
X * Revision 1.6  88/10/25  17:04:29  root
X * rexec code and a bug fix from srs!dan, miscellanious cleanup. ADR.
X * 
X * Revision 1.5  88/10/25  16:30:17  root
X * Fix from jeff@gatech.edu for getting user@host:dev right. ADR.
X * 
X * Revision 1.4  87/10/30  10:36:12  root
X * Made 4.2 syntax a compile time option. ADR.
X * 
X * Revision 1.3  87/04/22  11:16:48  root
X * Two fixes from parmelee@wayback.cs.cornell.edu to correctly
X * do fd biasing and rmt protocol on 'S' command. ADR.
X * 
X * Revision 1.2  86/10/09  16:38:53  root
X * Changed to reflect 4.3BSD rcp syntax. ADR.
X * 
X * Revision 1.1  86/10/09  16:17:35  root
X * Initial revision
X * 
X */
X
X/*
X *	rmt --- remote tape emulator subroutines
X *
X *	Originally written by Jeff Lee, modified some by Arnold Robbins
X *
X *	WARNING:  The man page rmt(8) for /etc/rmt documents the remote mag
X *	tape protocol which rdump and rrestore use.  Unfortunately, the man
X *	page is *WRONG*.  The author of the routines I'm including originally
X *	wrote his code just based on the man page, and it didn't work, so he
X *	went to the rdump source to figure out why.  The only thing he had to
X *	change was to check for the 'F' return code in addition to the 'E',
X *	and to separate the various arguments with \n instead of a space.  I
X *	personally don't think that this is much of a problem, but I wanted to
X *	point it out.
X *	-- Arnold Robbins
X *
X *	Redone as a library that can replace open, read, write, etc, by
X *	Fred Fish, with some additional work by Arnold Robbins.
X */
X 
X/* Use -DUSE_REXEC for rexec code, courtesy of Dan Kegel, srs!dan */
X
X#if defined(USG) && !defined(HAVE_MTIO)
X#define NO_RMTIOCTL
X#endif
X
X#include <stdio.h>
X#include <signal.h>
X#include <sys/types.h>
X
X#ifndef NO_RMTIOCTL
X#include <sys/ioctl.h>
X#include <sys/mtio.h>
X#endif
X
X#ifdef USE_REXEC
X#include <netdb.h>
X#endif
X
X#include <errno.h>
X#include <setjmp.h>
X#include <sys/stat.h>
X
X#define BUFMAGIC	64	/* a magic number for buffer sizes */
X
X/*
X *	MAXUNIT --- Maximum number of remote tape file units
X */
X#define MAXUNIT	4
X
X/*
X *	READ --- Return the number of the read side file descriptor
X *	WRITE --- Return the number of the write side file descriptor
X */
X#define READ(fd)	(Ctp[fd][0])
X#define WRITE(fd)	(Ptc[fd][1])
X
Xstatic int Ctp[MAXUNIT][2] = { -1, -1, -1, -1, -1, -1, -1, -1 };
Xstatic int Ptc[MAXUNIT][2] = { -1, -1, -1, -1, -1, -1, -1, -1 };
X
Xextern int errno;
X
Xchar *__rmt_path;
X
X/*
X *	_rmt_panic --- close off a remote tape connection
X */
X
Xstatic void _rmt_panic(fildes)
Xint fildes;
X{
X	close(READ(fildes));
X	close(WRITE(fildes));
X	READ(fildes) = -1;
X	WRITE(fildes) = -1;
X}
X
X
X
X/*
X *	command --- attempt to perform a remote tape command
X */
X
Xstatic int command(fildes, buf)
Xint fildes;
Xchar *buf;
X{
X	register int blen;
X#ifdef SIGNAL_VOID
X	void (*pstat)();
X#else
X	int (*pstat)();
X#endif
X
X/*
X *	save current pipe status and try to make the request
X */
X
X	blen = strlen(buf);
X	pstat = signal(SIGPIPE, SIG_IGN);
X	if (write(WRITE(fildes), buf, blen) == blen)
X	{
X		signal(SIGPIPE, pstat);
X		return(0);
X	}
X
X/*
X *	something went wrong. close down and go home
X */
X
X	signal(SIGPIPE, pstat);
X	_rmt_panic(fildes);
X
X	errno = EIO;
X	return(-1);
X}
X
X
X
X/*
X *	status --- retrieve the status from the pipe
X */
X
Xstatic int status(fildes)
Xint fildes;
X{
X	int i;
X	char c, *cp;
X	char buffer[BUFMAGIC];
X
X/*
X *	read the reply command line
X */
X
X	for (i = 0, cp = buffer; i < BUFMAGIC; i++, cp++)
X	{
X		if (read(READ(fildes), cp, 1) != 1)
X		{
X			_rmt_panic(fildes);
X			errno = EIO;
X			return(-1);
X		}
X		if (*cp == '\n')
X		{
X			*cp = 0;
X			break;
X		}
X	}
X
X	if (i == BUFMAGIC)
X	{
X		_rmt_panic(fildes);
X		errno = EIO;
X		return(-1);
X	}
X
X/*
X *	check the return status
X */
X
X	for (cp = buffer; *cp; cp++)
X		if (*cp != ' ')
X			break;
X
X	if (*cp == 'E' || *cp == 'F')
X	{
X		errno = atoi(cp + 1);
X		while (read(READ(fildes), &c, 1) == 1)
X			if (c == '\n')
X				break;
X
X		if (*cp == 'F')
X			_rmt_panic(fildes);
X
X		return(-1);
X	}
X
X/*
X *	check for mis-synced pipes
X */
X
X	if (*cp != 'A')
X	{
X		_rmt_panic(fildes);
X		errno = EIO;
X		return(-1);
X	}
X
X	return(atoi(cp + 1));
X}
X
X#ifdef USE_REXEC
X
X/*
X * _rmt_rexec
X *
X * execute /etc/rmt on a remote system using rexec().
X * Return file descriptor of bidirectional socket for stdin and stdout
X * If username is NULL, or an empty string, uses current username.
X *
X * ADR: By default, this code is not used, since it requires that
X * the user have a .netrc file in his/her home directory, or that the
X * application designer be willing to have rexec prompt for login and
X * password info. This may be unacceptable, and .rhosts files for use
X * with rsh are much more common on BSD systems.
X */
X
Xstatic int
X_rmt_rexec(host, user)
Xchar *host;
Xchar *user;		/* may be NULL */
X{
X	struct servent *rexecserv;
X	int save_stdin = dup(fileno(stdin));
X	int save_stdout = dup(fileno(stdout));
X	int tape_fd;		/* Return value. */
X
X	/*
X	 * When using cpio -o < filename, stdin is no longer the tty.
X	 * But the rexec subroutine reads the login and the passwd on stdin, 
X	 * to allow remote execution of the command.
X	 * So, reopen stdin and stdout on /dev/tty before the rexec and
X	 * give them back their original value after.
X	 */
X	if (freopen("/dev/tty", "r", stdin) == NULL)
X		freopen("/dev/null", "r", stdin);
X	if (freopen("/dev/tty", "w", stdout) == NULL)
X		freopen("/dev/null", "w", stdout);
X
X	rexecserv = getservbyname("exec", "tcp");
X	if (NULL == rexecserv) {
X		fprintf (stderr, "? exec/tcp: service not available.");
X		exit (-1);
X	}
X	if ((user != NULL) && *user == '\0')
X		user = (char *) NULL;
X	tape_fd = rexec (&host, rexecserv->s_port, user, NULL,
X			 "/etc/rmt", (int *)NULL);
X	fclose(stdin);
X	fdopen(save_stdin, "r");
X	fclose(stdout);
X	fdopen(save_stdout, "w");
X
X	return tape_fd;
X}
X#endif /* USE_REXEC */
X
X/*
X *	_rmt_open --- open a magtape device on system specified, as given user
X *
X *	file name has the form [user@]system:/dev/????
X#ifdef COMPAT
X *	file name has the form system[.user]:/dev/????
X#endif
X */
X
X#define MAXHOSTLEN	257	/* BSD allows very long host names... */
X
Xint __rmt_open (path, oflag, mode, bias)
Xchar *path;
Xint oflag;
Xint mode;
Xint bias;
X{
X	int i, rc;
X	char buffer[BUFMAGIC];
X	char system[MAXHOSTLEN];
X	char device[BUFMAGIC];
X	char login[BUFMAGIC];
X	char *sys, *dev, *user;
X
X	sys = system;
X	dev = device;
X	user = login;
X
X/*
X *	first, find an open pair of file descriptors
X */
X
X	for (i = 0; i < MAXUNIT; i++)
X		if (READ(i) == -1 && WRITE(i) == -1)
X			break;
X
X	if (i == MAXUNIT)
X	{
X		errno = EMFILE;
X		return(-1);
X	}
X
X/*
X *	pull apart system and device, and optional user
X *	don't munge original string
X *	if COMPAT is defined, also handle old (4.2) style person.site notation.
X */
X
X	while (*path != '@'
X#ifdef COMPAT
X			&& *path != '.'
X#endif
X			&& *path != ':') {
X		*sys++ = *path++;
X	}
X	*sys = '\0';
X	path++;
X
X	if (*(path - 1) == '@')
X	{
X		(void) strcpy (user, system);	/* saw user part of user@host */
X		sys = system;			/* start over */
X		while (*path != ':') {
X			*sys++ = *path++;
X		}
X		*sys = '\0';
X		path++;
X	}
X#ifdef COMPAT
X	else if (*(path - 1) == '.')
X	{
X		while (*path != ':') {
X			*user++ = *path++;
X		}
X		*user = '\0';
X		path++;
X	}
X#endif
X	else
X		*user = '\0';
X
X	while (*path) {
X		*dev++ = *path++;
X	}
X	*dev = '\0';
X
X#ifdef USE_REXEC
X/* 
X *	Execute the remote command using rexec 
X */
X	READ(i) = WRITE(i) = _rmt_rexec(system, login);
X	if (READ(i) < 0)
X		return -1;
X#else
X/*
X *	setup the pipes for the 'rsh' command and fork
X */
X
X	if (pipe(Ptc[i]) == -1 || pipe(Ctp[i]) == -1)
X		return(-1);
X
X	if ((rc = fork()) == -1)
X		return(-1);
X
X	if (rc == 0)
X	{
X		close(0);
X		dup(Ptc[i][0]);
X		close(Ptc[i][0]); close(Ptc[i][1]);
X		close(1);
X		dup(Ctp[i][1]);
X		close(Ctp[i][0]); close(Ctp[i][1]);
X		(void) setuid (getuid ());
X		(void) setgid (getgid ());
X		if (*login)
X		{
X			execl("/usr/ucb/rsh", "rsh", system, "-l", login,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bin/remsh", "remsh", system, "-l", login,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bin/rsh", "rsh", system, "-l", login,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bsd/rsh", "rsh", system, "-l", login,
X				"/etc/rmt", (char *)0);
X			execl("/usr/bin/nsh", "nsh", system, "-l", login,
X			        "/etc/rmt", (char *)0);
X		}
X		else
X		{
X			execl("/usr/ucb/rsh", "rsh", system,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bin/remsh", "remsh", system,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bin/rsh", "rsh", system,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bsd/rsh", "rsh", system,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bin/nsh", "nsh", system,
X			        "/etc/rmt", (char *)0);
X		}
X
X/*
X *	bad problems if we get here
X */
X
X		perror("remote shell exec");
X		exit(1);
X	}
X
X	close(Ptc[i][0]); close(Ctp[i][1]);
X#endif
X
X/*
X *	now attempt to open the tape device
X */
X
X	sprintf(buffer, "O%s\n%d\n", device, oflag);
X	if (command(i, buffer) == -1 || status(i) == -1)
X		return(-1);
X
X	return(i+bias);
X}
X
X
X
X/*
X *	_rmt_close --- close a remote magtape unit and shut down
X */
X
X int __rmt_close(fildes)
Xint fildes;
X{
X	int rc;
X
X	if (command(fildes, "C\n") != -1)
X	{
X		rc = status(fildes);
X
X		_rmt_panic(fildes);
X		return(rc);
X	}
X
X	return(-1);
X}
X
X
X
X/*
X *	_rmt_read --- read a buffer from a remote tape
X */
X
Xint __rmt_read(fildes, buf, nbyte)
Xint fildes;
Xchar *buf;
Xunsigned int nbyte;
X{
X	int rc, i;
X	char buffer[BUFMAGIC];
X
X	sprintf(buffer, "R%d\n", nbyte);
X	if (command(fildes, buffer) == -1 || (rc = status(fildes)) == -1)
X		return(-1);
X
X	for (i = 0; i < rc; i += nbyte, buf += nbyte)
X	{
X		nbyte = read(READ(fildes), buf, rc);
X		if (nbyte <= 0)
X		{
X			_rmt_panic(fildes);
X			errno = EIO;
X			return(-1);
X		}
X	}
X
X	return(rc);
X}
X
X
X
X/*
X *	_rmt_write --- write a buffer to the remote tape
X */
X
Xint __rmt_write(fildes, buf, nbyte)
Xint fildes;
Xchar *buf;
Xunsigned int nbyte;
X{
X	char buffer[BUFMAGIC];
X#ifdef SIGNAL_VOID
X	void (*pstat)();
X#else
X	int (*pstat)();
X#endif
X
X	sprintf(buffer, "W%d\n", nbyte);
X	if (command(fildes, buffer) == -1)
X		return(-1);
X
X	pstat = signal(SIGPIPE, SIG_IGN);
X	if (write(WRITE(fildes), buf, nbyte) == nbyte)
X	{
X		signal (SIGPIPE, pstat);
X		return(status(fildes));
X	}
X
X	signal (SIGPIPE, pstat);
X	_rmt_panic(fildes);
X	errno = EIO;
X	return(-1);
X}
X
X
X
X/*
X *	_rmt_lseek --- perform an imitation lseek operation remotely
X */
X
Xlong __rmt_lseek(fildes, offset, whence)
Xint fildes;
Xlong offset;
Xint whence;
X{
X	char buffer[BUFMAGIC];
X
X	sprintf(buffer, "L%d\n%d\n", offset, whence);
X	if (command(fildes, buffer) == -1)
X		return(-1);
X
X	return(status(fildes));
X}
X
X
X/*
X *	_rmt_ioctl --- perform raw tape operations remotely
X */
X
X#ifndef NO_RMTIOCTL
X__rmt_ioctl(fildes, op, arg)
Xint fildes, op;
Xchar *arg;
X{
X	char c;
X	int rc, cnt;
X	char buffer[BUFMAGIC];
X
X/*
X *	MTIOCOP is the easy one. nothing is transfered in binary
X */
X
X	if (op == MTIOCTOP)
X	{
X		sprintf(buffer, "I%d\n%d\n", ((struct mtop *) arg)->mt_op,
X			((struct mtop *) arg)->mt_count);
X		if (command(fildes, buffer) == -1)
X			return(-1);
X		return(status(fildes));
X	}
X
X/*
X *	we can only handle 2 ops, if not the other one, punt
X */
X
X	if (op != MTIOCGET)
X	{
X		errno = EINVAL;
X		return(-1);
X	}
X
X/*
X *	grab the status and read it directly into the structure
X *	this assumes that the status buffer is (hopefully) not
X *	padded and that 2 shorts fit in a long without any word
X *	alignment problems, ie - the whole struct is contiguous
X *	NOTE - this is probably NOT a good assumption.
X */
X
X	if (command(fildes, "S") == -1 || (rc = status(fildes)) == -1)
X		return(-1);
X
X	for (; rc > 0; rc -= cnt, arg += cnt)
X	{
X		cnt = read(READ(fildes), arg, rc);
X		if (cnt <= 0)
X		{
X			_rmt_panic(fildes);
X			errno = EIO;
X			return(-1);
X		}
X	}
X
X/*
X *	now we check for byte position. mt_type is a small integer field
X *	(normally) so we will check its magnitude. if it is larger than
X *	256, we will assume that the bytes are swapped and go through
X *	and reverse all the bytes
X */
X
X	if (((struct mtget *) arg)->mt_type < 256)
X		return(0);
X
X	for (cnt = 0; cnt < rc; cnt += 2)
X	{
X		c = arg[cnt];
X		arg[cnt] = arg[cnt+1];
X		arg[cnt+1] = c;
X	}
X
X	return(0);
X  }
X#endif /* NO_RMTIOCTL */
END_OF_FILE
if test 13040 -ne `wc -c <'rtape_lib.c'`; then
    echo shar: \"'rtape_lib.c'\" unpacked with wrong size!
fi
# end of 'rtape_lib.c'
fi
if test -f 'README' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'README'\"
else
echo shar: Extracting \"'README'\" \(1717 characters\)
sed "s/^X//" >'README' <<'END_OF_FILE'
XThis GNU tar 1.10.  Please send bug reports, etc., to
Xbug-gnu-utils@prep.ai.mit.edu.  
X
XThis is GNU tar.  It is based heavily on John Gilmore's public domain
Xtar, but with added features.  The manual is currently being written.
XAn old manual, surely riddled with errors, is in tar.texinfo.  Please
Xdon't send in bug reports about that manual.  In particular, the
Xmechanism for doing incremental dumps has been significantly changed.
X
XThe mt program is in the GNU cpio distribution.
X
XVarious people have been having problems using floppies on a NeXT.
XI've gotten conflicting reports about what should be done to solve the
Xproblems, and we have no way to test it ourselves.  If you don't have
X"rename" in your C library, you will need to find an implementation.
XI'm not sure if I want to roll in the GNU implementation into tar.
X
X	-mib
X
XUser-visible changes since 1.09:
X
XFilename to -G is optional.  -C works right.  
XNames +newer and +newer-mtime work right.
X
X-g is now +incremental
X-G is now +listed-incremental
X
XSparse files now work correctly.
X
X+volume is now called +label.
X
X+exclude now takes a filename argument, and +exclude-from does what
X+exclude used to do.
X
XExit status is now correct.
X
X+totals keeps track of total I/O and prints it when tar exits.
X
XWhen using +label with +extract, the label is now a regexp.
X
XNew option +tape-length (-L) does multi-volume handling like BSD dump:
Xyou tell tar how big the tape is and it will prompt at that point
Xinstead of waiting for a write error.
X
XNew backup scripts level-0 and level-1 which might be useful to
Xpeople.  They use a file "backup-specs" for information, and shouldn't
Xneed local modification.  These are what we use to do all our backups
Xat the FSF.
X
X
END_OF_FILE
if test 1717 -ne `wc -c <'README'`; then
    echo shar: \"'README'\" unpacked with wrong size!
fi
# end of 'README'
fi
if test -f 'COPYING' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'COPYING'\"
else
echo shar: Extracting \"'COPYING'\" \(12488 characters\)
sed "s/^X//" >'COPYING' <<'END_OF_FILE'
X
X		    GNU GENERAL PUBLIC LICENSE
X		     Version 1, February 1989
X
X Copyright (C) 1989 Free Software Foundation, Inc.
X                    675 Mass Ave, Cambridge, MA 02139, USA
X Everyone is permitted to copy and distribute verbatim copies
X of this license document, but changing it is not allowed.
X
X			    Preamble
X
X  The license agreements of most software companies try to keep users
Xat the mercy of those companies.  By contrast, our General Public
XLicense is intended to guarantee your freedom to share and change free
Xsoftware--to make sure the software is free for all its users.  The
XGeneral Public License applies to the Free Software Foundation's
Xsoftware and to any other program whose authors commit to using it.
XYou can use it for your programs, too.
X
X  When we speak of free software, we are referring to freedom, not
Xprice.  Specifically, the General Public License is designed to make
Xsure that you have the freedom to give away or sell copies of free
Xsoftware, that you receive source code or can get it if you want it,
Xthat you can change the software or use pieces of it in new free
Xprograms; and that you know you can do these things.
X
X  To protect your rights, we need to make restrictions that forbid
Xanyone to deny you these rights or to ask you to surrender the rights.
XThese restrictions translate to certain responsibilities for you if you
Xdistribute copies of the software, or if you modify it.
X
X  For example, if you distribute copies of a such a program, whether
Xgratis or for a fee, you must give the recipients all the rights that
Xyou have.  You must make sure that they, too, receive or can get the
Xsource code.  And you must tell them their rights.
X
X  We protect your rights with two steps: (1) copyright the software, and
X(2) offer you this license which gives you legal permission to copy,
Xdistribute and/or modify the software.
X
X  Also, for each author's protection and ours, we want to make certain
Xthat everyone understands that there is no warranty for this free
Xsoftware.  If the software is modified by someone else and passed on, we
Xwant its recipients to know that what they have is not the original, so
Xthat any problems introduced by others will not reflect on the original
Xauthors' reputations.
X
X  The precise terms and conditions for copying, distribution and
Xmodification follow.
X
X		    GNU GENERAL PUBLIC LICENSE
X   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
X
X  0. This License Agreement applies to any program or other work which
Xcontains a notice placed by the copyright holder saying it may be
Xdistributed under the terms of this General Public License.  The
X"Program", below, refers to any such program or work, and a "work based
Xon the Program" means either the Program or any work containing the
XProgram or a portion of it, either verbatim or with modifications.  Each
Xlicensee is addressed as "you".
X
X  1. You may copy and distribute verbatim copies of the Program's source
Xcode as you receive it, in any medium, provided that you conspicuously and
Xappropriately publish on each copy an appropriate copyright notice and
Xdisclaimer of warranty; keep intact all the notices that refer to this
XGeneral Public License and to the absence of any warranty; and give any
Xother recipients of the Program a copy of this General Public License
Xalong with the Program.  You may charge a fee for the physical act of
Xtransferring a copy.
X
X  2. You may modify your copy or copies of the Program or any portion of
Xit, and copy and distribute such modifications under the terms of Paragraph
X1 above, provided that you also do the following:
X
X    a) cause the modified files to carry prominent notices stating that
X    you changed the files and the date of any change; and
X
X    b) cause the whole of any work that you distribute or publish, that
X    in whole or in part contains the Program or any part thereof, either
X    with or without modifications, to be licensed at no charge to all
X    third parties under the terms of this General Public License (except
X    that you may choose to grant warranty protection to some or all
X    third parties, at your option).
X
X    c) If the modified program normally reads commands interactively when
X    run, you must cause it, when started running for such interactive use
X    in the simplest and most usual way, to print or display an
X    announcement including an appropriate copyright notice and a notice
X    that there is no warranty (or else, saying that you provide a
X    warranty) and that users may redistribute the program under these
X    conditions, and telling the user how to view a copy of this General
X    Public License.
X
X    d) You may charge a fee for the physical act of transferring a
X    copy, and you may at your option offer warranty protection in
X    exchange for a fee.
X
XMere aggregation of another independent work with the Program (or its
Xderivative) on a volume of a storage or distribution medium does not bring
Xthe other work under the scope of these terms.
X
X  3. You may copy and distribute the Program (or a portion or derivative of
Xit, under Paragraph 2) in object code or executable form under the terms of
XParagraphs 1 and 2 above provided that you also do one of the following:
X
X    a) accompany it with the complete corresponding machine-readable
X    source code, which must be distributed under the terms of
X    Paragraphs 1 and 2 above; or,
X
X    b) accompany it with a written offer, valid for at least three
X    years, to give any third party free (except for a nominal charge
X    for the cost of distribution) a complete machine-readable copy of the
X    corresponding source code, to be distributed under the terms of
X    Paragraphs 1 and 2 above; or,
X
X    c) accompany it with the information you received as to where the
X    corresponding source code may be obtained.  (This alternative is
X    allowed only for noncommercial distribution and only if you
X    received the program in object code or executable form alone.)
X
XSource code for a work means the preferred form of the work for making
Xmodifications to it.  For an executable file, complete source code means
Xall the source code for all modules it contains; but, as a special
Xexception, it need not include source code for modules which are standard
Xlibraries that accompany the operating system on which the executable
Xfile runs, or for standard header files or definitions files that
Xaccompany that operating system.
X
X  4. You may not copy, modify, sublicense, distribute or transfer the
XProgram except as expressly provided under this General Public License.
XAny attempt otherwise to copy, modify, sublicense, distribute or transfer
Xthe Program is void, and will automatically terminate your rights to use
Xthe Program under this License.  However, parties who have received
Xcopies, or rights to use copies, from you under this General Public
XLicense will not have their licenses terminated so long as such parties
Xremain in full compliance.
X
X  5. By copying, distributing or modifying the Program (or any work based
Xon the Program) you indicate your acceptance of this license to do so,
Xand all its terms and conditions.
X
X  6. Each time you redistribute the Program (or any work based on the
XProgram), the recipient automatically receives a license from the original
Xlicensor to copy, distribute or modify the Program subject to these
Xterms and conditions.  You may not impose any further restrictions on the
Xrecipients' exercise of the rights granted herein.
X
X  7. The Free Software Foundation may publish revised and/or new versions
Xof the General Public License from time to time.  Such new versions will
Xbe similar in spirit to the present version, but may differ in detail to
Xaddress new problems or concerns.
X
XEach version is given a distinguishing version number.  If the Program
Xspecifies a version number of the license which applies to it and "any
Xlater version", you have the option of following the terms and conditions
Xeither of that version or of any later version published by the Free
XSoftware Foundation.  If the Program does not specify a version number of
Xthe license, you may choose any version ever published by the Free Software
XFoundation.
X
X  8. If you wish to incorporate parts of the Program into other free
Xprograms whose distribution conditions are different, write to the author
Xto ask for permission.  For software which is copyrighted by the Free
XSoftware Foundation, write to the Free Software Foundation; we sometimes
Xmake exceptions for this.  Our decision will be guided by the two goals
Xof preserving the free status of all derivatives of our free software and
Xof promoting the sharing and reuse of software generally.
X
X			    NO WARRANTY
X
X  9. BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
XFOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN
XOTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
XPROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
XOR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
XMERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS
XTO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE
XPROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
XREPAIR OR CORRECTION.
X
X  10. IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
XWILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
XREDISTRIBUTE THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES,
XINCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING
XOUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED
XTO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY
XYOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER
XPROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE
XPOSSIBILITY OF SUCH DAMAGES.
X
X		     END OF TERMS AND CONDITIONS
X
X	Appendix: How to Apply These Terms to Your New Programs
X
X  If you develop a new program, and you want it to be of the greatest
Xpossible use to humanity, the best way to achieve this is to make it
Xfree software which everyone can redistribute and change under these
Xterms.
X
X  To do so, attach the following notices to the program.  It is safest to
Xattach them to the start of each source file to most effectively convey
Xthe exclusion of warranty; and each file should have at least the
X"copyright" line and a pointer to where the full notice is found.
X
X    <one line to give the program's name and a brief idea of what it does.>
X    Copyright (C) 19yy  <name of author>
X
X    This program is free software; you can redistribute it and/or modify
X    it under the terms of the GNU General Public License as published by
X    the Free Software Foundation; either version 1, or (at your option)
X    any later version.
X
X    This program is distributed in the hope that it will be useful,
X    but WITHOUT ANY WARRANTY; without even the implied warranty of
X    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
X    GNU General Public License for more details.
X
X    You should have received a copy of the GNU General Public License
X    along with this program; if not, write to the Free Software
X    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
X
XAlso add information on how to contact you by electronic and paper mail.
X
XIf the program is interactive, make it output a short notice like this
Xwhen it starts in an interactive mode:
X
X    Gnomovision version 69, Copyright (C) 19xx name of author
X    Gnomovision comes with ABSOLUTELY NO WARRANTY; for details type `show w'.
X    This is free software, and you are welcome to redistribute it
X    under certain conditions; type `show c' for details.
X
XThe hypothetical commands `show w' and `show c' should show the
Xappropriate parts of the General Public License.  Of course, the
Xcommands you use may be called something other than `show w' and `show
Xc'; they could even be mouse-clicks or menu items--whatever suits your
Xprogram.
X
XYou should also get your employer (if you work as a programmer) or your
Xschool, if any, to sign a "copyright disclaimer" for the program, if
Xnecessary.  Here a sample; alter the names:
X
X  Yoyodyne, Inc., hereby disclaims all copyright interest in the
X  program `Gnomovision' (a program to direct compilers to make passes
X  at assemblers) written by James Hacker.
X
X  <signature of Ty Coon>, 1 April 1989
X  Ty Coon, President of Vice
X
XThat's all there is to it!
END_OF_FILE
if test 12488 -ne `wc -c <'COPYING'`; then
    echo shar: \"'COPYING'\" unpacked with wrong size!
fi
# end of 'COPYING'
fi
if test -f 'ChangeLog' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'ChangeLog'\"
else
echo shar: Extracting \"'ChangeLog'\" \(31557 characters\)
sed "s/^X//" >'ChangeLog' <<'END_OF_FILE'
XMon Jul  1 14:14:06 1991  Michael I Bushnell  (mib at geech.gnu.ai.mit.edu)
X
X	* Release of version 1.10; appropriate changes to README.
X
X	* create.c: Removed printf's about sparse files.
X
X	* Fix a misplaced quote in level-0 and change some >& into
X	2>&1.
X
XFri Jun 21 23:04:31 1991  Michael I Bushnell  (mib at geech.gnu.ai.mit.edu)
X
X	* list.c (skip_extended_headers): Userec was being called in
X	the wrong place.
X
XThu Jun 20 19:10:35 1991  David J. MacKenzie  (djm at geech.gnu.ai.mit.edu)
X
X	* tar.h: Use ANSI prototypes for msg and msg_perror if
X	STDC_MSG is defined, even if BSD42 is also.
X
X	* Makefile: Replace DESTDIR with bindir.
X	(install): Don't install tar.texinfo.  There's no standard
X	place for texinfo files, and /usr/local/man is inappropriate.
X	Add TAGS, distclean, and realclean targets and SHELL= line.
X
X	* version.c: Move old change history to bottom of ChangeLog.
X
XWed Jun 12 12:43:58 1991  Michael I Bushnell  (mib at geech.gnu.ai.mit.edu)
X
X	* rtape_lib.c (__rmt_write): #ifdef should reference
X	SIGNAL_VOID, not USG.
X
XWed Jun  5 14:57:11 1991  Michael I Bushnell  (mib@geech.gnu.ai.mit.edu)
X
X	* tar.c (name_match, addname): Ugly hack to handle -C without
X	any files specified.  
X	tar.h (struct name): New field for ugly hack.
X
XMon Jun  3 14:46:46 1991  Michael I Bushnell  (mib@geech.gnu.ai.mit.edu)
X
X	* testpad.c: New file to determine if we need special padding
X	in struct header in tar.h.
X
X	* tar.h (struct header): include padding if necessary, include
X	testpad.h.
X
X	* Makefile: rules to create testpad.h, etc.
X
XWed May 22 16:02:35 1991  Michael I Bushnell  (mib@churchy.gnu.ai.mit.edu)
X
X	* tar.c (options): -L takes an argument.
X
X	* rtape_lib.c (__rmt_open): add /usr/bin/nsh to the list of
X	remote shell programs.
X
X	* create.c: define MAXPATHLEN if we don't get it from a system
X	header file.
X
X	* create.c (deal_with_sparse): return a real return value if
X	we can't open the file.
X
X	* tar.c (long_options): +newer takes an argument.
X	(describe): fix printing in various trivial ways
X
XTue May 21 17:15:19 1991  Michael I Bushnell  (mib at geech.gnu.ai.mit.edu)
X
X	* tar.c (long_options): +get and +concatentate don't require arguments
X
XMon May 20 15:55:30 1991  Michael I Bushnell  (mib at geech.gnu.ai.mit.edu)
X
X	* create.c (write_eot): Don't try and write an EOF if we are
X	already at one.
X
X	* port.c (strstr): Looking for null string should return zero.
X
XSun May 19 22:30:10 1991  Michael I Bushnell  (mib at geech.gnu.ai.mit.edu)
X
X	* tar.c (options): -l doesn't take an argument
X
X	* Makefile: minor fix for SGI 4D defines from torda@scum.ethz.ch
X
X	* rtape_server.c (main.c): Suggested mod for 386/AIX from
X	Minh Tran-Le.  I'm suspicious about this one.
X
X	* create.c (dump_file): Mods from Minh Tran-Le for hidden
X	files on AIX.
X	gnu.c (collect_and_sort_name, get_dir_contents): AIX hidden file mod.
X
X	* tar.c: (name_next): Mod from David Taylor to allow -C inside
X	a file list given to -T.
X
X	* Makefile: Comment describing presence of USE_REXEC.
X
X	* extract.c (extract_archive, case LF_SPARSE): zero check for
X	last element on numbytes needs to look at value after
X	converted from octal.
X
X	* port.c: Don't always demand strstr, check for HAVE_STRSTR
X	instead.
X	Makefile: Comment describing presence of HAVE_STRSTR option.
X
XSun May 19 18:39:48 1991  David J. MacKenzie  (djm at churchy.gnu.ai.mit.edu)
X
X	* port.c (get_date): Renamed from getdate, to avoid SVR4 conflict.
X	* tar.c: Call get_date instead of getdate.
X
XFri May 10 02:58:17 1991  Noah Friedman  (friedman at nutrimat)
X
X        * tar.c:  added "\n\" to the end of some documentation strings
X          where they were left off.  
X
XThu May  9 17:28:54 1991  Michael I Bushnell  (mib at geech.gnu.ai.mit.edu)
X
X	* Makefile: added level-0, level-1, and backup-specs to AUX.
X	* version.c: changed to 1.10 beta.
X	* README: updated for 1.10 beta release.
X
XTue Apr  2 12:04:54 1991  Michael I Bushnell  (mib at godwin)
X
X	* create.c (dump_file): HPUX's st_blocks is in 1024 byte units
X	instead of 512 like the rest of the world, so I special cased
X	it.
X	* tar.c: Undo Noah's changes.
X
XMon Apr  1 17:49:28 1991  Noah Friedman  (friedman at wookumz.gnu.ai.mit.edu)
X
X        (This ought to be temporary until things are fixed properly. )
X
X        * tar.c: (struct option long_options):  flag for "sparse" zero if
X          compiling under hpux. 
X          tar.c: (functon options): case 'S' is a no-op if compiling under
X          hpux. 
X
XSat Mar 30 12:20:41 1991  Michael I Bushnell  (mib at geech.gnu.ai.mit.edu)
X
X	* tar.h: new variable tape_length.
X
X	* tar.c (options): add new option +tape-length / -L.
X
X	* buffer.c (fl_write): Turn #ifdef TEST code for limited tape
X	length on always, for tape-length option.
X
X	* create.c (dump_file): avoid apollo lossage where S_IFIFO == S_IFSOCK.
X
X        * buffer.c: include regex.h
X	* buffer.c (fl_read, open_archive): Use regex routines for
X	volume header match.
X	* xmalloc.c: removed file; wasn't necessary.
X	* tar.c: (main) use ck_malloc instead of xmalloc.
X
XThu Mar 28 04:05:05 1991  Noah Friedman  (friedman at goldman)
X
X        * regex.c, regex.o: New links. 
X        * tar.c: include regex.h. 
X        * Makefile (OBJ2): Add regex.o.
X        (regex.o, tar.o): Depend on regex.h
X        (SRC2, AUX): Add the new files.
X
XSat Mar 23 15:39:42 1991  Noah Friedman  (friedman at wookumz.gnu.ai.mit.edu)
X
X        * Makefile: added default flags and options for compiling under
X          hpux.
X
X        * Added files alloca.c and xmalloc.c 
X
XSat Mar 23 14:35:31 1991  Michael I Bushnell  (mib at geech.gnu.ai.mit.edu)
X
X	* port.c: Define WANT_VALLOC in HPUX.
X
XFri Mar 15 06:20:15 1991  David J. MacKenzie  (djm at geech.ai.mit.edu)
X
X	* rtape_lib.c: If USG and not HAVE_MTIO, define NO_RMTIOCTL
X	automatically.
X	(_rmt_rexec): Temporarily re-open stdin and stdout to
X	/dev/tty, to guarantee that rexec() can prompt and read the
X	login name and password from the user.
X	From pascal@cnam.cnam.fr (Pascal Meheut).
X	* Makefile: Mention -DUSE_REXEC.
X
XFri Mar  8 20:15:11 1991  Michael I Bushnell  (mib at wookumz.ai.mit.edu)
X
X	* tar.h, Makefile:  Makefile CPP macro HAVE_SIZE_T might be
X	useful for some people.
X
X	* gnu.c: lstat->stat define where appropriate
X
X	* buffer.c (fl_write): keep track of amount written for +totals.
X	* tar.c, tar.h: set flag f_totals from +totals option
X	* tar.h (f_totals, tot_written): new variables
X	* tar.c (main): print total written with CMD_CREATE
X
X	* tar.c (main): return appropriate exit status
X
XThu Jan 17 00:50:21 1991  David J. MacKenzie  (djm at apple-gunkies)
X
X	* port.c: Remove a spurious `+' between functions (a remnant
X	of a context diff, apparently).
X
XWed Jan  9 19:43:59 1991  Michael I Bushnell  (mib at pogo.ai.mit.edu)
X
X	* create.c (where_is_data): Rewritten to be better, and then
X	#ifdef-ed out.
X	(deal_with_sparse): Severly pruned.  Now we write or don't
X	write only complete blocks, not worrying about partial blocks.
X	This simplifies calculations, removes bugs, and elides the
X	second scan through the block.  The first was zero_record, the
X	second was where_is_data.
X
XMon Jan  7 17:13:29 1991  Michael I Bushnell  (mib at wookumz.ai.mit.edu)
X
X	* create.c (deal_with_sparse): Second computation (for short
X	reads) of numbytes increment had subtraction backwards.
X	Need to handle calling where_is_data better when we did a
X	short read (it might go past the end of the read), also, set
X	sparsearray[...].offset in this case too.
X
XFri Jan  4 12:24:38 EST 1991	Jay Fenlason (hack@ai.mit.edu)
X
X	* buffer.c  Return a special error code if the archive you're
X	trying to read starts with a different label than the one specified
X	on the command line.
X
XWed Jan  2 12:05:21 EST 1991	Jay Fenlason (hack@ai.mit.edu)
X
X	* gnu.c  Prepend the current directory to the gnu_dumpfile, so that
X	-C's won't affect where the output goes. (sigh.)
X
XTue Dec 18 18:05:59 EST 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* (gnu.c)  Don't complain if the gnudumpfile we're reading info
X	from doesn't exist.
X
X	* create.c  Write out gnudumpfile after finishing writing the archive.
X
X	* tar.c  Add +exclude FNAME, and make +exclude-from do what +exclude
X	used to.
X
X		Make +version an operation, not an option.
X
X		add +confirmation alias for +interactive.
X
XTue Dec  4 13:28:08 EST 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* tar.c (check_exclude)  Don't let MUMBLE match MUMBLE.c or fooMUMBLE
X	but only foo/MUMBLE
X
X	* Add the name mangler (mangle.c, plus changes to create.c and
X	extract.c)
X
X	* extract.c  Three small patches from Chip Salzenberg
X	(tct!chip@uunet.uu.net)
X
X		Don't complain when extracting a link, IFF it already exists.
X
X		Don't complain when extracting a directory IFF it already
X		exists.
X
X		Don't ad u+wx to directories when running as root.
X
X	* gnu.c  Some changes from Chip Salzenberg to make
X	+listed-incremental work.
X
X	* port.c Add the F_FREESP emulation of the ftruncate syscall.
X
XWed Nov 21 15:57:07 EST 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	Remove excess \n from lots of msg() calls.
X
XMon Nov 19 14:09:43 EST 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* tar.c  Rename +volume to +label
X
XFri Nov 16 15:43:44 1990  David J. MacKenzie  (djm at apple-gunkies)
X
X	* tar.c (describe): Include the default values for -b and -f
X	(as set in the Makefile) in the message.
X
XThu Nov 15 13:36:45 EST 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* extract.c (extract_archive)  Do the utime() call before the
X	chmod() call, 'cuz some versons of utime() trash the file's mode
X	bits.
X
X	* list.c (read_and)	Call do_something on volume headers and
X	multivol files even if they don't match the names we're looking for,
X	etc. . .
X
XTue Nov  6 13:51:46 EST 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* port.c (un-quote-string)	Don't try to write a null
X	if there's already one there.
X
XThu Nov  1 14:58:57 EST 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* buffer.c  (new_volume) fflush(msg_file) before reading for
X	confirmation on new volume.  On EOF or error, print error msg and
X	abort.
X
XMon Oct 29 12:06:35 EST 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* getdate.y	Use new version of getdate().
X
X	* tar.c (name_add) Use sizeof(char *) instead of sizeof(int)
X
X	* README give the correct return address.
X
XThu Oct 25 16:03:58 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	rtape_lib.c	Change RMTIOCTL to NO_RMTIOCTL, so it is on by default.
X
X	rmt.h		Add _isrmt() #define for NO_REMOTE case.
X
X	gnu.c		Add forward reference for add_dir_name().
X
XTue Oct 16 11:04:52 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	1.09	New -G file implementation of gnu-dump stuff.
X
X	* tar.c  (name_add)  Get the calls to ck_realloc and ck_malloc right.
X
XThu Oct 11 11:23:38 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* gnu.c  Fix A couple of typos.
X
XWed Sep 19 13:35:03 1990  David J. MacKenzie  (djm at apple-gunkies)
X
X	* getdate.y [USG] (ftime): Use `daylight' unless
X	DAYLIGHT_MISSING is defined.
X
XMon Sep 17 18:04:21 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* gnu.c (gnu_restore)  Don't use a passed char* for the
X	file name, use skipcrud+head->header.name, just like everything
X	else does.  This means that gnu_restore will still work with
X	small buffers, etc.
X
XThu Sep 13 15:01:17 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* tar.c (add_exclude)  Don't bus-error if the exclude file doesn't
X	end with a newline.
X
XSun Sep  9 22:35:27 1990  David J. MacKenzie  (djm at albert.ai.mit.edu)
X
X	* Makefile (dist): Remove .fname when done.
X
XThu Sep  6 12:48:58 EDT 1990	Jay Fenlason (hack@ai.mti.edu)
X
X	* gnu.c (gnu_restore) Rember to skip_file() over the directory
X	contents, even if we don't have to do anything with them.
X
X	* create.c extract.c diffarch.c  Free sparsearray after we're done
X	with it.
X
XTue Sep  4 10:18:50 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* Makefile  Include gnu.c in dist
X
X	* gnu.c move add_dir above read_dir_file so that cc doesn't complain
X	about add_dir returning void.
X
XSun Sep  2 20:46:34 1990  David J. MacKenzie  (djm at apple-gunkies)
X
X	* getdate.y: Declare some more functions and add storage
X	classes where omitted to shut compiler up.
X	[USG] (ftime): Don't use extern var `daylight'; appears that
X	some systems don't have it.
X
XWed Aug 29 00:05:06 1990  David J. MacKenzie  (djm at apple-gunkies)
X
X	* getdate.y (lookup): In the code that allows `Aug.' to be
X	recognized as `Aug', don't chop off the final `.' from words
X	like `a.m.', so they can be recognized.
X
XThu Aug 16 11:34:07 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* buffer.c (open_archive)  If -O, write verbosity to stderr
X	instead of stdout.
X
XFri Aug 10 12:29:28 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* getdate.y  Handle an explicit DST in the input string.
X	A dozen line patch from Per Foreby (perf@efd.lth.se).
X
XMon Jul 16 13:05:11 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* tar.c  rename -g -G +incremental, +listed-imcremental, etc.
X
XFri Jul 13 14:10:33 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* tar.c  Make +newer and +newer-mtime work according to their names.
X
X	* gnu.c  If +newer or +newer-mtime, use the time specified on the
X	command line.
X
X	* buffer.c, create.c  Add test to see if dimwit is trying to
X	archive the archive.
X
X	* tar.c  (long_options[]) re-ordered, so that groups of similar
X	options are next to each other. . .  I think.
X
X		(describe)  Modified to more closely reflect reality.
X
XFri Jul  6 13:13:59 EDT 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* tar.c  add compile-time option for SYS V (?) style
X	tape-drive names /dev/rmt/{n}[lmh]
X
X	* tar.c  Fix getopt-style stuff so that -C always works correctly.
X
X	* gnu.c, tar.c make filename to -G optional.
X
X	* {all over}, replace some fprintf(stderr...) calls with calls
X	to msg().
X
X	* port.c  Make -Dmumble_MSG option on command line override
X	internal assumptions.
X
X	* Makefile  Mention -Dmumble_MSG options
X
XFri Jul  6 02:35:31 1990  David J. MacKenzie  (djm at apple-gunkies)
X
X	* tar.c (options): Don't change `c' if it is 0, as getopt now
X	handles that internally.
X
XMon Jul  2 15:21:13 EDT 1990 Jay Fenlason (hack@ai.mit.edu)
X
X	* gnu.c  (new file)  Moved all the f_gnudump stuff here where we
X	can keep track of it easier.  Also made -G take a file name where it
X	stores the inode information about directories so that we can
X	detect moved directores.
X
X	* create.c (dump_file)  Changed slightly to work with the new
X	f_gnudump.
X
X	* tar.c  Moved the f_gnudump stuff to gnu.c
X
X	* tar.c, extract.c  added the +do-chown option, which forces tar
X	to always try to chown the created files to their original owners.
X
X	* version.c  New version 1.09
X
XSun Jun 24 14:26:28 1990  David J. MacKenzie  (djm at albert.ai.mit.edu)
X
X	* create.c: Change ifdefs for directory library header
X	selection to be like the ones in tar.c.
X	* Makefile [Xenix]: Link with -ldir to get the dirent.h
X	directory library.
X
XThu Jun  7 03:31:51 1990  David J. MacKenzie  (djm at albert.ai.mit.edu)
X
X	* Makefile, buffer.c, diffarch.c: Change MTIO symbol to HAVE_MTIO
X	because SCO Xenix defines 'MTIO' for an incompatible tape driver
X	system in a file included by termio.h.
X	* tar.h: Don't define size_t for Xenix.
X
XTue Jun  5 11:38:00 EDT 1990 Jay Fenlason (hack@ai.mit.edu)
X
X	* create.c (dump_file)  Only print the
X	"... is on a different filesystem..." if f_verbose is on.
X	also add a case for S_IFSOCK and treat it like a FIFO.
X	(Not sure if that's the right thing to do or not, but it's better
X	than all those Unknown File Type msgs.)
X
XThu May 31 19:25:36 EDT 1990 Jay Fenlason (hack@ai.mit.edu)
X
X	* port.c  Use #ifdef sparc instead of #ifdef SPARC since
X	the lowercase version is defined, and the uppercase one isn't.
X
XTue May 22 11:49:18 EDT 1990 Jay Fenlason (hack@ai.mit.edu)
X
X	* port.c (ck_malloc)  if size==0 pretend size=1
X		(ck_realloc)  if(!ptr) call ck_malloc instead.
X
XTue May 15 12:05:45 EDT 1990 Jay Fenlason (hack@ai.mit.edu)
X
X	* diffarch.c (diff_archive)  If not f_absolute_paths, and attempt to
X	open a file listed in the archive fails, try /filename also.  This will
X	allow diff to open the wrong file if both /filename and filename exist,
X	but there's nothing we can do about that.
X
XFri May 11 16:17:43 EDT 1990 Jay Fenlason (hack@ai.mit.edu)
X
X	* Makefile, Descripbe new -DMTIO option.
X
X	* buffer.c diffarch.c  Change ifdefs slightly, so that
X	-DMTIO will include sys/mtio.h even if USG is defined.
X	This is for HUPX and similar BSD/USG crossovers.
X
XTue May  8 13:14:54 EDT 1990 Jay Fenlason (hack@ai.mit.edu)
X	* update.c (update_archive)  Call reset_eof() when appropriate.
X
X	* buffer.c (reset_eof)  New function, that turns of EOF flag, and
X	re-sets the ar_record and ar_last pointers.  This will allow
X	'tar rf non-existant-file' to not core-dump.
X
XFri May  4 14:05:31 1990  David J. MacKenzie  (djm at albert.ai.mit.edu)
X
X	* tar.c: Recognize the +sparse option.  It was documented, but
X	only the short form (-S) was actually recognized.
X
XTue Apr 17 21:34:14 EDT 1990 Jay Fenlason (hack@ai.mit.edu)
X
X	* create.c  Don't access location 0 if ->dir_contents is null.
X
XWed Apr 11 17:30:03 EDT 1990 Jay Fenlason (hack@ai.mit.edu)
X
X	* buffer.c (flush_archive, close_archive, new_volume) Always check
X	the return value of rmtclose(), and only give a warning msg if it is
X	<0.  Some device drivers (including Sun floppy disk, and HP
X	streaming tape) return -1 after an IO error (or something like that.)
X
XFri Mar 23 00:06:30 1990  Jim Kingdon  (kingdon at mole.ai.mit.edu)
X
X	* tar.c (long_options): Make it so +append +extract +list +update
X	+catenate and +delete don't take arguments.
X
XMon Mar 12 13:33:53 EST 1990
X
X	* buffer.c (open_archive, fl_write) Set the mtime of the volume
X	header to the current time.
X
XWed Mar  7 14:10:10 EST 1990	Jay Fenlason (hack@ai.mit.edu)
X
X	* buffer.c  Fix +compress-block  A two character patch from
X	Juha Sarlin (juha@tds.kth.se)
X		Replace #ifdef __GNU__ with #ifdef __STDC__
X		(new_volume)  If open of new archive fails, ask again
X				(Is probably user error.)
X
X	* tar.c   Replace #ifdef __GNU__ with #ifdef __STDC__
X
X	* port.c  Clean up #ifdef and #defines a bit.
X		(quote_copy_string)  Sometimes the malloc'd buffer
X				would be up to two characters too short.
X
X	* extract.c (extract_archive) Don't declare ind static.
X
X	* create.c (dump_file)  Don't declare index_offset static.
X
X	* diffarch.c  Remove diff_name variable, and always use
X	head->header.name, which will always work, unlike diff_name, which
X	becomes trash when the next block is read in.
X
XThu Mar  1 13:43:30 EST 1990	Jay Fenlason (hack@wookumz.ai.mit.edu)
X
X	* Makefile Mention the -NO_REMOTE option.
X	* port.c Fix typo, and define WANT_FTRUNCATE on i386 machines.
X
XMon Feb 26 17:44:53 1990  Jim Kingdon  (kingdon at pogo.ai.mit.edu)
X
X	* getdate.y: Declare yylex and yyerror as static.
X	#define yyparse to getdate_yyparse.
X
XSun Feb 25 20:47:23 1990  David J. MacKenzie  (djm at albert.ai.mit.edu)
X
X	* tar.c: Remove +old option, since it is a valid abbreviation of
X	+old-archive, which does the same thing.
X	(describe): A few small cleanups in message.
X
XMon Feb  5 14:29:21 EST 1990	Jay Fenlason	(hack@wookumz)
X
X	* port.c  define LOSING_MSG on sparc, since doprnt_msg doesn't work.
X		  Fix typo in #ifdef WANT_GETWD
X
XFri Jan 26 16:11:20 EST 1990	Jay Fenlason	(hack@wookumz)
X
X	1.08	Sparse file support added.  Also various other features.
X
X	* diffarch.c (compare_chunk)  Include correct arguments in
X	a call to fprintf() for an error msg.
X	(compare_chunks, compare_dir)  First argument is a long, not an int.
X
X	* tar.c (options)  Use tar variable (argv[0]) as the name to print
X 	in an error msg, instead of a constant "tar".
X	(confirm)  Use external variable char TTY_NAME[] for name of file
X	to open for confirmation input.
X
X	* buffer.c (new_volume)  Ditto.
X
X	* port.c  Add declaration for TTY_NAME[].
X
X	* rmt.h  Add long declarations for lseek() and __rmt_lseek();
X
XTue Jan 23 14:06:21 EST 1990	Jay Fenlason (hack@wookumz)
X	* tar.c, create.c  Create the +newer-mtime option, which is like
X	+newer, but only looks for files whose mtime is newer than the
X	given date.
X
X	* rtape_lib.c  Make *both* instances of signal-handler stuff use
X	void (*foo)() on USG systems.
X
XThu Jan 11 14:03:45 EST 1990  Jay Fenlason  (hack@wookumz)
X
X	* getdate.y  Parse European dates of the form YYMMDD.
X	In ftime()  Init timezone by calling localtime(), and remember that
X	timezone is in seconds, but we want timeb->timezone to be in minutes.
X	This small patch from Joergen Haegg  (jh@aahas.se)
X
X	* rtape_lib.c (__rmt_open)  Also look for /usr/bsd/rsh.
X	Declare signal handler as returning void instead of int if USG is
X	defined.
X
X	* port.c Declare WANT_GETWD for SGI 4-D IRIS.
X
X	* Makefile  Include defines for SGI 4D version.  There are a simple
X	patch from Mike Muuss (mike@brl.mil).
X
X	* buffer.c (fl_read)  Work properly on broken Ultrix systems where
X	read() returns -1 with errno==ENOSPC on end of tape.  Correctly go
X	on to the next volume if f_multivol.
X
X	* list.c (list_archive,print_header)  Flush msg_file after printing
X	messages.
X
X	* port.c Delete unused references to alloca().
X	Don't crash if malloc() returns zero in quote_copy_string.
X	Flush stderr in msg() and msg_perror().
X
X	* tar.c  Flush msg_file after printing confirmation msg.
X
XWed Jan 10 01:58:46 1990  David J. MacKenzie  (djm at hobbes.ai.mit.edu)
X
X	* tar.c (main): Change -help option and references to it to +help,
X	and remove suggestion to run info (which is unreleased, so not
X	likely to be of any help).
X
XTue Jan  9 16:16:00 EST 1990	Jay Fenlason  (hack @wookumz)
X
X	* create.c (dump_file)  Close file descriptor if start_header()
X	fails.
X		(dump_file)  Change test for ./ ness to not think that
X	.{any character} is a ./  These are both trivial changes from
X	Piercarlo "Peter" Grandi  pcg%cs.aber.ac.uk@nsfnet-relay.ac.uk
X
X	* diffarch.c (diff_init)  Print correct number of bytes in error
X	message.
X
XTue Jan  9 03:19:49 1990  David J. MacKenzie  (djm at hobbes.ai.mit.edu)
X
X	* Makefile: Add comment at top noting that two source files also
X	contain #defines that might need to be changed by hand.
X
X	* create.c, diffarch.c, extract.c: Change L_SET to 0 in lseek
X	calls, because only BSD defines it.
X	* create.c (dump_file): Make sparse file checking code conditional
X	on BSD42 because it uses st_blocks, which the other systems lack.
X
XTue Jan  2 13:35:56 EST 1990 Jay Fenlason (hack@gnu)
X
X	* port.c (quote_copy_string)  Fix so it doesn't scramble memory if
X	the last character is non-printable.  A trivial fix from Kian-Tat Lim
X	(ktl@wag240.caltech.edu).
X
XTue Dec 19 11:19:37 1989  Jim Kingdon  (kingdon at pogo)
X
X	* port.c [BSD42]: Define DOPRNT_MSG.
X	tar.h [BSD42]: Do not prototype msg{,_perror}.
X
XFri Dec  8 11:02:47 EST 1989	Jay Fenlason (hack@gnu)
X
X	* create.c (dump_file)  Remove typo in msg.
X
XFri Dec  1 19:26:47 1989  David J. MacKenzie  (djm at trix)
X
X	* Makefile: Remove comments referring to certain systems lacking
X	getopt, since it is now provided always and needed by all systems.
X
X	* port.c: Remove copy of getopt.c, as it is now linked in
X	separately to always get the current version.
X
X	* tar.c: Rename +cat-tars option to +catenate or +concatenate, 
X	and +local-filesystem to +one-file-system (preferred by rms
X	and used in GNU cp for the same purpose).
X	(describe): Reflect changes.
X
XTue Nov 28 04:28:26 1989  David J. MacKenzie  (djm at hobbes.ai.mit.edu)
X
X	* port.c: Move declaration of alloca into #else /* sparc */
X	so it will compile on sparcs.
X
XMon Nov 27 15:17:08 1989  David J. MacKenzie  (djm at hobbes.ai.mit.edu)
X
X	* tar.c (options): Remove -version option (replaced by +version).
X	(describe): Mention long options.
X
XSat Nov 25 04:25:23 1989  David J. MacKenzie  (djm at hobbes.ai.mit.edu)
X
X	* getoldopt.c (getoldopt): Make `opt_index' argument a pointer to
X	an int, not char.
X
X	* tar.c: Modify long options per rms's suggestions:
X	Make preserve-permissions an alias for same-permissions.
X	Make preserve-order an alias for same-order.
X	Define preserve to mean both of those combined.
X	Make old an alias for old-archive.
X	Make portability an alias for old-archive, also.
X	Rename sym-links to dereference.
X	Rename gnudump to incremental.
X	Rename filename to file.
X	Make compare an alias for diff.  Leave diff but prefer compare.
X	Rename blocking-factor to block-size.
X	Rename chdir to directory.
X	Make uncompress an alias for compress.
X	Rename confirm to interactive.
X	Make get an alias for extract.
X	Rename volume-header to volume.
X
X	Also make +version an alias for -version.
X
X	(options): Shorten code that interprets long options by using
X	the equivalent short options' code.  This also makes it tons
X	easier to change the long options.
X
X	(describe): Make usage message more internally consistent
X	stylistically. 
X
XMon Nov 20 14:55:39 EST 1989	hack@ai.mit.edu
X
X	* list.c (read_and)  Call check_exclude() to see if the files
X	should be skipped on extract or list.
X
XThu Nov  9 18:59:32 1989  Jim Kingdon  (kingdon at hobbes.ai.mit.edu)
X
X	* buffer.c (fl_read): Fix typos in error message
X	"tar EOF not on block boundary".
X
XMon Oct 23 13:09:40 EDT 1989		(hack@ai.mit.edu)
X
X	* tar.c (long_options[])  Add an option for blocked compression.
X
XThu Oct 19 13:38:16 EDT 1989		(hack@ai.mit.edu)
X
X	* buffer.c (writeerror)  Print a more useful error msg.
X
XWed Sep 27 18:33:41 EDT 1989		(hack@ai.mit.edu)
X
X	* tar.c (main)  Mention "tar -help" if the luser types a non-workable
X	set of options.
X
XMon Sep 11 15:03:29 EDT 1989		(hack@ai.mit.edu)
X
X	* tar.c (options)  Have -F correctly set info_script.
X
XTue Aug 29 12:58:06 EDT 1989		(hack@ai.mit.edu)
X
X	* Makefile  Include ChangeLog in tar.tar and tar.tar.Z
X
XMon Aug 28 17:42:24 EDT 1989		(hack@ai.mit.edu)
X
X	* tar.c (options) Made -F imply -M
X	Also remind tar that the -f option takes an argument!
X
X	* Modified -F option to make it do what (I think) it
X	should.  e.g, if you say -F, tar won't send a msg to
X	msg_file and wait for a <return> It'll just run the program
X	it was given, and when the prog returns, the new tape had
X	*better* be ready. . .
X
X	* buffer.c (open_archive)  Give error message and abort if
X	the luser didn't give an archive name.
X
XFri Aug 25 20:05:27 EDT 1989		Joy Kendall (jak at hobbes)
X
X	* Added code to make a new option to run a specified script
X	at the end of each tape in a multi-volume backup.  Changed:
X	tar.c: made new switch, -F, and new long-named option,
X	"info-script".  Code is where you would expect.
X	tar.h: added flag f_run_script_at_end, and an extern char *
X	called info_script, which optarg gets set to.
X	buffer.c: line 1158 in new_volume(): if f_run_script_at_end
X	is set, we give info_script to system(), otherwise we do
X	what we've always done.  **FIXME** I'm not sure if that's all
X	that has to be done here.
X
XThu Aug 24 10:09:38 EDT 1989		Joy Kendall (jak at spiff)
X(These changes made over the course of 6/89 - 8/89)
X
X	* diffarch.c: diff_archive: Added switches for LF_SPARSE in the
X	case statements that needed it.  Also, skip any extended headers
X	if we need to when we skip over a file.  (need to change
X	the bit about, if the size doesn't agree AND the file is NOT
X	sparse, then there's a discrepancy, because I added another
X	field to the header which should be able to deal with the
X	sizes)   If the file is sparse, call the added routine
X	"diff_sparse_files" to compare.  Also added routine 
X	"fill_in_sparse_array".
X
X	* extract.c: extract_archive: added the switch LF_SPARSE
X	to the case statement as needed, and code to treat the 
X	sparse file.  At label "again_file", modified opening the
X	file to see if we should have O_APPEND be one of the modes.
X	Added code at label "extract_file" to call the new routine
X 	"extract_sparse_file" when we have an LF_SPARSE flag.
X
X	Note: really should erase the commented-out code in there,
X	because it's confusing.
X
X	* update.c: made sure that if a file needed to be "skipped" 
X	over, it would check to see if the linkflag was sparse, and
X	if so, would then make sure to skip over any "extended 
X	headers" that might come after the header itself.  Do so by
X	calling "skip_extended_headers".
X
X	* create.c: create_archive: added code to detect a sparse
X	file when in the long case statement.  Added ways to detect
X	extended headers, and label "extend" (ack! should get rid of
X	that, is atrocious).  Call the new routine "finish_sparse_file"
X	if the linkflag is LF_SPARSE to write the info to the tape.
X	Also added routines "init_sparsearray", "deal_with_sparse",
X	"clear_buffer", "where_is_data", "zero_record", and 
X	"find_new_file_size".
X
X	* tar.h:  Added the #define's SPARSE_EXT_HDR and 
X	SPARSE_IN_HDR.  Added the struct sparse and the struct
X	sp_array.  Added the linkflag LF_SPARSE. Changed the tar
X 	header in several ways:
X		- added an array of struct sparse's SPARSE_IN_HDR long
X		- added a char flag isextended
X		- added a char string realsize to store the true
X		size of a sparse file
X	Added another choice to the union record called a
X	struct extended_header, which is an array of 21 struct
X	sparse's and a char isextended flag.  Added flag
X	f_sparse_file to list of flags.
X
X	* tar.c: added long-named options to make tar compatible with
X	getopt_long, changed Makefile.
X
X... ... .. ..:..:.. ... ....	Jay Fenlason (hack@ai.mit.edu)
X
X	1.07	New version to go on beta tape with GCC 1.35
X	Better USG support.  Also support for __builtin_alloca
X	if we're compiling with GCC.
X	diffarch.c: Include the correct header files so MTIOCTOP
X	is defined.
X	tar.c:  Don't print the verbose list of options unless
X	given -help.  The list of options is *way* too long.
X
X	1.06	Use STDC_MSG if __STDC__ defined
X	ENXIO meand end-of-volume in archive (for the UNIX PC)
X	Added break after volume-header case (line 440) extract.c
X	Added patch from arnold@unix.cc.emory.edu to rtape_lib.c
X	Added f_absolute_paths option.
X	Deleted refereces to UN*X manual sections (dump(8), etc)
X	Fixed to not core-dump on illegal options
X	Modified msg_perror to call perror("") instead of perror(0)
X	patch so -X - works
X	Fixed tar.c so 'tar cf - -C dir' doesn't core-dump
X	tar.c (name_match): Fixed to chdir() to the appropriate
X	directory if the matching name's change_dir is set.  This
X	makes tar xv -C foo {files} work.
X
X	1.05	A fix to make confirm() work when the archive is on stdin
X	include 'extern FILE *msg_file;' in pr_mkdir(), and fix
X	tar.h to work with __STDC__
X
X	Added to port.c: mkdir() ftruncate()  Removed: lstat()
X	Fixed -G to work with -X
X	Another fix to tar.texinfo
X	Changed tar.c to say argv[0]":you must specify exactly ...
X	buffer.c: modified child_open() to keep tar from hanging when
X	it is done reading/writing a compressed archive
X	added fflush(msg_file) before printing error messages
X	create.c: fixed to make link_names non-absolute
X
X	1.04	Added functions msg() and msg_perror()  Modified all the
X	files to call them.  Also checked that all (I hope)
X	calls to msg_perror() have a valid errno value
X	(modified anno() to leave errno alone), etc
X	Re-fixed the -X option.  This time for sure. . .
X	re-modified the msg stuff.  flushed anno() completely
X	Modified the directory stuff so it should work on sysV boxes
X	added ftime() to getdate.y
X	Fixed un_quote_string() so it won't wedge on \" Also fixed
X	\ddd (like \123, etc)
X	More fixes to tar.texinfo
X
X	1.03	Fixed buffer.c so 'tar tzf NON_EXISTENT_FILE' returns an error
X	message instead of hanging forever
X	More fixes to tar.texinfo
X
X	1.02	Fixed tar.c so 'tar -h' and 'tar -v' don't cause core dump
X	Also fixed the 'usage' message to be more up-to-date.
X	Fixed diffarch.c so verify should compile without MTIOCTOP
X	defined
X
X	1.01	Fixed typoes in tar.texinfo
X	Fixed a bug in the #define for rmtcreat()
X	Fixed the -X option to not call realloc() of 0.
X
X	Version 1.00:  version.c added.  -version option added
X	Installed new version of the remote-tape library
X	Added -help option
X
XLocal Variables:
Xmode: indented-text
Xleft-margin: 8
Xversion-control: never
XEnd:
END_OF_FILE
if test 31557 -ne `wc -c <'ChangeLog'`; then
    echo shar: \"'ChangeLog'\" unpacked with wrong size!
fi
# end of 'ChangeLog'
fi
if test -f 'Makefile' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'Makefile'\"
else
echo shar: Extracting \"'Makefile'\" \(8773 characters\)
sed "s/^X//" >'Makefile' <<'END_OF_FILE'
X# Makefile for GNU tar program.
X
XSHELL = /bin/sh
X
X# In order to disable remote-tape support, add -DNO_REMOTE to the
X# appropriate DEFS line, and remove rtape_lib.* from LOCAL_{SRC,OBJ}
X# For Ultrix 3.1, you will have to compile rtape_lib.c with -DUSG.
X# Add -DUSE_REXEC to use rexec for remote tape operations
X# instead of forking rsh or remsh.
X#
X# If tar fails to properly print error msgs, or core-dumps doing same,
X# you may need to change which version of msg...() you are using.
X# To do so, add one of the following to your DEFS= line
X# -DSTDC_MSG		If you are using an ANSI compiler, and have vfprintf().
X# -DVARARGS_MSG		If you have varargs.h and vfprintf()
X# -DDOPRNT_MSG		If you have _doprnt(), and no useful varargs support
X# -DLOSING_MSG		If nothing else works.
X#
X# Some non-BSD systems may have to add -DNEED_TZSET in order to have getdate.y
X# compile correctly.
X#
X# If you have a system V system which defines size_t, add -DHAVE_SIZE_T.
X# If you have a system which defines strstr, add -DHAVE_STRSTR.
X#
X# If you can't use remote tar with the rmt library, you can still get
X# some stuff to work right by adding -DUSE_REXEC.
X#
X# Some people's systems define a prototype for signal handlers which
X# require them to be declared as void.  If you get such problems in
X# rtape_lib, function command, then define -DSIGNAL_VOID.  
X#
X# getdate.y has 8 shift/reduce conflicts.
X#
X# In addition to setting DEFS appropriately for your system, you might
X# have to hand edit the #defines and #undefs in port.c.
X#
X
X## GNU version
X#DEFS = -DBSD42
X#LOCAL_SRC = 
X#LOCAL_OBJ = 
X#LDFLAGS =
X#LIBS =  -lutils
X#LINT = lint
X#LINTFLAGS = -abchx
X#DEF_AR_FILE = \"-\"
X#DEFBLOCKING = 20
X#O = o
X
X## Berserkeley version
XCC=gcc
XDEFS = -DBSD42
XLOCAL_SRC = getdate.y  rtape_lib.c
XLOCAL_OBJ = getdate.$O rtape_lib.$O
XLDFLAGS =
XLIBS =
XLINT = lint
XLINTFLAGS = -abchx
XDEF_AR_FILE = \"/dev/rmt8\"
XDEFBLOCKING = 20
XO = o
X
X## Ultrix
X#CC=gcc
X#DEFS = -DBSD42 -DSIGNAL_VOID
X#LOCAL_SRC = getdate.y  rtape_lib.c
X#LOCAL_OBJ = getdate.$O rtape_lib.$O
X#LDFLAGS =
X#LIBS =
X#LINT = lint
X#LINTFLAGS = -abchx
X#DEF_AR_FILE = \"/dev/rmt8\"
X#DEFBLOCKING = 20
X#O = o
X
X# HPUX 7.0 version
X#DEFS = -DBSD42 -Dhpux -DVARARGS_MSG
X#LOCAL_SRC = getdate.y  rtape_lib.c 
X#LOCAL_OBJ = getdate.$O rtape_lib.$O alloca.$O
X#LDFLAGS =
X#LIBS = -lBSD 
X#LINT = lint
X#LINTFLAGS = -abchx
X#DEF_AR_FILE = \"/dev/rct/c3d0s2\"
X#DEFBLOCKING = 20
X#O = o
X
X# IBM AIX version -- this saves "hidden" directories, but doesn't restore
X# them as hidden.  Add -Di386 for a PS/2.  If you don't have GCC, turn it off.
X# Some people think you need -lbsd, some don't.  Dunno.
X#CC=gcc
X#DEFS= -DUSG -Daix -DSTDC_MSG -DHAVE_MTIO -DHAVE_SIZE_T -DSIGNAL_VOID
X#LOCAL_SRC =  getdate.y rtape_lib.c
X#LOCAL_OBJ =  getdate.$O rtape_lib.$O
X#LDFLAGS =
X#LIBS = -lbsd
X#LINT = lint
X#LINTFLAGS = -p
X#DEF_AR_FILE = \"/dev/rmt0\"
X#DEFBLOCKING = 20
X#O = o
X
X# USG version
X# Add -DNDIR to DEFS if your system uses ndir.h instead of dirent.h
X# Add -DDIRECT to DEFS if your system uses 'struct direct' instead of
X# 'struct dirent' (this is the case at least with one add-on ndir 
X# library)
X# Add -DHAVE_MTIO to DEFS if your system has sys/mtio.h and defines MTIOCTOP
X# Add -DDAYLIGHT_MISSING to DEFS if your system doesn't define the
X# external variable `daylight'.
X# Add -lndir to LIBS if your ndir routines aren't in libc.a
X# Add -lPW to LIBS if you don't compile with gcc (to get alloca)
X#DEFS = -DUSG -DSIGNAL_VOID #-DNDIR -DDIRECT -DHAVE_MTIO
X#LOCAL_SRC =  getdate.y rtape_lib.c
X#LOCAL_OBJ =  getdate.$O rtape_lib.$O
X#LDFLAGS =
X#LIBS = #-lndir -lPW
X#LINT = lint
X#LINTFLAGS = -p
X#DEF_AR_FILE = \"/dev/rmt8\"
X#DEFBLOCKING = 20
X#O = o
X
X# UniSoft's Uniplus SVR2 with NFS
X#DEFS = -DUSG -DUNIPLUS -DNFS -DSVR2 -DSIGNAL_VOID
X#LOCAL_SRC =  getdate.y rtape_lib.c
X#LOCAL_OBJ =  getdate.$O rtape_lib.$O
X#LDFLAGS =
X#LIBS = -lndir
X#LINT = lint
X#LINTFLAGS = -bx
X#DEF_AR_FILE = \"/dev/rmt8\"
X#DEFBLOCKING = 20
X#O = o
X
X# MASSCOMP version
X#CC = ucb cc
X#DEFS = -DBSD42
X#LOCAL_SRC =  getdate.y rtape_lib.c
X#LOCAL_OBJ =  getdate.$O rtape_lib.$O
X#LDFLAGS =
X#LIBS = 
X#LINT = lint
X#LINTFLAGS = -bx
X#DEF_AR_FILE = \"/dev/rmt0\"
X#DEFBLOCKING = 20
X#O = o
X
X# (yuk) MS-DOS (Microsoft C 4.0) version
X#MODEL = S
X#DEFS = -DNONAMES -A$(MODEL) -DNO_REMOTE
X#LOCAL_SRC =  getdate.y rtape_lib.c
X#LOCAL_OBJ =  getdate.$O rtape_lib.$O
X#LDFLAGS =
X#LIBS = $(MODEL)dir.lib
X#LINT =	$(CC)
X#LINTFLAGS = -W3
X#DEF_AR_FILE = \"tar.out\"
X#DEFBLOCKING = 20
X#O = obj
X
X# V7 version
X# Pick open3 emulation or nonexistence.  See open3.h, port.c.
X##DEFS = -DV7 -DEMUL_OPEN3 -Dvoid=int
X##DEFS = -DV7 -DNO_OPEN3 -Dvoid=int
X#LOCAL_SRC =  getdate.y rtape_lib.c
X#LOCAL_OBJ =  getdate.$O rtape_lib.$O
X#LDFLAGS =
X#LIBS = -lndir
X#LINT = lint
X#LINTFLAGS = -abchx
X#DEF_AR_FILE = \"/dev/rmt8\"
X#DEFBLOCKING = 20
X#O = o
X
X# Minix version
X# No lint, so no lintflags.  Default file is stdin/out.  (Minix "tar"
X# doesn't even take an "f" flag, it assumes argv[2] is the archive name!)
X# Minix "make" doesn't expand macros right, so Minix users will have
X# to expand CFLAGS, SRCS, O, etc by hand, or fix your make.  Not my problem!
X# You'll also need to come up with ctime(), the directory
X# library, and a fixed doprintf() that handles %*s.  Put this stuff in
X# the "SUBSRC/SUBOBJ" macro below if you didn't put it in your C library.
X# Note that Minix "cc" produces ".s" files, not .o's, so O = s has been set.
X#
X# Pick open3 emulation or nonexistence.  See open3.h, port.c.
X##DEFS = -DV7 -DMINIX -DEMUL_OPEN3
X##DEFS = -DV7 -DMINIX -DNO_OPEN3
X#LOCAL_SRC =  getdate.y rtape_lib.c
X#LOCAL_OBJ =  getdate.$O rtape_lib.$O
X#LDFLAGS =
X#LIBS =
X#DEF_AR_FILE = \"-\"
X#DEFBLOCKING = 8	# No good reason for this, change at will
X#O = s
X
X# Xenix version
X#DEFS = -DUSG -DXENIX -DSIGNAL_VOID
X#LOCAL_SRC =  getdate.y rtape_lib.c
X#LOCAL_OBJ =  getdate.$O rtape_lib.$O
X#LDFLAGS = 
X#LIBS = -lx
X#LINT = lint
X#LINTFLAGS = -p
X#DEF_AR_FILE = \"/dev/rmt8\"
X#DEFBLOCKING = 20
X#O = o
X
X# SGI 4D version
X# You will need to define NEED_TZSET in getdate.y
X#DEFS = -DUSG -I/usr/include/bsd
X#LOCAL_SRC = getdate.y rtape_lib.c
X#LOCAL_OBJ =  getdate.$O rtape_lib.$O
X#LDFLAGS = 
X#LIBS = -lxmalloc
X#LINT = lint
X#LINTFLAGS = -p
X#DEF_AR_FILE = \"/dev/tape\"
X#DEFBLOCKING = 20
X#O = o
X
X#CC = gcc
X#TARGET_ARCH = 
X
XCFLAGS = $(COPTS) $(ALLDEFS)
XALLDEFS = $(DEFS) \
X	-DDEF_AR_FILE=$(DEF_AR_FILE) \
X	-DDEFBLOCKING=$(DEFBLOCKING)
X# next line for Debugging
XCOPTS = -g
X# next line for Production
X#COPTS = -O
X
X# Add things here like readdir that aren't in your standard libraries.
X# (E.g. MSDOS needs msd_dir.c, msd_dir.obj)
XSUBSRC=
XSUBOBJ=	
X
X# Destination directory and installation program for make install
Xbindir = /usr/local/gnubin
XINSTALL = cp
XRM = rm -f
X
XSRC1 =	tar.c create.c extract.c buffer.c getoldopt.c update.c gnu.c mangle.c
XSRC2 =  version.c list.c names.c diffarch.c port.c wildmat.c getopt.c getopt1.c regex.c
XSRC3 =  $(LOCAL_SRC) $(SUBSRC)
XSRCS =	$(SRC1) $(SRC2) $(SRC3)
XOBJ1 =	tar.$O create.$O extract.$O buffer.$O getoldopt.$O list.$O update.$O
XOBJ2 =	version.$O names.$O diffarch.$O port.$O wildmat.$O getopt.$O getopt1.$O regex.$O
XOBJ3 =  gnu.$O mangle.$O $(LOCAL_OBJ) $(SUBOBJ)
XOBJS =	$(OBJ1) $(OBJ2) $(OBJ3)
X# AUX =	README PORTING Makefile TODO tar.h port.h open3.h \
X#	msd_dir.h msd_dir.c
XAUX =   README COPYING ChangeLog Makefile tar.texinfo tar.h port.h open3.h \
X	rmt.h msd_dir.h msd_dir.c rtape_server.c rtape_lib.c getdate.y \
X	getopt.h regex.h level-0 level-1 backup-specs testpad.c
X
Xall:	tar rmt
X
Xtar:	$(OBJS)
X	$(CC) $(LDFLAGS) -o tar $(COPTS) $(OBJS) $(LIBS)
X
Xrmt:	rtape_server.c
X	$(CC) $(CFLAGS) $(LDFLAGS) -o rmt rtape_server.c
X
Xtestpad.h: testpad
X	testpad > testpad.h
X
Xtestpad: testpad.o
X	$(CC) -o testpad testpad.o
X
X# command is too long for Messy-Dos (128 char line length limit) so
X# this kludge is used...
X#	@echo $(OBJ1) + > command
X#	@echo $(OBJ2) >> command
X#	link @command, $@,,$(LIBS) /NOI;
X#	@$(RM) command
X
Xinstall: all
X	$(RM) $(bindir)/tar
X	$(INSTALL) tar $(bindir)/tar
X	$(INSTALL) rmt /etc/rmt
X
Xlint:	$(SRCS)
X	$(LINT) $(LINTFLAGS) $(ALLDEFS) $(SRCS)
X
XTAGS:	$(SRCS)
X	etags $(SRCS)
X
Xclean:
X	$(RM) errs $(OBJS) tar rmt testpad.o testpad testpad.h
X
Xdistclean: clean
X
Xrealclean: clean
X
Xshar: $(SRCS) $(AUX)
X	shar $(SRCS) $(AUX) | compress > tar-`sed -e '/version_string/!d' -e 's/[^0-9.]*\([0-9.]*\).*/\1/' -e q version.c`.shar.Z
X
Xdist: $(SRC1) $(SRC2) $(AUX)
X	echo tar-`sed -e '/version_string/!d' -e 's/[^0-9.]*\([0-9.]*\).*/\1/' -e q < version.c` > .fname
X	-rm -rf `cat .fname`
X	mkdir `cat .fname`
X	ln $(SRC1) $(SRC2) $(AUX) `cat .fname`
X	tar chZf `cat .fname`.tar.Z `cat .fname`
X	-rm -rf `cat .fname` .fname
X
Xtar.zoo: $(SRCS) $(AUX)
X	-mkdir tmp.dir
X	-rm tar.zoo
X	for X in $(SRCS) $(AUX) ; do echo $$X ; sed 's/$$//' $$X > tmp.dir/$$X ; done
X	cd tmp.dir ; zoo aM ../tar.zoo *
X	-rmdir tmp.dir
X
X$(OBJS): tar.h port.h testpad.h
Xregex.$O tar.$O: regex.h
END_OF_FILE
if test 8773 -ne `wc -c <'Makefile'`; then
    echo shar: \"'Makefile'\" unpacked with wrong size!
fi
# end of 'Makefile'
fi
if test -f 'tar.texinfo' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'tar.texinfo'\"
else
echo shar: Extracting \"'tar.texinfo'\" \(54782 characters\)
sed "s/^X//" >'tar.texinfo' <<'END_OF_FILE'
X\input texinfo @c -*-texinfo-*-
X
X@setfilename tar.info
X@settitle The @code{tar} Manual: DRAFT
X@ifinfo
XThis file documents the tape archive of the GNU system.
X
XCopyright (C) 1988 Free Software Foundation, Inc.
X
XPermission is granted to make and distribute verbatim copies of this
Xmanual provided the copyright notice and this permission notice are
Xpreserved on all copies.
X
X@ignore
XPermission is granted to process this file through TeX and print the
Xresults, provided the printed document carries copying permission
Xnotice identical to this one except for the removal of this paragraph
X(this paragraph not being relevant to the printed manual).
X
X@end ignore
XPermission is granted to copy and distribute modified versions of
Xthis manual under the conditions for verbatim copying, provided that
Xthe entire resulting derived work is distributed under the terms of
Xa permission notice identical to this one.
X
XPermission is granted to copy and distribute translations of this
Xmanual into another language, under the above conditions for
Xmodified versions.
X@end ifinfo
X
X@iftex
X@finalout
X@end iftex
X
X@titlepage
X@sp 11
X@center @titlefont{tar}
X@sp 1
X@center The GNU tape archive
X@sp 2
X@center by Jay Fenlason
X@sp 2
X@center DRAFT!
X@sp 1
X@center @today
X@page
X@vskip 0pt plus 1filll
XCopyright @copyright{} 1988 Free Software Foundation, Inc.
X
XPermission is granted to make and distribute verbatim copies of
Xthis manual provided the copyright notice and this permission notice
Xare preserved on all copies.
X
X@ignore
XPermission is granted to process this file through Tex and print the
Xresults, provided the printed document carries copying permission
Xnotice identical to this one except for the removal of this paragraph
X(this paragraph not being relevant to the printed manual).
X
X@end ignore
XPermission is granted to copy and distribute modified versions of this
Xmanual under the conditions for verbatim copying, provided that the entire
Xresulting derived work is distributed under the terms of a permission
Xnotice identical to this one.
X
XPermission is granted to copy and distribute translations of this manual
Xinto another language, under the same conditions as for modified versions.
X
X@end titlepage
X@node Top, Why, ,
X@unnumbered Preface
X
XThis manual describes the GNU tape archiver, @code{tar}, and how you
Xcan use it to store copies of a file or a group of files in an
X@dfn{archive}.  This archive may be written directly to a magnetic
Xtape or other storage medium, stored as a file, or sent through a
Xpipe to another program.  @code{tar} can also be used to add files
Xto an already existing archive, list the files in an archive, or
Xextract the files in the archive.
X
X
X
XGNU @code{tar} was written by John Gilmore, and modified by many
Xpeople.  The GNU enhancements were written by Jay Fenlason.
X
X@ifinfo
X@ichapter Using the Tape Archiver
X
XYou can use the GNU tape archiver, @code{tar}, to store copies of a file
Xor a group of files in an @dfn{archive}.  This archive may be written
Xdirectly to a magnetic tape or other storage medium, stored as a file,
Xor sent through a pipe to another program.  @code{tar} can also be used
Xto add files to an already existing archive, list the files in an
Xarchive, or extract the files in the archive.
X
X@menu
X* Why::			What @code{tar} archives are good for.
X* Commands::		How to tell @code{tar} what to do.
X* Options::		Options that change the way @code{tar} behaves.
X* FullDumps::		Using @code{tar} to perform full dumps.
X* IncDumps::		Using @code{tar} to perform incremental dumps.
X* Problems::		Common problems using @code{tar}.
X* Rem Tape::		The remote tape server.
X* Format::		The format of a @code{tar} archive.
X@end menu
X@end ifinfo
X
X@node Why, Commands, Top, Top
X@chapter The Uses of Tape Archives
X
XThe tape archiver @code{tar} allows you to store many files in an
X@dfn{archive file} or @dfn{tar file} which describes the names and contents
Xof the constituent files.  Later you can extract some or all of these files
Xfrom the archive.
X
XTar files are not restricted to magnetic tapes.  The @code{tar} program
Xcan equally well use an ordinary file, or a pipe, or any device, as the
Xarchive.  But they were originally designed for use with magnetic tapes,
Xand that is how the name ``tar'' came about.
X
XArchive files can be used for transporting a group of files from one system
Xto another:  put all relevant files into an archive on one computer system,
Xtransfer the archive to another, and extract the contents there.  The basic
Xtransfer medium might be magnetic tape, Internet FTP, or even electronic
Xmail (though you must encode the archive with @code{uuencode} in order to
Xtransport it properly by mail).  Both machines do not have to use the same
Xoperating system, as long as they both support the @code{tar} program.
X
XA magnetic tape can store several files in sequence, but has no names for
Xthem, just relative position on the tape.  A tar file or something like it
Xis the only way to store several files on one tape and retain their names.
XEven when the basic transfer mechanism can keep track of names, as FTP can,
Xthe nuisance of handling multiple files, directories, and multiple links,
Xmay make a tar file a much easier method.
X
XArchive files are also used for long-term storage, which you can think
Xof as transportation from one time to another.
X
XPiping one @code{tar} to another is an easy way to copy a directory's
Xcontents from one disk to another, while preserving the dates, modes, owners
Xand link-structure of all the files therein.
X
XThe GNU version of @code{tar} has special features that allow it to be
Xused to make incremental and full dumps of all the files in a
Xfilesystem.
X
X@node Commands, Options, Why, Top
X@chapter The Different Operations @code{tar} Can Perform
X
XOne program, @code{tar}, is used to create an archive, to extract files
Xfrom an archive, to modify an archive, or to list the contents.  Each
Xtime you run @code{tar}, you must give a @dfn{command} to specify which
Xone of these things you want to do.
X
XThe command must always be in the first argument to @code{tar}.  This
Xargument can also contain options (@pxref{Options}).  For compatibility
Xwith Unix @code{tar}, the first argument is always treated as containing
Xcommand and option letters even if it doesn't start with @samp{-}.  Thus,
X@samp{tar c} is equivalent to @samp{tar -c}: both of them specify the
X@samp{-c} command to create an archive.
X
XIn addition, a set of long-named options are provided which can be used
Xinstead of or inter-mixed with the single-letter flags.  The long-named
Xoptions are meant to be easy to remember and logical, while the single
Xletter flags may not always be.  Long-named options are preceded by a
X@samp{+}.  In the list of single-letter commands below, each
Xcorresponding long-named option is listed next to it, in parentheses.
X
XThe remaining arguments to @code{tar} are either options, if they start
Xwith @samp{-} or @samp{+}, or files to operate on.
X
XThe file names that you give as arguments are the files that @code{tar} will
Xact on -- for example, they are the files to put in the archive, or the files
Xto extract from it.  If you don't give any file name arguments, the default
Xdepends on which command you used.  Some commands use all relevant files;
Xsome commands have no default and will report an error if you don't specify
Xfiles.
X
XIf a file name argument actually names a directory, then that directory
Xand all files and subdirectories in it are used.
X
XHere is a list of all the @code{tar} commands:
X
X@table @samp
X@item -c
X@itemx +create
XThis command tells @code{tar} to create a new archive that contains the
Xfile(s) specified on the command line.  If you don't specify files, all
Xthe files in the current directory are used.
X
XIf the archive file already exists, it is overwritten; the old contents
Xare lost.
X
X@item -d
X@itemx +compare
X@itemx +diff
XThis command causes @code{tar} to compare the archive with the files in
Xthe file system.  It will report differences in file size, mode, owner,
Xand contents.  If a file exists in the archive, but not in the file
Xsystem, @code{tar} will report this.
X
XIf you specify file names, those files are compared with the tape and
Xthey must all exist in the archive.  If you don't specify files, all
Xthe files in the archive are compared.
X
X@item -r
X@itemx +append
XThis command causes @code{tar} to add the specified file(s) to the end of
Xthe archive.  This assumes that the archive file already exists and is
Xin the proper format (which probably means it was created previously
Xwith the @code{tar} program).  If the archive is not in a format that
X@code{tar} understands, the results will be unpredictable.
X
XYou must specify the files to be used; there is no default.
X
X@item -t
X@itemx +list
XThis command causes @code{tar} to display a list of the files in the
Xarchive.  If you specify file names, only the files that you specify will
Xbe mentioned (but each of them is mentioned only if it appears in the
Xarchive).
X
X@item -u
X@itemx +update
XThis command causes @code{tar} to add the specified files to the end of
Xthe archive, like @w{@samp{-r}}, but only when a file doesn't already
Xexist in the archive or is newer than the version in the archive
X(the last-modification time is compared).  Adding files to the end of an
Xarchive can be very slow.
X
XYou must specify the files to be used; there is no default.
X
X@item -x
X@itemx +extract
X@itemx +get
XThis command causes @code{tar} to extract the specified files from the
Xarchive.  If no file names are given, all the files in the archive will
Xbe extracted.
X
X@item -A
X@itemx +catenate
X@itemx +concatenate
XThis command is used for concatenating several archive files into one big
Xarchive file.  The files to operate on should all be archive files.
XThey are all appended to the end of @emph{the} archive file which
X@code{tar} works on.  (The other files are not changed).
X
XYou might be tempted to use @code{cat} for this, but it won't ordinarily
Xwork.  A @code{tar} archive contains data which indicates the end of the
Xarchive, so more material added to the end with @code{cat} would be
Xignored.  This command works because it removes the end-of-archive
Xmarkers from the middle of the result.
X
X@item -D
X@itemx +delete
XThis command causes @code{tar} to delete the specified files from the
Xarchive.  This command is extremely slow.  Warning: Use of this command
Xon archives stored on magnetic tape may result in a scrambled archive.
XThere is no safe way (except for completely re-writing the archive) to
Xdelete files from a magnetic tape.
X@end table
X
X@node Options, FullDumps, Commands, Top
X@chapter Options That Change How @code{tar} Works
X
XOptions may be specified as individual arguments starting with @samp{-}.
XIn this case, if the option wants an argument (as does, for example,
X@samp{-f}) then the argument should come after the option, separated
Xfrom it by a space.
XAll options are optional.  Some options make sense with any command, while
Xothers are meaningful only with particular commands.@refill
X
X@menu
X* General Options::		Options that are always meaningful.
X* Creation Options::		Options for creating or updating an archive.
X* Extraction Options::		Options for listing or extracting files.
X* Option Syntax::		Old syntax for options
X@end menu
X
X@node General Options, Creation Options, , Options
X@section Options That Are Always Meaningful
X
X@table @samp
X@item -b @var{number}
X@itemx +block-size @var{number}
XThis option is used to specify a @dfn{blocking factor} for the
Xarchive.  When reading or writing the archive, @code{tar}, will do
Xreads and writes of the archive in blocks of @var{number}*512 bytes.
X
XThe default blocking factor is set when @code{tar} is compiled, and is
Xtypically 20.
X
XBlocking factors larger than 20 cannot be read by very old versions of
X@code{tar}, or by some newer versions of @code{tar} running on old machines
Xwith small address spaces.
X
XWith a magnetic tape, larger blocks give faster throughput and fit
Xmore data on a tape (because there are fewer inter-record gaps).  If
Xthe archive is in a disk file or a pipe, you may want to specify a
Xsmaller blocking factor, since a large one will result in a large
Xnumber of null bytes at the end of the archive.
X
XWhen writing cartridge or other streaming tapes, a much larger
Xblocking factor (say 126 or more) will greatly increase performance.
XHowever, you must specify the same blocking factor when reading or
Xupdating the archive.
X
XWith GNU @code{tar} the blocking factor is limited only by the maximum
Xblock size of the device containing the archive, or by the amount of
Xavailable virtual memory.
X
X@item -f @var{filename}
X@itemx +file @var{filename}
XThis option is used to specify the file name of the archive @code{tar}
Xworks on.
X
XIf this option is not given, but the environment variable @code{TAPE}
Xis set, its value is used; otherwise, a default archive name (which was
Xpicked when @code{tar} was compiled) is used.  The default is normally
Xset up to be the ``first'' tape drive or other transportable I/O medium
Xon the system.
X
XIf the filename is @samp{-}, @code{tar} reads the archive from
Xstandard input (when listing or extracting), or writes it to standard
Xoutput (when creating).  If the @samp{-} filename is given when
Xupdating an archive, @code{tar} will read the original archive from
Xits standard input, and will write the entire new archive to its
Xstandard output.
X
XIf the filename contains @samp{:/dev/}, it is interpreted as
X@samp{hostname:filename}.  If the @var{hostname} contains an ``at'' sign
X(@samp{@@}), it is treated as @samp{user@@hostname:filename}.
XIn either case, @code{tar} will invoke the command @code{rsh}
X(or @code{remsh}) to start
Xup an @code{/etc/rmt} on the remote machine.  If you give an alternate login
Xname, it will be given to the @code{rsh}.  Naturally, the remote machine must
Xhave a copy of @file{/etc/rmt}.  @code{/etc/rmt} is free software
Xfrom the University of California, and a copy of the source code can be found
Xwith the sources for @code{tar}.  @code{/etc/rmt} will have to be modified to
Xrun on non-BSD4.3 systems.@refill
X
X@item -C @var{dir}
X@itemx +directory @var{dir}
XThis option causes @code{tar} to change into the directory @var{dir}
Xbefore continuing.  This option is usually interspersed with the files
X@code{tar} is to work on.  For example,
X
X@example 
Xtar -c iggy ziggy -C baz melvin
X@end example
X
X@noindent
Xwill place the files @file{iggy} and @file{ziggy} from the current
Xdirectory on the tape, followed by the file @file{melvin} from the
Xdirectory @file{baz}.  This option is especially useful when you have
Xseveral widely separated files that you want to store in the same
Xdirectory in the archive.
X
XNote that the file @file{melvin} is recorded in the archive under the
Xprecise name @file{melvin}, @emph{not} @file{baz/melvin}.  Thus, the
Xarchive will contain three files that all appear to have come from the
Xsame directory; if the archive is extracted with plain @samp{tar -x},
Xall three files will be created in the current directory.
X
XContrast this with the command
X
X@example
Xtar -c iggy ziggy bar/melvin
X@end example
X
X@noindent
Xwhich records the third file in the archive under the name @file{bar/melvin}
Xso that, if plain @samp{tar -x} is used, the third file will be created
Xin a subdirectory named @file{bar}.
X
X@item -M
X@itemx +multi-volume
XThis option causes @code{tar} to write a @dfn{multi-volume} archive--one
Xthat may be larger than will fit on the medium used to hold it.
X
XWhen this option is used, @code{tar} will not abort when it cannot
Xread or write any more data.  Instead, it will ask you to prepare a
Xnew volume.  If the archive is on a magnetic tape, you should change
Xtapes now; if the archive is on a floppy disk, you should change
Xdisks, etc.
X
XEach volume of a multi-volume archive is an independent tar archive,
Xcomplete in itself.  For example, you can list or extract any volume
Xalone (just don't specify @samp{-M}).  However, if one file in the
Xarchive is split across volumes, the only way to extract it
Xsuccessfully is with a multi-volume extract command (@samp{-xM})
Xstarting on or before the volume where the file begins.
X
X@item -N @var{date}
X@itemx +after-date @var{date}
XThis option causes @code{tar} to only work on files whose modification
Xor inode-changed times are newer than the @var{date} given.  The main
Xuse is for creating an archive; then only new files are written.  If
Xextracting, only newer files are extracted.
X
XRemember that the entire date argument should be quoted if it contains
Xany spaces.
X
XThe date is parsed using @code{getdate}.
X
X@item -R
X@itemx +record-number
XIf @samp{-R} is used, @code{tar} prints, along with every message it
Xwould normally produce, the record number within the archive where
Xthe message occurred.  This option is especially useful when reading
Xdamaged archives, since it helps pinpoint the damaged sections.
X
XThis can also be useful when making a log of a file-system backup tape,
Xsince the results allow you to find the file you want to retrieve
Xon several backup tapes and choose the tape where the file appears
Xearliest (closest to the front of the tape).
X
X@item -T @var{filename}
X@itemx +files-from @var{filename}
XInstead of taking the list of files to work on from the command
Xline, the list of files to work on is read from the file
X@var{filename}.  If @var{filename} is given as @samp{-}, the list is
Xread from standard input.  Note that using both @samp{-T -} and
X@samp{-f -} will not work unless you are using the @samp{-c} command.
X
X@item -v
X@itemx +verbose
XThis option causes @code{tar} to be verbose about the actions it is
Xtaking.
X
XNormally, the @samp{-t} command to list an archive prints
Xjust the file names (one per line) and the other commands are silent.
X
X@samp{-tv} prints a full line of information about each file, like the
Xoutput of @samp{ls -l}.  @samp{-v} with any other command (aside from
X@samp{-t}) prints just the name of each file operated on.
X
XThe output from @samp{-v} appears on the standard output except when
Xcreating or updating an archive to the standard output, 
Xin which case the output from @samp{-v} is sent to the standard
Xerror.
X
X@item +version
X
XThis option causes @code{tar} to print out its version number to the
Xstandard error.  It has no equivalent short option name.
X
X@item -w
X@itemx +interactive
XThis option causes @code{tar} to print a message for each action it
Xintends to take, and ask for confirmation on the terminal.  To
Xconfirm, you must type a line of input.  If your input line begins
Xwith @samp{y}, the action is performed, otherwise it is skipped.
X
XThe actions which require confirmation include adding a file to the
Xarchive, extracting a file from the archive, deleting a file from the
Xarchive, and deleting a file from disk.
X
XIf @code{tar} is reading the archive from the standard input,
X@code{tar} will open the file @file{/dev/tty} to ask for
Xconfirmation on.
X
X@item -X @var{file}
X@itemx +exclude @var{file}
XThis option causes @code{tar} to read a list of filename regular
Xexpressions, one per line, from the file @var{file}; @code{tar} will
Xignore files with those names.  Thus if @code{tar} is called as
X@samp{tar -c -X foo .} and the file @file{foo} contains @samp{*.o} none
Xof the files whose names end in @file{.o} in the current directory (or
Xany subdirectory of the current directory) will be added to the archive.
XMultiple @code{-X} options may be given.
X
X@item -z
X@itemx -Z
X@itemx +compress
X@itemx +uncompress
XThe archive should be compressed as it is written, or decompressed
Xas it is read, using the @code{compress} program.  This option works
Xon physical devices (tape drives, etc.) and remote files as well as
Xon normal files; data to or from such devices or remote files is
Xreblocked by another copy of the @code{tar} program to enforce the
Xspecified (or default) block size.  The default compression
Xparameters are used; if you need to override them, avoid the
X@samp{-z} option and run @code{compress} explicitly.
X
XIf the @samp{-z} option is given twice, or the @samp{+compress-block} option
Xis used, @code{tar} will pad the archive out to the next block boundry
X(@pxref{General Options}).  This may be useful with some devices that
Xrequire that all write operations be a multiple of a certain size.
X
XNote that the @samp{-z} option will not work with the @samp{-M} option,
Xor with the @samp{-u}, @samp{-r}, @samp{-A}, or @samp{-D} commands.
X@end table
X
X@node Creation Options, Extraction Options, General Options, Options
X@section Options for Creating Or Updating an Archive
X
XThese options are used to control which files @code{tar} puts in an
Xarchive, or to control the format the archive is written in (@pxref{Format}).
X
XExcept as noted below, these options are useful with the @samp{-c},
X@samp{-r}, @samp{-u}, @samp{-A}, and @samp{-D} commands.
XAlso note that the @samp{-B} option, (@pxref{Extraction Options}),
Xis also useful with the @samp{-r}, @samp{-u}, @samp{-A}, and @samp{-D} commands.
X
X@table @samp
X@item -G
X@itemx +incremental
XThis option should only be used when creating an incremental backup of
Xa filesystem.  When the @samp{-G} option is used, @code{tar} writes, at
Xthe beginning of the archive, an entry for each of the directories that
Xwill be operated on.  The entry for a directory includes a list of all
Xthe files in the directory at the time the dump was done, and a flag
Xfor each file indicating whether the file is going to be put in the
Xarchive.  This information is used when doing a complete incremental
Xrestore.
X
XNote that this option causes @code{tar} to create a non-standard
Xarchive that may not be readable by non-GNU versions of the @code{tar}
Xprogram.
X
X@item -h
X@itemx +dereference
XIf @samp{-h} is used, when @code{tar} encounters a symbolic link, it
Xwill archive the linked-to file, instead of simply recording the
Xpresence of a symbolic link.  If the linked-to file is archived
Xagain, an entire second copy of it will be archived, instead of a
Xlink.  This could be considered a bug.
X
X@item -l
X@itemx +one-file-system
XThis option causes @code{tar} to not cross filesystem boundaries
Xwhen archiving parts of a directory tree.  This option only
Xaffects files that are archived because they are in a directory that
Xis archived; files named on the command line are archived
Xregardless, and they can be from various file systems.
X
XThis option is useful for making full or incremental archival backups of
Xa file system, as with the Unix @code{dump} command.
X
XFiles which are skipped due to this option are mentioned on the
Xstandard error.
X
X@item -o
X@itemx +old-archive
X@itemx +old
X@itemx +portability
XThis option causes @code{tar} to write an old format archive, which
Xdoes not include information about directories, pipes, fifos,
Xcontiguous files, or device files, and specifies file ownership by
Xnumeric user- and group-ids rather than by user and group names.  In
Xmost cases, a @emph{new} format archive can be read by an @emph{old}
X@code{tar} program without serious trouble, so this option should
Xseldom be needed.  When updating an archive, do not use @samp{-o}
Xunless the archive was created with the @samp{-o} option.
X
X@item -S
X@itemx +sparse
XThis option causes all files to be put in the archive to be tested for
Xsparseness, and handled specially if they are.  The @samp{-S} option
Xis useful when many dbm files, for example, are being backed up, and
Xrunning out of space on the tape is an issue.  Using this option
Xdramatically decreases the amount of space needed to store such a file.
X
XIn later versions, this option may be removed, and the testing and
Xtreatment of sparse files may be done automatically with any special
XGNU options.  For now, it is an option needing to be specified on the
Xcommand line with the creation or updating of an archive.
X
X@item -V @var{name}
X@itemx +volume @var{name}
XThis option causes @code{tar} to write out a @dfn{volume header} at
Xthe beginning of the archive.  If @samp{-M} is used, each volume of
Xthe archive will have a volume header of @samp{@var{name} Volume @var{N}},
Xwhere @var{N} is 1 for the first volume, 2 for the next, and so on.
X
X@item -W
X@itemx +verify
XThis option causes @code{tar} to verify the archive after writing it.
XEach volume is checked after it is written, and any discrepancies are
Xrecorded on the standard error output.
X
XVerification requires that the archive be on a back-space-able medium.
XThis means pipes, some cartridge tape drives, and some other devices
Xcannot be verified.
X@end table
X
X@node Extraction Options, Option Syntax, Creation Options, Options
X@section Options for Listing Or Extracting Files
X
XThe options in this section are meaningful with the @samp{-x} command.
XUnless otherwise stated, they are also meaningful with the @samp{-t}
Xcommand.
X
X@table @samp
X@item -B
X@itemx +read-full-blocks
XIf @samp{-B} is used, @code{tar} will not panic if an attempt to
Xread a block from the archive does not return a full block.  Instead,
X@code{tar} will keep reading until it has obtained a full block.
X
XThis option is turned on by default when @code{tar} is reading an
Xarchive from standard input, or from a remote machine.  This is
Xbecause on BSD Unix systems, a read of a pipe will return however much
Xhappens to be in the pipe, even if it is less than @code{tar}
Xrequested.  If this option was not used, @code{tar} would fail
Xas soon as it read an incomplete block from the pipe.
X
XThis option is also useful with the commands for updating an archive.
X
X@item -G
X@itemx +incremental
XThe @samp{-G} option means the archive is an incremental backup.
XIts meaning depends on the command that it modifies.
X
XIf the @samp{-G} option is used with @samp{-t}, @code{tar} will
Xlist, for each directory in the archive, the list of files in that
Xdirectory at the time the archive was created.  This information is
Xput out in a format that is not easy for humans to read, but which
Xis unambiguous for a program: each filename is preceded by either a
X@samp{Y} if the file is present in the archive, an @samp{N} if the
Xfile is not included in the archive, or a @samp{D} if the file is a
Xdirectory (and is included in the archive).  Each filename is
Xterminated by a null character.  The last file is followed by an
Xadditional null and a newline to indicate the end of the data.
X
XIf the @samp{-G} option is used with @samp{-x}, then when the entry
Xfor a directory is found, all files that currently exist in that directory
Xbut are not listed in the archive @emph{are deleted from the directory}.
X
XThis behavior is convenient when you are restoring a damaged file system
Xfrom a succession of incremental backups: it restores the entire state
Xof the file system to that which obtained when the backup was made.
XIf you don't use @samp{-G}, the file system will probably fill up
Xwith files that shouldn't exist any more.
X
X@item -i
X@itemx +ignore-zeros
XThe @samp{-i} option causes @code{tar} to ignore blocks of zeros in the
Xarchive.  Normally a block of zeros indicates the end of the
Xarchive, but when reading a damaged archive, or one which was created by
X@code{cat}-ing several archives together, this option allows
X@code{tar} to read the entire archive.  This option is not on by
Xdefault because many versions of @code{tar} write garbage after the
Xzeroed blocks.
X
XNote that this option causes @code{tar} to read to the end of the
Xarchive file, which may sometimes avoid problems when multiple files
Xare stored on a single physical tape.
X
X@item -k
X@itemx +keep-old-files
XThe @samp{-k} option prevents @code{tar} from over-writing existing
Xfiles with files with the same name from the archive.
X
XThe @samp{-k} option is meaningless with @samp{-t}.
X
X@item -K @var{filename}
X@itemx +starting-file @var{filename}
XThe @samp{-K} option causes @code{tar} to begin extracting or listing
Xthe archive with the file @var{filename}, and to consider only the
Xfiles starting at that point in the archive.  This is useful if a
Xprevious attempt to extract files failed when it reached
X@var{filename} due to lack of free space.  (This assumes, of course,
Xthat there is now free space, or that you are now extracting into a
Xdifferent file system.)
X
X@item -m
X@item +modification-time
XWhen this option is used, @code{tar} leaves the modification times of
Xthe files it extracts as the time when the files were extracted,
Xinstead of setting it to the time recorded in the archive.
X
XThis option is meaningless with @samp{-t}.
X
X@item -O
X@itemx +to-stdout
XWhen this option is used, instead of creating the files specified,
X@code{tar} writes the contents of the files extracted to its standard
Xoutput.  This may be useful if you are only extracting the files in
Xorder to send them through a pipe.
X
XThis option is meaningless with @samp{-t}.
X
X@item -p
X@itemx +same-permissions
X@itemx +preserve-permissions
XThis option causes @code{tar} to set the modes (access permissions) of
Xextracted files exactly as recorded in the archive.  If this option is
Xnot used, the current @code{umask} setting limits the permissions on
Xextracted files.
X
XThis option is meaningless with @samp{-t}.
X
X@item -P
X@itemx +absolute-paths
XThis option should be used when the absolute pathname of a file should
Xbe preserved in the archive.  @code{tar} normally strips the leading `/'
Xfrom the name of the file, thus making /usr/foo/bar/baz into
Xusr/foo/bar/baz.  Using the @samp{-P} option keeps the pathname intact,
Xand is useful in that it is not necessary to change to the root
Xdirectory when extracting files.
X
X@item -s
X@itemx +same-order
X@itemx +preserve-order
XThis option tells @code{tar} that the list of filenames to be listed or
Xextracted is sorted in the same order as the files in the archive.  This
Xallows a large list of names to be used, even on a small machine that
Xwould not otherwise be able to hold all the names in memory at the same
Xtime.  Such a sorted list can easily be created by running @samp{tar -t}
Xon the archive and editing its output.
X
XThis option is probably never needed on modern computer systems.
X
X@item +preserve
XThe @samp{+preserve} option has no equivalent short option name.
XIt is equivalent to @samp{-p} plus @samp{-s}.
X@end table
X
X@node Option Syntax, , Extraction Options, Options
X@section Old Syntax for Options
X
XFor compatibility with Unix @code{tar}, the first argument can contain
Xoption letters in addition to the command letter; for example, @samp{tar
Xcv} specifies the option @samp{-v} in addition to the command @samp{-c}.
XThe first argument to GNU @code{tar} is always treated as command and
Xoption letters even if it doesn't start with @samp{-}.
X
XSome options need their own arguments; for example, @samp{-f} is followed
Xby the name of the archive file.  When the option is given separately, its
Xargument follows it, as is usual for Unix programs.  For example:
X
X@example
Xtar -c -v -b 20 -f /dev/rmt0
X@end example
X
XWhen options that need arguments are given together with the command, all
Xthe associated arguments follow, in the same order as the options.  Thus,
Xthe example above could also be written in the old style as follows:
X
X@example
Xtar cvbf 20 /dev/rmt0
X@end example
X
X@noindent
XHere @samp{20} is the argument of @samp{-b} and @file{/dev/rmt0} is the
Xargument of @samp{-f}.
X
XThe long-named options can be used instead of the single-letter flags.
XThey are meant to be obvious and easy to remember, possibly more so than
Xtheir corresponding single-letter options.  The above example using
Xlong-named options would look like this:
X
X@example
Xtar +create +verbose +block-size +file 20 /dev/rmt0
X@end example
X
X@node FullDumps, IncDumps, Options, Top
X@chapter Using @code{tar} to Perform Full Dumps
XFull dumps should only be made when no other people or programs are
Xmodifying files in the filesystem.  If files are modified while
X@code{tar} is making the backup, they may not be stored properly in
Xthe archive, in which case you won't be able to restore them if you
Xhave to.
X
XYou will want to use the @samp{-V} option to give the archive a
Xvolume label, so you can tell what this archive is even if the label
Xfalls off the tape, or anything like that.
X
XUnless the filesystem you are dumping is guaranteed to fit on one
Xvolume, you will need to use the @samp{-M} option.  Make sure you
Xhave enough tapes on hand to complete the backup.
X
XIf you want to dump each filesystem separately you will need to use
Xthe @samp{-l} option to prevent @code{tar} from crossing filesystem
Xboundaries when storing (sub)directories.
X
XThe @samp{-G} option is not needed, since this is a complete copy of
Xeverything in the filesystem, and a full restore from this backup
Xwould only be done onto a completely empty disk.
X
XUnless you are in a hurry, and trust the @code{tar} program (and
Xyour tapes), it is a good idea to use the @code{-W} (verify) option,
Xto make sure your files really made it onto the dump properly.  This
Xwill also detect cases where the file was modified while (or just
Xafter) it was being archived.
X
X@node IncDumps, Problems, FullDumps, Top
X@chapter Using @code{tar} to Perform Incremental Dumps
XPerforming incremental dumps is similar to performing full dumps,
Xalthough a few more options will usually be needed.
X
XYou will need to use the @samp{-N @var{date}} option to tell @code{tar} to
Xonly store files that have been modified since @var{date}.
X@var{date} should be the date and time of the last full/incremental
Xdump.
X
XA standard scheme is to do a @samp{monthly} (full) dump once a month,
Xa @samp{weekly} dump once a week of everything since the last monthly and
Xa @samp{daily} every day of everything since the last (weekly or monthly)
Xdump.
X
XHere is a copy of the script used to dump the filesystems of the
Xmachines here at the Free Software Foundation.  This script is run
X(semi-)automatically late at night when people are least likely to
Xbe using the machines.  This script dumps several filesystems from
Xseveral machines at once (by using a network-filesystem).  The
Xoperator is responsible for ensuring that all the machines will be
Xup at the time the dump happens.  If a machine is not running, its
Xfiles will not be dumped, and the next day's incremental dump will
X@emph{not} store files that would have gone onto that dump.
X
X@example
X#!/bin/csh
X# Dump thingie
Xset now = `date`
Xset then = `cat date.nfs.dump`
X/u/hack/bin/tar -c -G -v\
X -f /dev/rtu20\
X -b 126\
X -N "$then"\
X -V "Dump from $then to $now"\
X /alpha-bits/gp\
X /gnu/hack\
X /hobbes/u\
X /spiff/u\
X /sugar-bombs/u
Xecho $now > date.nfs.dump
Xmt -f /dev/rtu20 rew
X@end example
X
XOutput from this script is stored in a file, for the operator to
Xread later.
X
XThis script uses the file @file{date.nfs.dump} to store the date/time of
Xthe last dump.
X
XSince this is a streaming tape drive, no attempt to verify the
Xarchive is done.  This is also why the high blocking factor (126) is
Xused.  The tape drive must also be rewound by the @code{mt} command
Xafter the dump is made.
X
X@node Problems, Rem Tape, IncDumps, Top
X@chapter Common Problems Using @code{tar}
X
XUnless you use the @code{-P} option, GNU @code{tar} will not allow
Xyou to create an archive that contains absolute pathnames.  (An
Xabsolute pathname is one that begins with a @samp{/}.) If you try,
X@code{tar} will automatically remove the leading @samp{/} from the
Xfile names it stores in the archive.  It will also type a warning
Xmessage telling you what it is doing.
X
XWhen reading an archive that was created with a different @code{tar}
Xprogram, GNU @code{tar} automatically extracts entries in the
Xarchive which have absolute pathnames as if the pathnames were not
Xabsolute.  If the archive contained a file @samp{/usr/bin/computoy},
XGNU @code{tar} would extract the file to @samp{usr/bin/computoy} in
Xthe current directory.  If you want to extract the files in an
Xarchive to the same absolute names that they had when the archive
Xwas created, you should do a @samp{cd /} before extracting the files
Xfrom the archive, or you should either use the @samp{-P} option, or
Xuse the command @samp{tar -C / @dots{}}.
X
XSome versions of UNIX, (Ultrix 3.1 is know to have this problem) can
Xclaim that a short write near the end of a tape succeeded, when it
Xactually failed.  This will result in the -M option not working
Xcorrectly.  The best workaround at the moment is to use a
Xsignificantly larger blocksize than the default 20.
X
XIn order to update an archive, @code{tar} must be able to backspace
Xthe archive in order to re-read or re-write a block that was just read
X(or written).  This is currently possible only on two kinds of
Xfiles:  normal disk files (or any other file that can be
Xbackspaced with @code{lseek()}), and industry-standard 9-track magnetic
Xtape (or any other kind of tape that can be backspaced with
X@code{ioctl(@dots{},MTIOCTOP,@dots{})}).
X
XThis means that the @samp{-r}, @samp{-u}, @samp{-A}, and @samp{-D}
Xcommands will not work on any other kind of file.  Some media simply
Xcannot be backspaced, which means these commands and options will
Xnever be able to work on them.  These non-backspacing media include
Xpipes and cartridge tape drives.
X
XSome other media can be backspaced, and @code{tar} will work on them
Xonce @code{tar} is modified to do so.
X
XArchives created with the @samp{-M}, @samp{-V}, and @samp{-G}
Xoptions may not be readable by other version of @code{tar}.  In particular,
Xrestoring a file that was split over a volume boundary will require
Xsome careful work with @code{dd}, if it can be done at all.  Other versions
Xof @code{tar} may also create an empty file whose name is that of
Xthe volume header.  Some versions of @code{tar} may create normal
Xfiles instead of directories archived with the @samp{-G} option.
X
X@node Rem Tape, Format, Problems, Top
X@chapter The Remote Tape Server
XIn order to access the tape drive on a remote machine, @code{tar}
Xuses the remote tape server written at the University of California
Xat Berkeley.  The remote tape server must be installed as
X@file{/etc/rmt} on any machine whose tape drive you want to use.
X@code{tar} calls @file{/etc/rmt} by running an @code{rsh} or
X@code{remsh} to the remote machine, optionally using a different
Xlogin name if one is supplied.
X
XA copy of the source for the remote tape server is provided.  It is
XCopyright @copyright{} 1983 by the Regents of the University of California, but
Xcan be freely distributed.  Instructions for compiling and
Xinstalling it are included in the @file{Makefile}.
X
XThe remote tape server may need to be modified in order to run on a
Xnon-4.3BSD system.
X
X@node Format, , Rem Tape, Top
X@chapter The Format of a @code{tar} Archive
XThis chapter is based heavily on John Gilmore's @i{tar}(5) manual page
Xfor the public domain @code{tar} that GNU @code{tar} is based on.
X
X@section The Standard Format
XA @dfn{tar tape} or file contains a series of records.  Each record
Xcontains @code{RECORDSIZE} bytes.  Although this format may be
Xthought of as being on magnetic tape, other media are often used.
X
XEach file archived is represented by a header record which describes
Xthe file, followed by zero or more records which give the contents
Xof the file.  At the end of the archive file there may be a record
Xfilled with binary zeros as an end-of-file marker.  A reasonable
Xsystem should write a record of zeros at the end, but must not
Xassume that such a record exists when reading an archive.
X
XThe records may be @dfn{blocked} for physical I/O operations.  Each
Xblock of @var{N} records (where @var{N} is set by the @samp{-b}
Xoption to @code{tar}) is written with a single @code{write()}
Xoperation.  On magnetic tapes, the result of such a write is a
Xsingle tape record.  When writing an archive, the last block of
Xrecords should be written at the full size, with records after the
Xzero record containing all zeroes.  When reading an archive, a
Xreasonable system should properly handle an archive whose last block
Xis shorter than the rest, or which contains garbage records after a
Xzero record.
X
XThe header record is defined in C as follows:
X
X@example
X/*
X * Standard Archive Format - Standard TAR - USTAR
X */
X#define RECORDSIZE  	512
X#define NAMSIZ      	100
X#define TUNMLEN      	32
X#define TGNMLEN      	32
X#define SPARSE_EXT_HDR	21
X#define	SPARSE_IN_HDR	4
X
Xstruct sparse @{
X	char offset[12];
X	char numbytes[12];
X@};
X
Xunion record @{
X    char        charptr[RECORDSIZE];
X    struct header @{
X        char    name[NAMSIZ];
X        char    mode[8];
X        char    uid[8];
X        char    gid[8];
X        char    size[12];
X        char    mtime[12];
X        char    chksum[8];
X        char    linkflag;
X        char    linkname[NAMSIZ];
X        char    magic[8];
X        char    uname[TUNMLEN];
X        char    gname[TGNMLEN];
X        char    devmajor[8];
X        char    devminor[8];
X	/* these following fields were added by JF for gnu */
X	/* and are NOT standard */
X	char	atime[12];
X	char	ctime[12];
X	char	offset[12];
X	char	longnames[4];
X	/* the next three fields were added by JK to deal with
X 	   shrinking down sparse files */
X	struct	sparse sp[SPARSE_IN_HDR];
X	char	isextended;
X	char	ending_blanks[12];	/* number of nulls at the
X					   end of the file, if any */
X    @} header;
X
X    struct extended_header @{
X	struct sparse sp[21];
X	char isextended;
X    @} ext_hdr;
X
X@};
X
X/* The checksum field is filled with this while the checksum is computed. */
X#define    CHKBLANKS    "        "        /* 8 blanks, no null */
X
X/* The magic field is filled with this if uname and gname are valid. */
X#define    TMAGIC    "ustar  "        /* 7 chars and a null */
X
X/* The magic field is filled with this if this is a GNU format dump entry */
X#define    GNUMAGIC  "GNUtar "        /* 7 chars and a null */
X
X/* The linkflag defines the type of file */
X#define  LF_OLDNORMAL '\0'       /* Normal disk file, Unix compatible */
X#define  LF_NORMAL    '0'        /* Normal disk file */
X#define  LF_LINK      '1'        /* Link to previously dumped file */
X#define  LF_SYMLINK   '2'        /* Symbolic link */
X#define  LF_CHR       '3'        /* Character special file */
X#define  LF_BLK       '4'        /* Block special file */
X#define  LF_DIR       '5'        /* Directory */
X#define  LF_FIFO      '6'        /* FIFO special file */
X#define  LF_CONTIG    '7'        /* Contiguous file */
X
X/* Further link types which were defined later. */
X#define LF_DUMPDIR	'D'		/* This is a dir entry that contains
X					   the names of files that were in
X					   the dir at the time the dump
X					   was made */
X#define LF_MULTIVOL	'M'		/* This is the continuation
X					   of a file that began on another
X					   volume */
X#define LF_SPARSE	'S'		/* This is for sparse files */
X#define LF_VOLHDR	'V'		/* This file is a tape/volume header */
X					/* Ignore it on extraction */
X
X/* Bits used in the mode field - values in octal */
X#define  TSUID    04000        /* Set UID on execution */
X#define  TSGID    02000        /* Set GID on execution */
X#define  TSVTX    01000        /* Save text (sticky bit) */
X
X/* File permissions */
X#define  TUREAD   00400        /* read by owner */
X#define  TUWRITE  00200        /* write by owner */
X#define  TUEXEC   00100        /* execute/search by owner */
X#define  TGREAD   00040        /* read by group */
X#define  TGWRITE  00020        /* write by group */
X#define  TGEXEC   00010        /* execute/search by group */
X#define  TOREAD   00004        /* read by other */
X#define  TOWRITE  00002        /* write by other */
X#define  TOEXEC   00001        /* execute/search by other */
X@end example
X
XAll characters in header records are represented by using 8-bit
Xcharacters in the local variant of ASCII.  Each field within the
Xstructure is contiguous; that is, there is no padding used within
Xthe structure.  Each character on the archive medium is stored
Xcontiguously.
X
XBytes representing the contents of files (after the header record of
Xeach file) are not translated in any way and are not constrained to
Xrepresent characters in any character set.  The @code{tar} format
Xdoes not distinguish text files from binary files, and no
Xtranslation of file contents is performed.
X
XThe @code{name}, @code{linkname}, @code{magic}, @code{uname}, and
X@code{gname} are null-terminated character strings.  All other
Xfileds are zero-filled octal numbers in ASCII.  Each numeric field
Xof width @var{w} contains @var{w} minus 2 digits, a space, and a null,
Xexcept @code{size}, and @code{mtime}, which do not contain the
Xtrailing null.
X
XThe @code{name} field is the pathname of the file, with directory
Xnames (if any) preceding the file name, separated by slashes.
X
XThe @code{mode} field provides nine bits specifying file permissions
Xand three bits to specify the Set UID, Set GID, and Save Text
X(``stick'') modes.  Values for these bits are defined above.  When
Xspecial permissions are required to create a file with a given mode,
Xand the user restoring files from the archive does not hold such
Xpermissions, the mode bit(s) specifying those special permissions
Xare ignored.  Modes which are not supported by the operating system
Xrestoring files from the archive will be ignored.  Unsupported modes
Xshould be faked up when creating or updating an archive; e.g. the
Xgroup permission could be copied from the @code{other} permission.
X
XThe @code{uid} and @code{gid} fields are the numeric user and group
XID of the file owners, respectively.  If the operating system does
Xnot support numeric user or group IDs, these fields should be
Xignored.
X
XThe @code{size} field is the size of the file in bytes; linked files
Xare archived with this field specified as zero.
X@xref{Extraction Options}; in particular the @samp{-G} option.@refill
X
XThe @code{mtime} field is the modification time of the file at the
Xtime it was archived.  It is the ASCII representation of the octal
Xvalue of the last time the file was modified, represented as an
Xinteger number of seconds since January 1, 1970, 00:00 Coordinated
XUniversal Time.
X
XThe @code{chksum} field is the ASCII representation of the octal
Xvalue of the simple sum of all bytes in the header record.  Each
X8-bit byte in the header is added to an unsigned integer,
Xinitialized to zero, the precision of which shall be no less than
Xseventeen bits.  When calculating the checksum, the @code{chksum}
Xfield is treated as if it were all blanks.
X
XThe @code{typeflag} field specifies the type of file archived.  If a
Xparticular implementation does not recognize or permit the specified
Xtype, the file will be extracted as if it were a regular file.  As
Xthis action occurs, @code{tar} issues a warning to the standard
Xerror.
X
XThe @code{atime} and @code{ctime} fields are used in making incremental
Xbackups; they store, respectively, the particular file's access time and
Xlast inode-change time.
X
XThe @code{offset} is used by the -M option, when making a multi-volume
Xarchive.  The offset is number of bytes into the file that we need to
Xrestart at to continue the file on the next tape, i.e., where we store
Xthe location that a continued file is continued at.
X
XThe @code{longnames} field of the header belongs with something that is
Xnot yet implemented in tar, and is therefore empty.
X
XThe following fields were added to deal with sparse files.  A file is
X@dfn{sparse} if it takes in unallocated blocks which end up being
Xrepresented as zeros, i.e., no useful data.  A test to see if a file is
Xsparse is to look at the number blocks allocated for it versus the number of
Xcharacters in the file; if there are fewer blocks allocated for the file
Xthan would normally be allocated for a file of that size, then the file is
Xsparse.  This is the method tar uses to detect a sparse file, and once such
Xa file is detected, it is treated differently from non-sparse files.
X
XSparse files are often dbm files, or other database-type files which have
Xdata at some points and emptiness in the greater part of the file.  Such
Xfiles can appear to be very large when an @code{ls -l} is done on them,
Xwhen in truth, there may be a very small amount of important data
Xcontained in the file.  It is thus undesirable to have tar think that it
Xmust back up this entire file, as great quantities of room are wasted on
Xempty blocks, which can lead to running out of room on a tape far
Xearlier than is necessary.  Thus, sparse files are dealt with so that
Xthese empty blocks are not written to the tape.  Instead, what is
Xwritten to the tape is a description, of sorts, of the sparse file: where
Xthe holes are, how big the holes are, and how much data is found at the
Xend of the hole.  This way, the file takes up potentially far less room
Xon the tape, and when the file is extracted later on, it will look
Xexactly the way it looked beforehand.  The following is a description of
Xthe fields used to handle a sparse file:
X
XThe @code{sp} is an array of @code{struct sparse}.  Each @code{struct
Xsparse} contains two 12-character strings which represent an offset into
Xthe file and a number of bytes to be written at that offset.  The offset
Xis absolute, and not relative to the offset in preceding array element.
X
XThe header can hold four of these @code{struct sparse} at the moment; if
Xmore are needed, they are not stored in the header.
X
XThe @code{isextended} flag is set when an @code{extended_header} is
Xneeded to deal with a file.  Note that this means that this flag can only
Xbe set when dealing with a sparse file, and it is only set in the event
Xthat the description of the file will not fit in the alloted room for
Xsparse structures in the header.  In other words, an extended_header is
Xneeded.
X
XThe @code{extended_header} structure is used for sparse files which need
Xmore sparse structures than can fit in the header.  The header can fit
X4 such structures; if more are needed, the flag @code{isextended} gets set
Xand the next record is an @code{extended_header}.
X
XEach @code{extended_header} structure contains an array of 21 sparse
Xstructures, along with a similar @code{isextended} flag that the header
Xhad.  There can be an indeterminate number of such @code{extended_header}s
Xto describe a sparse file.
X
X@table @code
X@item LF_NORMAL
X@itemx LF_OLDNORMAL
XThese flags represent a regular file.  In order to be compatible with
Xolder versions of @code{tar}, a @code{typeflag} value of
X@code{LF_OLDNORMAL} should be silently recognized as a regular
Xfile.  New archives should be created using @code{LF_NORMAL}.  Also,
Xfor backward compatibility, @code{tar} treats a regular file whose
Xname ends with a slash as a directory.
X
X@item LF_LINK
XThis flag represents a file linked to another file, of any type,
Xpreviously archived.  Such files are identified in Unix by each file
Xhaving the same device and inode number.  The linked-to
Xname is specified in the @code{linkname} field with a trailing null.
X
X@item LF_SYMLINK
XThis represents a symbolic link to another file.  The linked-to
Xname is specified in the @code{linkname} field with a trailing null.
X
X@item LF_CHR
X@itemx LF_BLK
XThese represent character special files and block special files
Xrespectively.  In this case the @code{devmajor} and @code{devminor}
Xfields will contain the major and minor device numbers
Xrespectively.  Operating systems may map the device specifications
Xto their own local specification, or may ignore the entry.
X
X@item LF_DIR
XThis flag specifies a directory or sub-directory.  The directory name in
Xthe @code{name} field should end with a slash.  On systems where
Xdisk allocation is performed on a directory basis, the @code{size}
Xfield will contain the maximum number of bytes (which may be rounded
Xto the nearest disk block allocation unit) which the directory may
Xhold.  A @code{size} field of zero indicates no such limiting.
XSystems which do not support limiting in this manner should ignore
Xthe @code{size} field.
X
X@item LF_FIFO
XThis specifies a FIFO special file.  Note that the archiving of a
XFIFO file archives the existence of this file and not its contents.
X
X@item LF_CONTIG
XThis specifies a contiguous file, which is the same as a normal
Xfile except that, in operating systems which support it,
Xall its space is allocated contiguously on the disk.  Operating
Xsystems which do not allow contiguous allocation should silently treat
Xthis type as a normal file.
X
X@item 'A' @dots{}
X@itemx 'Z'
XThese are reserved for custom implementations.  Some of these are
Xused in the GNU modified format, as described below.
X@end table
X
XOther values are reserved for specification in future revisions of
Xthe P1003 standard, and should not be used by any @code{tar} program.
X
XThe @code{magic} field indicates that this archive was output in the
XP1003 archive format.  If this field contains @code{TMAGIC}, the
X@code{uname} and @code{gname} fields will contain the ASCII
Xrepresentation of the owner and group of the file respectively.  If
Xfound, the user and group ID represented by these names will be used
Xrather than the values within the @code{uid} and @code{gid} fields.
X
X@section GNU Extensions to the Archive Format
XThe GNU format uses additional file types to describe new types of
Xfiles in an archive.  These are listed below.
X
X@table @code
X@item LF_DUMPDIR
X@itemx 'D'
XThis represents a directory and a list of files created by the
X@samp{-G} option.  The @code{size} field gives the total size of the
Xassociated list of files.  Each filename is preceded by either a @code{'Y'}
X(the file should be in this archive) or an @code{'N'} (The file is a
Xdirectory, or is not stored in the archive).  Each filename is
Xterminated by a null.  There is an additional null after the last
Xfilename.
X
X@item LF_MULTIVOL
X@itemx 'M'
XThis represents a file continued from another volume of a
Xmulti-volume archive created with the @samp{-M} option.  The original
Xtype of the file is not given here.  The @code{size} field gives the
Xmaximum size of this piece of the file (assuming the volume does not
Xend before the file is written out).  The @code{offset} field gives
Xthe offset from the beginning of the file where this part of the
Xfile begins.  Thus @code{size} plus @code{offset} should equal the
Xoriginal size of the file.
X
X@item LF_SPARSE
X@itemx 'S' 
XThis flag indicates that we are dealing with a sparse file.  Note that
Xarchiving a sparse file requires special operations to find holes in the
Xfile, which mark the positions of these holes, along with the number of
Xbytes of data to be found after the hole.
X
X@item LF_VOLHDR
X@itemx 'V'
XThis file type is used to mark the volume header that was given with
Xthe @samp{-V} option when the archive was created.  The @code{name}
Xfield contains the @code{name} given after the @samp{-V} option.
XThe @code{size} field is zero.  Only the first file in each volume
Xof an archive should have this type.
X
X@end table
X
XYou may have trouble reading a GNU format archive on a non-GNU system if
Xthe options @samp{-G}, @samp{-M}, @samp{-S}, or @samp{-V} were used when
Xwriting the archive.  In general, if tar does not use the GNU-added
Xfields of the header, other versions of tar should be able to read the
Xarchive.  Otherwise, the tar program will give an error, the most likely
Xone being a checksum error.
X
X@unnumbered Concept Index
X@printindex cp
X@setchapternewpage odd
X@contents
X@bye
END_OF_FILE
if test 54782 -ne `wc -c <'tar.texinfo'`; then
    echo shar: \"'tar.texinfo'\" unpacked with wrong size!
fi
# end of 'tar.texinfo'
fi
if test -f 'tar.h' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'tar.h'\"
else
echo shar: Extracting \"'tar.h'\" \(9241 characters\)
sed "s/^X//" >'tar.h' <<'END_OF_FILE'
X/*
X
X	Copyright (C) 1988 Free Software Foundation
X
XGNU tar is distributed in the hope that it will be useful, but WITHOUT ANY
XWARRANTY.  No author or distributor accepts responsibility to anyone
Xfor the consequences of using it or for whether it serves any
Xparticular purpose or works at all, unless he says so in writing.
XRefer to the GNU tar General Public License for full details.
X
XEveryone is granted permission to copy, modify and redistribute GNU tar,
Xbut only under the conditions described in the GNU tar General Public
XLicense.  A copy of this license is supposed to have been given to you
Xalong with GNU tar so you can know your rights and responsibilities.  It
Xshould be in a file named COPYING.  Among other things, the copyright
Xnotice and this notice must be preserved on all copies.
X
XIn other words, go ahead and share GNU tar, but don't try to stop
Xanyone else from sharing it farther.  Help stamp out software hoarding!
X*/
X
X/*
X * Header file for tar (tape archive) program.
X *
X * @(#)tar.h 1.24 87/11/06
X *
X * Created 25 August 1985 by John Gilmore, ihnp4!hoptoad!gnu.
X */
X
X#include "testpad.h"
X
X/* major() and minor() macros (among other things) defined here for hpux */
X#ifdef hpux
X#include <sys/mknod.h>
X#endif
X
X/*
X * Kludge for handling systems that can't cope with multiple
X * external definitions of a variable.  In ONE routine (tar.c),
X * we #define TAR_EXTERN to null; here, we set it to "extern" if
X * it is not already set.
X */
X#ifndef TAR_EXTERN
X#define TAR_EXTERN extern
X#endif
X
X#if defined(USG) && !defined(XENIX) && !defined(HAVE_SIZE_T)
Xtypedef int size_t;
X#endif
X
X/*
X * Header block on tape.
X *
X * I'm going to use traditional DP naming conventions here.
X * A "block" is a big chunk of stuff that we do I/O on.
X * A "record" is a piece of info that we care about.
X * Typically many "record"s fit into a "block".
X */
X#define	RECORDSIZE	512
X#define	NAMSIZ		100
X#define	TUNMLEN		32
X#define	TGNMLEN		32
X#define SPARSE_EXT_HDR  21
X#define SPARSE_IN_HDR	4
X
Xstruct sparse {
X	char offset[12];
X	char numbytes[12];
X};
X
Xstruct sp_array {
X	int offset;
X	int numbytes;
X};
X
Xunion record {
X	char		charptr[RECORDSIZE];
X	struct header {
X		char	name[NAMSIZ];
X		char	mode[8];
X		char	uid[8];
X		char	gid[8];
X		char	size[12];
X		char	mtime[12];
X		char	chksum[8];
X		char	linkflag;
X		char	linkname[NAMSIZ];
X		char	magic[8];
X		char	uname[TUNMLEN];
X		char	gname[TGNMLEN];
X		char	devmajor[8];
X		char	devminor[8];
X		/* these following fields were added by JF for gnu */
X		/* and are NOT standard */
X		char	atime[12];
X		char	ctime[12];
X		char	offset[12];
X		char	longnames[4];
X#ifdef NEEDPAD
X		char    pad;
X#endif
X		struct	sparse sp[SPARSE_IN_HDR];
X		char	isextended;
X		char	realsize[12];		/* true size of the sparse file */
X/*		char	ending_blanks[12];*/	/* number of nulls at the
X						   end of the file, if any */
X	} header;
X	struct extended_header {
X		struct sparse sp[21];
X		char isextended;
X	} ext_hdr;
X};
X
X/* The checksum field is filled with this while the checksum is computed. */
X#define	CHKBLANKS	"        "	/* 8 blanks, no null */
X
X/* The magic field is filled with this if uname and gname are valid. */
X#define	TMAGIC		"ustar  "	/* 7 chars and a null */
X
X/* The linkflag defines the type of file */
X#define	LF_OLDNORMAL	'\0'		/* Normal disk file, Unix compat */
X#define	LF_NORMAL	'0'		/* Normal disk file */
X#define	LF_LINK		'1'		/* Link to previously dumped file */
X#define	LF_SYMLINK	'2'		/* Symbolic link */
X#define	LF_CHR		'3'		/* Character special file */
X#define	LF_BLK		'4'		/* Block special file */
X#define	LF_DIR		'5'		/* Directory */
X#define	LF_FIFO		'6'		/* FIFO special file */
X#define	LF_CONTIG	'7'		/* Contiguous file */
X/* Further link types may be defined later. */
X
X/* Note that the standards committee allows only capital A through
X   capital Z for user-defined expansion.  This means that defining something
X   as, say '8' is a *bad* idea. */
X#define LF_DUMPDIR	'D'		/* This is a dir entry that contains
X					   the names of files that were in
X					   the dir at the time the dump
X					   was made */
X#define LF_MULTIVOL	'M'		/* This is the continuation
X					   of a file that began on another
X					   volume */
X#define LF_NAMES	'N'		/* For storing filenames that didn't
X					   fit in 100 characters */
X#define LF_SPARSE	'S'		/* This is for sparse files */
X#define LF_VOLHDR	'V'		/* This file is a tape/volume header */
X					/* Ignore it on extraction */
X
X/*
X * Exit codes from the "tar" program
X */
X#define	EX_SUCCESS	0		/* success! */
X#define	EX_ARGSBAD	1		/* invalid args */
X#define	EX_BADFILE	2		/* invalid filename */
X#define	EX_BADARCH	3		/* bad archive */
X#define	EX_SYSTEM	4		/* system gave unexpected error */
X#define EX_BADVOL	5		/* Special error code means
X					   Tape volume doesn't match the one
X					   specified on the command line */
X
X/*
X * Global variables
X */
XTAR_EXTERN union record	*ar_block;	/* Start of block of archive */
XTAR_EXTERN union record	*ar_record;	/* Current record of archive */
XTAR_EXTERN union record	*ar_last;	/* Last+1 record of archive block */
XTAR_EXTERN char		ar_reading;	/* 0 writing, !0 reading archive */
XTAR_EXTERN int		blocking;	/* Size of each block, in records */
XTAR_EXTERN int		blocksize;	/* Size of each block, in bytes */
XTAR_EXTERN char		*ar_file;	/* File containing archive */
XTAR_EXTERN char		*info_script;	/* Script to run at end of each tape change */
XTAR_EXTERN char		*name_file;	/* File containing names to work on */
XTAR_EXTERN char		*tar;		/* Name of this program */
XTAR_EXTERN struct sp_array *sparsearray;/* Pointer to the start of the scratch space */
XTAR_EXTERN int		sp_array_size;	/* Initial size of the sparsearray */
XTAR_EXTERN int 		tot_written;    /* Total written to output */
XTAR_EXTERN struct re_pattern_buffer
X  			*label_pattern;	/* compiled regex for extract label */
X
X/*
X * Flags from the command line
X */
XTAR_EXTERN int cmd_mode;
X#define CMD_NONE	0
X#define CMD_CAT		1		/* -A */
X#define CMD_CREATE	2		/* -c */
X#define CMD_DIFF	3		/* -d */
X#define CMD_APPEND	4		/* -r */
X#define CMD_LIST	5		/* -t */
X#define CMD_UPDATE	6		/* -u */
X#define CMD_EXTRACT	7		/* -x */
X#define CMD_DELETE	8		/* -D */
X#define CMD_VERSION	9		/* +version */
X
X					/* -[0-9][lmh] */
X			/* CMD_CAT	   -A */
X					/* -b */
XTAR_EXTERN int	f_reblock;		/* -B */
X			/* CMD_CREATE	   -c */
X					/* -C */
X			/* CMD_DIFF	   -d */
X/* TAR_EXTERN char	f_dironly;	/* -D */
X					/* -f */
XTAR_EXTERN int	f_run_script_at_end;	/* -F */
XTAR_EXTERN int 	f_gnudump;		/* -G */
XTAR_EXTERN int	f_follow_links;		/* -h */
XTAR_EXTERN int	f_ignorez;		/* -i */
X			/* CMD_DELETE	   -J */
XTAR_EXTERN int	f_keep;			/* -k */
XTAR_EXTERN int	f_startfile;		/* -K */
XTAR_EXTERN int	f_local_filesys;	/* -l */
XTAR_EXTERN int  tape_length;		/* -L */
XTAR_EXTERN int	f_modified;		/* -m */
XTAR_EXTERN int 	f_multivol;		/* -M */
XTAR_EXTERN int	f_new_files;		/* -N */
XTAR_EXTERN int	f_oldarch;		/* -o */
XTAR_EXTERN int  f_exstdout;		/* -O */
XTAR_EXTERN int	f_use_protection;	/* -p */
XTAR_EXTERN int  f_absolute_paths;	/* -P */
XTAR_EXTERN int	f_sayblock;		/* -R */
XTAR_EXTERN int	f_sorted_names;		/* -s */
XTAR_EXTERN int	f_sparse_files;		/* -S  ... JK */
XTAR_EXTERN int	f_namefile;		/* -T */
X			/* CMD_UPDATE	   -u */
XTAR_EXTERN int	f_verbose;		/* -v */
XTAR_EXTERN char *f_volhdr;		/* -V */
XTAR_EXTERN int  f_confirm;		/* -w */
XTAR_EXTERN int  f_verify;		/* -W */
X			/* CMD_EXTRACT     -x */
XTAR_EXTERN int  f_exclude;		/* -X */
XTAR_EXTERN int 	f_compress;		/* -z */
X					/* -Z */
XTAR_EXTERN int	f_do_chown;		/* +do-chown */
XTAR_EXTERN int  f_totals;		/* +totals */
X
X/*
X * We now default to Unix Standard format rather than 4.2BSD tar format.
X * The code can actually produce all three:
X *	f_standard	ANSI standard
X *	f_oldarch	V7
X *	neither		4.2BSD
X * but we don't bother, since 4.2BSD can read ANSI standard format anyway.
X * The only advantage to the "neither" option is that we can cmp our
X * output to the output of 4.2BSD tar, for debugging.
X */
X#define		f_standard		(!f_oldarch)
X
X/*
X * Structure for keeping track of filenames and lists thereof.
X */
Xstruct name {
X	struct name	*next;
X	short		length;		/* cached strlen(name) */
X	char		found;		/* A matching file has been found */
X	char		firstch;	/* First char is literally matched */
X	char		regexp;		/* This name is a regexp, not literal */
X	char		*change_dir;	/* JF set with the -C option */
X	char		*dir_contents;	/* JF for f_gnudump */
X	char		fake;		/* dummy entry */
X	char		name[1];
X};
X
XTAR_EXTERN struct name	*namelist;	/* Points to first name in list */
XTAR_EXTERN struct name	*namelast;	/* Points to last name in list */
X
XTAR_EXTERN int		archive;	/* File descriptor for archive file */
XTAR_EXTERN int		errors;		/* # of files in error */
X
XTAR_EXTERN char *gnu_dumpfile;
X
X/*
X * Error recovery stuff
X */
XTAR_EXTERN char		read_error_flag;
X
X
X/*
X * Declarations of functions available to the world.
X */
Xunion record *findrec();
Xvoid userec();
Xunion record *endofrecs();
Xvoid anno();
X
X/* Do not prototype these for BSD--see port.c [DOPRNT_MSG].  */
X#if defined(__STDC__) && (!defined(BSD42) || defined(STDC_MSG))
Xvoid msg(char *, ...);
Xvoid msg_perror(char *, ...);
X#else
Xvoid msg();
Xvoid msg_perror();
X#endif
X/* #define	 annorec(stream, msg)	anno(stream, msg, 0)	/* Cur rec */
X/* #define	annofile(stream, msg)	anno(stream, msg, 1)	/* Saved rec */
END_OF_FILE
if test 9241 -ne `wc -c <'tar.h'`; then
    echo shar: \"'tar.h'\" unpacked with wrong size!
fi
# end of 'tar.h'
fi
if test -f 'port.h' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'port.h'\"
else
echo shar: Extracting \"'port.h'\" \(1636 characters\)
sed "s/^X//" >'port.h' <<'END_OF_FILE'
X/* Portability declarations.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X/*
X * Portability declarations for tar.
X *
X * @(#)port.h 1.3	87/11/11	by John Gilmore, 1986
X */
X
X/*
X * Everybody does wait() differently.  There seem to be no definitions
X * for this in V7 (e.g. you are supposed to shift and mask things out
X * using constant shifts and masks.)  So fuck 'em all -- my own non
X * standard but portable macros.  Don't change to a "union wait"
X * based approach -- the ordering of the elements of the struct 
X * depends on the byte-sex of the machine.  Foo!
X */
X#define	TERM_SIGNAL(status)	((status) & 0x7F)
X#define TERM_COREDUMP(status)	(((status) & 0x80) != 0)
X#define TERM_VALUE(status)	((status) >> 8)
X
X#ifdef	MSDOS
X/* missing things from sys/stat.h */
X#define	S_ISUID		0
X#define	S_ISGID		0
X#define	S_ISVTX		0
X
X/* device stuff */
X#define	makedev(ma, mi)		((ma << 8) | mi)
X#define	major(dev)		(dev)
X#define	minor(dev)		(dev)
X#endif	/* MSDOS */
END_OF_FILE
if test 1636 -ne `wc -c <'port.h'`; then
    echo shar: \"'port.h'\" unpacked with wrong size!
fi
# end of 'port.h'
fi
if test -f 'open3.h' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'open3.h'\"
else
echo shar: Extracting \"'open3.h'\" \(2671 characters\)
sed "s/^X//" >'open3.h' <<'END_OF_FILE'
X/* Defines for Sys V style 3-argument open call.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/*
X * @(#)open3.h 1.4 87/11/11
X *
X * open3.h -- #defines for the various flags for the Sys V style 3-argument
X * open() call.  On BSD or System 5, the system already has this in an
X * include file.  This file is needed for V7 and MINIX systems for the
X * benefit of open3() in port.c, a routine that emulates the 3-argument
X * call using system calls available on V7/MINIX. 
X *
X * This file is needed by PD tar even if we aren't using the
X * emulator, since the #defines for O_WRONLY, etc. are used in
X * a couple of places besides the open() calls, (e.g. in the assignment
X * to openflag in extract.c).  We just #include this rather than
X * #ifdef them out.
X *
X * Written 6/10/87 by rmtodd@uokmax (Richard Todd).
X *
X * The names have been changed by John Gilmore, 31 July 1987, since
X * Richard called it "bsdopen", and really this change was introduced in
X * AT&T Unix systems before BSD picked it up.
X */
X
X/* Only one of the next three should be specified */
X#define O_RDONLY	 0 /* only allow read */
X#define	O_WRONLY	 1 /* only allow write */
X#define	O_RDWR		 2 /* both are allowed */
X
X/* The rest of these can be OR-ed in to the above. */
X/*
X * O_NDELAY isn't implemented by the emulator.  It's only useful (to tar) on
X * systems that have named pipes anyway; it prevents tar's hanging by
X * opening a named pipe.  We #ifndef it because some systems already have
X * it defined.
X */
X#ifndef O_NDELAY
X#define O_NDELAY	 4 /* don't block on opening devices that would
X			    * block on open -- ignored by emulator. */
X#endif
X#define O_CREAT		 8 /* create file if needed */
X#define O_EXCL		16 /* file cannot already exist */
X#define O_TRUNC		32 /* truncate file on open */
X#define O_APPEND	64 /* always write at end of file -- ignored by emul */
X
X#ifdef EMUL_OPEN3
X/*
X * make emulation transparent to rest of file -- redirect all open() calls
X * to our routine
X */
X#define open	open3
X#endif
END_OF_FILE
if test 2671 -ne `wc -c <'open3.h'`; then
    echo shar: \"'open3.h'\" unpacked with wrong size!
fi
# end of 'open3.h'
fi
if test -f 'rmt.h' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'rmt.h'\"
else
echo shar: Extracting \"'rmt.h'\" \(2914 characters\)
sed "s/^X//" >'rmt.h' <<'END_OF_FILE'
X/* Remote tape drive defines for tar.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X#ifdef NO_REMOTE
X#define _isrmt(f)	0
X#define rmtopen		open
X#define rmtaccess	access
X#define rmtstat		stat
X#define rmtcreat	creat
X#define rmtlstat	lstat
X#define rmtread		read
X#define rmtwrite	write
X#define rmtlseek	lseek
X#define rmtclose	close
X#define rmtioctl	ioctl
X#define rmtdup		dup
X#define rmtfstat	fstat
X#define rmtfcntl	fcntl
X#define rmtisatty	isatty
X
Xextern long lseek();
X#else
X#ifndef USG
X#define strchr index
X#endif
X
X#define __REM_BIAS	128
X#define RMTIOCTL
X
X#ifndef O_CREAT
X#define O_CREAT	01000
X#endif
Xextern char *__rmt_path;
Xextern char *strchr();
X
X#define _remdev(path)	((__rmt_path=strchr(path, ':')) && strncmp(__rmt_path, ":/dev/", 6)==0)
X#define _isrmt(fd)		((fd) >= __REM_BIAS)
X
X#define rmtopen(path,oflag,mode) (_remdev(path) ? __rmt_open(path, oflag, mode, __REM_BIAS) : open(path, oflag, mode))
X#define rmtaccess(path, amode)	(_remdev(path) ? 0 : access(path, amode))
X#define rmtstat(path, buf)	(_remdev(path) ? (errno = EOPNOTSUPP), -1 : stat(path, buf))
X#define rmtcreat(path, mode)	(_remdev(path) ? __rmt_open (path, 1 | O_CREAT, mode, __REM_BIAS) : creat(path, mode))
X#define rmtlstat(path,buf)	(_remdev(path) ? (errno = EOPNOTSUPP), -1 : lstat(path,buf))
X
X#define rmtread(fd, buf, n)	(_isrmt(fd) ? __rmt_read(fd - __REM_BIAS, buf, n) : read(fd, buf, n))
X#define rmtwrite(fd, buf, n)	(_isrmt(fd) ? __rmt_write(fd - __REM_BIAS, buf, n) : write(fd, buf, n))
X#define rmtlseek(fd, off, wh)	(_isrmt(fd) ? __rmt_lseek(fd - __REM_BIAS, off, wh) : lseek(fd, off, wh))
X#define rmtclose(fd)		(_isrmt(fd) ? __rmt_close(fd - __REM_BIAS) : close(fd))
X#ifdef RMTIOCTL
X#define rmtioctl(fd,req,arg)	(_isrmt(fd) ? __rmt_ioctl(fd - __REM_BIAS, req, arg) : ioctl(fd, req, arg))
X#else
X#define rmtioctl(fd,req,arg)	(_isrmt(fd) ? (errno = EOPNOTSUPP), -1 : ioctl(fd, req, arg))
X#endif
X#define rmtdup(fd)		(_isrmt(fd) ? (errno = EOPNOTSUPP), -1 : dup(fd))
X#define rmtfstat(fd, buf)	(_isrmt(fd) ? (errno = EOPNOTSUPP), -1 : fstat(fd, buf))
X#define rmtfcntl(fd,cmd,arg)	(_isrmt(fd) ? (errno = EOPNOTSUPP), -1 : fcntl (fd, cmd, arg))
X#define rmtisatty(fd)		(_isrmt(fd) ? 0 : isatty(fd))
X
X#undef RMTIOCTL
Xextern long lseek(),__rmt_lseek();
X#endif
END_OF_FILE
if test 2914 -ne `wc -c <'rmt.h'`; then
    echo shar: \"'rmt.h'\" unpacked with wrong size!
fi
# end of 'rmt.h'
fi
if test -f 'msd_dir.h' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'msd_dir.h'\"
else
echo shar: Extracting \"'msd_dir.h'\" \(1018 characters\)
sed "s/^X//" >'msd_dir.h' <<'END_OF_FILE'
X/*
X * @(#)msd_dir.h 1.4 87/11/06	Public Domain.
X *
X *  A public domain implementation of BSD directory routines for
X *  MS-DOS.  Written by Michael Rendell ({uunet,utai}michael@garfield),
X *  August 1897
X */
X
X#define	rewinddir(dirp)	seekdir(dirp, 0L)
X
X#define	MAXNAMLEN	12
X
X#ifdef __TURBOC__
Xtypedef int ino_t;
Xtypedef int dev_t;
X#endif
X
Xstruct direct {
X	ino_t	d_ino;			/* a bit of a farce */
X	int	d_reclen;		/* more farce */
X	int	d_namlen;		/* length of d_name */
X	char	d_name[MAXNAMLEN + 1];		/* garentee null termination */
X};
X
Xstruct _dircontents {
X	char	*_d_entry;
X	struct _dircontents	*_d_next;
X};
X
Xtypedef struct _dirdesc {
X	int		dd_id;	/* uniquely identify each open directory */
X	long		dd_loc;	/* where we are in directory entry is this */
X	struct _dircontents	*dd_contents;	/* pointer to contents of dir */
X	struct _dircontents	*dd_cp;	/* pointer to current position */
X} DIR;
X
Xextern	DIR		*opendir();
Xextern	struct direct	*readdir();
Xextern	void		seekdir();
Xextern	long		telldir();
Xextern	void		closedir();
END_OF_FILE
if test 1018 -ne `wc -c <'msd_dir.h'`; then
    echo shar: \"'msd_dir.h'\" unpacked with wrong size!
fi
# end of 'msd_dir.h'
fi
if test -f 'msd_dir.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'msd_dir.c'\"
else
echo shar: Extracting \"'msd_dir.c'\" \(4230 characters\)
sed "s/^X//" >'msd_dir.c' <<'END_OF_FILE'
X/*
X * @(#)msd_dir.c 1.4 87/11/06	Public Domain.
X *
X *  A public domain implementation of BSD directory routines for
X *  MS-DOS.  Written by Michael Rendell ({uunet,utai}michael@garfield),
X *  August 1897
X */
X
X#include	<sys/types.h>
X#include	<sys/stat.h>
X#include	"msd_dir.h"
X#ifndef __TURBOC__
X#include	<malloc.h>
X#endif
X#include	<string.h>
X#include	<dos.h>
X
X#ifndef	NULL
X# define	NULL	0
X#endif	/* NULL */
X
X#ifndef	MAXPATHLEN
X# define	MAXPATHLEN	255
X#endif	/* MAXPATHLEN */
X
X/* attribute stuff */
X#define	A_RONLY		0x01
X#define	A_HIDDEN	0x02
X#define	A_SYSTEM	0x04
X#define	A_LABEL		0x08
X#define	A_DIR		0x10
X#define	A_ARCHIVE	0x20
X
X/* dos call values */
X#define	DOSI_FINDF	0x4e
X#define	DOSI_FINDN	0x4f
X#define	DOSI_SDTA	0x1a
X
X#define	Newisnull(a, t)		((a = (t *) malloc(sizeof(t))) == (t *) NULL)
X/* #define	ATTRIBUTES		(A_DIR | A_HIDDEN | A_SYSTEM) */
X#define ATTRIBUTES	(A_RONLY | A_SYSTEM | A_DIR)
X
X/* what find first/next calls look use */
Xtypedef struct {
X	char		d_buf[21];
X	char		d_attribute;
X	unsigned short	d_time;
X	unsigned short	d_date;
X	long		d_size;
X	char		d_name[13];
X} Dta_buf;
X
Xstatic	char	*getdirent();
Xstatic	void	mysetdta();
Xstatic	void	free_dircontents();
X
Xstatic	Dta_buf		dtabuf;
Xstatic	Dta_buf		*dtapnt = &dtabuf;
Xstatic	union REGS	reg, nreg;
X
X#if	defined(M_I86LM)
Xstatic	struct SREGS	sreg;
X#endif
X
XDIR	*
Xopendir(name)
X	char	*name;
X{
X	struct	stat		statb;
X	DIR			*dirp;
X	char			c;
X	char			*s;
X	struct _dircontents	*dp;
X	char			nbuf[MAXPATHLEN + 1];
X	
X	if (stat(name, &statb) < 0 || (statb.st_mode & S_IFMT) != S_IFDIR)
X		return (DIR *) NULL;
X	if (Newisnull(dirp, DIR))
X		return (DIR *) NULL;
X	if (*name && (c = name[strlen(name) - 1]) != '\\' && c != '/')
X		(void) strcat(strcpy(nbuf, name), "\\*.*");
X	else
X		(void) strcat(strcpy(nbuf, name), "*.*");
X	dirp->dd_loc = 0;
X	mysetdta();
X	dirp->dd_contents = dirp->dd_cp = (struct _dircontents *) NULL;
X	if ((s = getdirent(nbuf)) == (char *) NULL)
X		return dirp;
X	do {
X		if (Newisnull(dp, struct _dircontents) || (dp->_d_entry =
X			malloc((unsigned) (strlen(s) + 1))) == (char *) NULL)
X		{
X			if (dp)
X				free((char *) dp);
X			free_dircontents(dirp->dd_contents);
X			return (DIR *) NULL;
X		}
X		if (dirp->dd_contents)
X			dirp->dd_cp = dirp->dd_cp->_d_next = dp;
X		else
X			dirp->dd_contents = dirp->dd_cp = dp;
X		(void) strcpy(dp->_d_entry, s);
X		dp->_d_next = (struct _dircontents *) NULL;
X	} while ((s = getdirent((char *) NULL)) != (char *) NULL);
X	dirp->dd_cp = dirp->dd_contents;
X
X	return dirp;
X}
X
Xvoid
Xclosedir(dirp)
X	DIR	*dirp;
X{
X	free_dircontents(dirp->dd_contents);
X	free((char *) dirp);
X}
X
Xstruct direct	*
Xreaddir(dirp)
X	DIR	*dirp;
X{
X	static	struct direct	dp;
X	
X	if (dirp->dd_cp == (struct _dircontents *) NULL)
X		return (struct direct *) NULL;
X	dp.d_namlen = dp.d_reclen =
X		strlen(strcpy(dp.d_name, dirp->dd_cp->_d_entry));
X	strlwr(dp.d_name);		/* JF */
X	dp.d_ino = 0;
X	dirp->dd_cp = dirp->dd_cp->_d_next;
X	dirp->dd_loc++;
X
X	return &dp;
X}
X
Xvoid
Xseekdir(dirp, off)
X	DIR	*dirp;
X	long	off;
X{
X	long			i = off;
X	struct _dircontents	*dp;
X
X	if (off < 0)
X		return;
X	for (dp = dirp->dd_contents ; --i >= 0 && dp ; dp = dp->_d_next)
X		;
X	dirp->dd_loc = off - (i + 1);
X	dirp->dd_cp = dp;
X}
X
Xlong
Xtelldir(dirp)
X	DIR	*dirp;
X{
X	return dirp->dd_loc;
X}
X
Xstatic	void
Xfree_dircontents(dp)
X	struct	_dircontents	*dp;
X{
X	struct _dircontents	*odp;
X
X	while (dp) {
X		if (dp->_d_entry)
X			free(dp->_d_entry);
X		dp = (odp = dp)->_d_next;
X		free((char *) odp);
X	}
X}
X
Xstatic	char	*
Xgetdirent(dir)
X	char	*dir;
X{
X	if (dir != (char *) NULL) {		/* get first entry */
X		reg.h.ah = DOSI_FINDF;
X		reg.h.cl = ATTRIBUTES;
X#if	defined(M_I86LM)
X		reg.x.dx = FP_OFF(dir);
X		sreg.ds = FP_SEG(dir);
X#else
X		reg.x.dx = (unsigned) dir;
X#endif
X	} else {				/* get next entry */
X		reg.h.ah = DOSI_FINDN;
X#if	defined(M_I86LM)
X		reg.x.dx = FP_OFF(dtapnt);
X		sreg.ds = FP_SEG(dtapnt);
X#else
X		reg.x.dx = (unsigned) dtapnt;
X#endif
X	}
X#if	defined(M_I86LM)
X	intdosx(&reg, &nreg, &sreg);
X#else
X	intdos(&reg, &nreg);
X#endif
X	if (nreg.x.cflag)
X		return (char *) NULL;
X
X	return dtabuf.d_name;
X}
X
Xstatic	void
Xmysetdta()
X{
X	reg.h.ah = DOSI_SDTA;
X#if	defined(M_I86LM)
X	reg.x.dx = FP_OFF(dtapnt);
X	sreg.ds = FP_SEG(dtapnt);
X	intdosx(&reg, &nreg, &sreg);
X#else
X	reg.x.dx = (int) dtapnt;
X	intdos(&reg, &nreg);
X#endif
X}
END_OF_FILE
if test 4230 -ne `wc -c <'msd_dir.c'`; then
    echo shar: \"'msd_dir.c'\" unpacked with wrong size!
fi
# end of 'msd_dir.c'
fi
if test -f 'rtape_server.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'rtape_server.c'\"
else
echo shar: Extracting \"'rtape_server.c'\" \(5516 characters\)
sed "s/^X//" >'rtape_server.c' <<'END_OF_FILE'
X/*
X * Copyright (c) 1983 Regents of the University of California.
X * All rights reserved.
X *
X * Redistribution and use in source and binary forms are permitted
X * provided that the above copyright notice and this paragraph are
X * duplicated in all such forms and that any documentation,
X * advertising materials, and other materials related to such
X * distribution and use acknowledge that the software was developed
X * by the University of California, Berkeley.  The name of the
X * University may not be used to endorse or promote products derived
X * from this software without specific prior written permission.
X * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
X * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
X * WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
X */
X
X#ifndef lint
Xchar copyright[] =
X"@(#) Copyright (c) 1983 Regents of the University of California.\n\
X All rights reserved.\n";
X#endif /* not lint */
X
X#ifndef lint
Xstatic char sccsid[] = "@(#)rmt.c	5.4 (Berkeley) 6/29/88";
X#endif /* not lint */
X
X/* JF added #ifdef about SO_RCVBUF in attempt to make this run on more
X   machines.  Maybe it'll work */
X/*
X * rmt
X */
X#include <stdio.h>
X#include <sgtty.h>
X#include <sys/types.h>
X#include <sys/socket.h>
X#include <sys/mtio.h>
X#include <errno.h>
X
X#if defined (i386) && defined (AIX)
X#include <fcntl.h>
X#endif
X
Xint	tape = -1;
X
Xchar	*record;
Xint	maxrecsize = -1;
Xchar	*checkbuf();
X
X#define	SSIZE	64
Xchar	device[SSIZE];
Xchar	count[SSIZE], mode[SSIZE], pos[SSIZE], op[SSIZE];
X
Xextern	errno;
Xchar	*sys_errlist[];
Xchar	resp[BUFSIZ];
X
Xlong	lseek();
X
XFILE	*debug;
X#define	DEBUG(f)	if (debug) fprintf(debug, f)
X#define	DEBUG1(f,a)	if (debug) fprintf(debug, f, a)
X#define	DEBUG2(f,a1,a2)	if (debug) fprintf(debug, f, a1, a2)
X
Xmain(argc, argv)
X	int argc;
X	char **argv;
X{
X	int rval;
X	char c;
X	int n, i, cc;
X
X	argc--, argv++;
X	if (argc > 0) {
X		debug = fopen(*argv, "w");
X		if (debug == 0)
X			exit(1);
X		(void) setbuf(debug, (char *)0);
X	}
Xtop:
X	errno = 0;
X	rval = 0;
X	if (read(0, &c, 1) != 1)
X		exit(0);
X	switch (c) {
X
X	case 'O':
X		if (tape >= 0)
X			(void) close(tape);
X		getstring(device); getstring(mode);
X		DEBUG2("rmtd: O %s %s\n", device, mode);
X#if defined (i386) && defined (AIX)
X		/* This is alleged to fix a byte ordering problem. */
X		/* I'm quite suspicious if it's right. -- mib */
X		{
X		  int oflag = atoi (mode);
X		  int nflag = 0;
X		  if ((oflag & 3) == 0)
X		    nflag |= O_RDONLY;
X		  if (oflag & 1)
X		    nflag |= O_WRONLY;
X		  if (oflag & 2)
X		    nflag |= O_RDWR;
X		  if (oflag & 0x0008)
X		    nflag |= O_APPEND;
X		  if (oflag & 0x0200)
X		    nflag |= O_CREAT;
X		  if (oflag & 0x0400)
X		    nflag |= O_TRUNC;
X		  if (oflag & 0x0800)
X		    nflag |= O_EXCL;
X		  tape = open (device, nflag, 0666);
X		}
X#else		
X		tape = open(device, atoi(mode),0666);
X#endif
X		if (tape < 0)
X			goto ioerror;
X		goto respond;
X
X	case 'C':
X		DEBUG("rmtd: C\n");
X		getstring(device);		/* discard */
X		if (close(tape) < 0)
X			goto ioerror;
X		tape = -1;
X		goto respond;
X
X	case 'L':
X		getstring(count); getstring(pos);
X		DEBUG2("rmtd: L %s %s\n", count, pos);
X		rval = lseek(tape, (long) atoi(count), atoi(pos));
X		if (rval < 0)
X			goto ioerror;
X		goto respond;
X
X	case 'W':
X		getstring(count);
X		n = atoi(count);
X		DEBUG1("rmtd: W %s\n", count);
X		record = checkbuf(record, n);
X		for (i = 0; i < n; i += cc) {
X			cc = read(0, &record[i], n - i);
X			if (cc <= 0) {
X				DEBUG("rmtd: premature eof\n");
X				exit(2);
X			}
X		}
X		rval = write(tape, record, n);
X		if (rval < 0)
X			goto ioerror;
X		goto respond;
X
X	case 'R':
X		getstring(count);
X		DEBUG1("rmtd: R %s\n", count);
X		n = atoi(count);
X		record = checkbuf(record, n);
X		rval = read(tape, record, n);
X		if (rval < 0)
X			goto ioerror;
X		(void) sprintf(resp, "A%d\n", rval);
X		(void) write(1, resp, strlen(resp));
X		(void) write(1, record, rval);
X		goto top;
X
X	case 'I':
X		getstring(op); getstring(count);
X		DEBUG2("rmtd: I %s %s\n", op, count);
X		{ struct mtop mtop;
X		  mtop.mt_op = atoi(op);
X		  mtop.mt_count = atoi(count);
X		  if (ioctl(tape, MTIOCTOP, (char *)&mtop) < 0)
X			goto ioerror;
X		  rval = mtop.mt_count;
X		}
X		goto respond;
X
X	case 'S':		/* status */
X		DEBUG("rmtd: S\n");
X		{ struct mtget mtget;
X		  if (ioctl(tape, MTIOCGET, (char *)&mtget) < 0)
X			goto ioerror;
X		  rval = sizeof (mtget);
X		  (void) sprintf(resp, "A%d\n", rval);
X		  (void) write(1, resp, strlen(resp));
X		  (void) write(1, (char *)&mtget, sizeof (mtget));
X		  goto top;
X		}
X
X	default:
X		DEBUG1("rmtd: garbage command %c\n", c);
X		exit(3);
X	}
Xrespond:
X	DEBUG1("rmtd: A %d\n", rval);
X	(void) sprintf(resp, "A%d\n", rval);
X	(void) write(1, resp, strlen(resp));
X	goto top;
Xioerror:
X	error(errno);
X	goto top;
X}
X
Xgetstring(bp)
X	char *bp;
X{
X	int i;
X	char *cp = bp;
X
X	for (i = 0; i < SSIZE; i++) {
X		if (read(0, cp+i, 1) != 1)
X			exit(0);
X		if (cp[i] == '\n')
X			break;
X	}
X	cp[i] = '\0';
X}
X
Xchar *
Xcheckbuf(record, size)
X	char *record;
X	int size;
X{
X	extern char *malloc();
X
X	if (size <= maxrecsize)
X		return (record);
X	if (record != 0)
X		free(record);
X	record = malloc(size);
X	if (record == 0) {
X		DEBUG("rmtd: cannot allocate buffer space\n");
X		exit(4);
X	}
X	maxrecsize = size;
X#ifdef SO_RCVBUF
X	while (size > 1024 &&
X	       setsockopt(0, SOL_SOCKET, SO_RCVBUF, &size, sizeof (size)) < 0)
X		size -= 1024;
X#else
X	size= 1+((size-1)%1024);
X#endif
X	return (record);
X}
X
Xerror(num)
X	int num;
X{
X
X	DEBUG2("rmtd: E %d (%s)\n", num, sys_errlist[num]);
X	(void) sprintf(resp, "E%d\n%s\n", num, sys_errlist[num]);
X	(void) write(1, resp, strlen (resp));
X}
END_OF_FILE
if test 5516 -ne `wc -c <'rtape_server.c'`; then
    echo shar: \"'rtape_server.c'\" unpacked with wrong size!
fi
# end of 'rtape_server.c'
fi
if test -f 'rtape_lib.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'rtape_lib.c'\"
else
echo shar: Extracting \"'rtape_lib.c'\" \(13040 characters\)
sed "s/^X//" >'rtape_lib.c' <<'END_OF_FILE'
X/* Remote tape emulator subroutines.
X   Copyright (C) 1988 Free Software Foundation
X
XThis file is part of GNU Tar.
X
XGNU Tar is free software; you can redistribute it and/or modify
Xit under the terms of the GNU General Public License as published by
Xthe Free Software Foundation; either version 1, or (at your option)
Xany later version.
X
XGNU Tar is distributed in the hope that it will be useful,
Xbut WITHOUT ANY WARRANTY; without even the implied warranty of
XMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
XGNU General Public License for more details.
X
XYou should have received a copy of the GNU General Public License
Xalong with GNU Tar; see the file COPYING.  If not, write to
Xthe Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/* JF: modified to make all rmtXXX calls into macros for speed */
X
X#ifndef lint
Xstatic char *RCSid = "$Header: /usr/src/local/usr.lib/librmt/RCS/rmtlib.c,v 1.7 89/03/23 14:09:51 root Exp Locker: root $";
X#endif
X
X/*
X * $Log:	rmtlib.c,v $
X * Revision 1.7  89/03/23  14:09:51  root
X * Fix from haynes@ucscc.ucsc.edu for use w/compat. ADR.
X * 
X * Revision 1.6  88/10/25  17:04:29  root
X * rexec code and a bug fix from srs!dan, miscellanious cleanup. ADR.
X * 
X * Revision 1.5  88/10/25  16:30:17  root
X * Fix from jeff@gatech.edu for getting user@host:dev right. ADR.
X * 
X * Revision 1.4  87/10/30  10:36:12  root
X * Made 4.2 syntax a compile time option. ADR.
X * 
X * Revision 1.3  87/04/22  11:16:48  root
X * Two fixes from parmelee@wayback.cs.cornell.edu to correctly
X * do fd biasing and rmt protocol on 'S' command. ADR.
X * 
X * Revision 1.2  86/10/09  16:38:53  root
X * Changed to reflect 4.3BSD rcp syntax. ADR.
X * 
X * Revision 1.1  86/10/09  16:17:35  root
X * Initial revision
X * 
X */
X
X/*
X *	rmt --- remote tape emulator subroutines
X *
X *	Originally written by Jeff Lee, modified some by Arnold Robbins
X *
X *	WARNING:  The man page rmt(8) for /etc/rmt documents the remote mag
X *	tape protocol which rdump and rrestore use.  Unfortunately, the man
X *	page is *WRONG*.  The author of the routines I'm including originally
X *	wrote his code just based on the man page, and it didn't work, so he
X *	went to the rdump source to figure out why.  The only thing he had to
X *	change was to check for the 'F' return code in addition to the 'E',
X *	and to separate the various arguments with \n instead of a space.  I
X *	personally don't think that this is much of a problem, but I wanted to
X *	point it out.
X *	-- Arnold Robbins
X *
X *	Redone as a library that can replace open, read, write, etc, by
X *	Fred Fish, with some additional work by Arnold Robbins.
X */
X 
X/* Use -DUSE_REXEC for rexec code, courtesy of Dan Kegel, srs!dan */
X
X#if defined(USG) && !defined(HAVE_MTIO)
X#define NO_RMTIOCTL
X#endif
X
X#include <stdio.h>
X#include <signal.h>
X#include <sys/types.h>
X
X#ifndef NO_RMTIOCTL
X#include <sys/ioctl.h>
X#include <sys/mtio.h>
X#endif
X
X#ifdef USE_REXEC
X#include <netdb.h>
X#endif
X
X#include <errno.h>
X#include <setjmp.h>
X#include <sys/stat.h>
X
X#define BUFMAGIC	64	/* a magic number for buffer sizes */
X
X/*
X *	MAXUNIT --- Maximum number of remote tape file units
X */
X#define MAXUNIT	4
X
X/*
X *	READ --- Return the number of the read side file descriptor
X *	WRITE --- Return the number of the write side file descriptor
X */
X#define READ(fd)	(Ctp[fd][0])
X#define WRITE(fd)	(Ptc[fd][1])
X
Xstatic int Ctp[MAXUNIT][2] = { -1, -1, -1, -1, -1, -1, -1, -1 };
Xstatic int Ptc[MAXUNIT][2] = { -1, -1, -1, -1, -1, -1, -1, -1 };
X
Xextern int errno;
X
Xchar *__rmt_path;
X
X/*
X *	_rmt_panic --- close off a remote tape connection
X */
X
Xstatic void _rmt_panic(fildes)
Xint fildes;
X{
X	close(READ(fildes));
X	close(WRITE(fildes));
X	READ(fildes) = -1;
X	WRITE(fildes) = -1;
X}
X
X
X
X/*
X *	command --- attempt to perform a remote tape command
X */
X
Xstatic int command(fildes, buf)
Xint fildes;
Xchar *buf;
X{
X	register int blen;
X#ifdef SIGNAL_VOID
X	void (*pstat)();
X#else
X	int (*pstat)();
X#endif
X
X/*
X *	save current pipe status and try to make the request
X */
X
X	blen = strlen(buf);
X	pstat = signal(SIGPIPE, SIG_IGN);
X	if (write(WRITE(fildes), buf, blen) == blen)
X	{
X		signal(SIGPIPE, pstat);
X		return(0);
X	}
X
X/*
X *	something went wrong. close down and go home
X */
X
X	signal(SIGPIPE, pstat);
X	_rmt_panic(fildes);
X
X	errno = EIO;
X	return(-1);
X}
X
X
X
X/*
X *	status --- retrieve the status from the pipe
X */
X
Xstatic int status(fildes)
Xint fildes;
X{
X	int i;
X	char c, *cp;
X	char buffer[BUFMAGIC];
X
X/*
X *	read the reply command line
X */
X
X	for (i = 0, cp = buffer; i < BUFMAGIC; i++, cp++)
X	{
X		if (read(READ(fildes), cp, 1) != 1)
X		{
X			_rmt_panic(fildes);
X			errno = EIO;
X			return(-1);
X		}
X		if (*cp == '\n')
X		{
X			*cp = 0;
X			break;
X		}
X	}
X
X	if (i == BUFMAGIC)
X	{
X		_rmt_panic(fildes);
X		errno = EIO;
X		return(-1);
X	}
X
X/*
X *	check the return status
X */
X
X	for (cp = buffer; *cp; cp++)
X		if (*cp != ' ')
X			break;
X
X	if (*cp == 'E' || *cp == 'F')
X	{
X		errno = atoi(cp + 1);
X		while (read(READ(fildes), &c, 1) == 1)
X			if (c == '\n')
X				break;
X
X		if (*cp == 'F')
X			_rmt_panic(fildes);
X
X		return(-1);
X	}
X
X/*
X *	check for mis-synced pipes
X */
X
X	if (*cp != 'A')
X	{
X		_rmt_panic(fildes);
X		errno = EIO;
X		return(-1);
X	}
X
X	return(atoi(cp + 1));
X}
X
X#ifdef USE_REXEC
X
X/*
X * _rmt_rexec
X *
X * execute /etc/rmt on a remote system using rexec().
X * Return file descriptor of bidirectional socket for stdin and stdout
X * If username is NULL, or an empty string, uses current username.
X *
X * ADR: By default, this code is not used, since it requires that
X * the user have a .netrc file in his/her home directory, or that the
X * application designer be willing to have rexec prompt for login and
X * password info. This may be unacceptable, and .rhosts files for use
X * with rsh are much more common on BSD systems.
X */
X
Xstatic int
X_rmt_rexec(host, user)
Xchar *host;
Xchar *user;		/* may be NULL */
X{
X	struct servent *rexecserv;
X	int save_stdin = dup(fileno(stdin));
X	int save_stdout = dup(fileno(stdout));
X	int tape_fd;		/* Return value. */
X
X	/*
X	 * When using cpio -o < filename, stdin is no longer the tty.
X	 * But the rexec subroutine reads the login and the passwd on stdin, 
X	 * to allow remote execution of the command.
X	 * So, reopen stdin and stdout on /dev/tty before the rexec and
X	 * give them back their original value after.
X	 */
X	if (freopen("/dev/tty", "r", stdin) == NULL)
X		freopen("/dev/null", "r", stdin);
X	if (freopen("/dev/tty", "w", stdout) == NULL)
X		freopen("/dev/null", "w", stdout);
X
X	rexecserv = getservbyname("exec", "tcp");
X	if (NULL == rexecserv) {
X		fprintf (stderr, "? exec/tcp: service not available.");
X		exit (-1);
X	}
X	if ((user != NULL) && *user == '\0')
X		user = (char *) NULL;
X	tape_fd = rexec (&host, rexecserv->s_port, user, NULL,
X			 "/etc/rmt", (int *)NULL);
X	fclose(stdin);
X	fdopen(save_stdin, "r");
X	fclose(stdout);
X	fdopen(save_stdout, "w");
X
X	return tape_fd;
X}
X#endif /* USE_REXEC */
X
X/*
X *	_rmt_open --- open a magtape device on system specified, as given user
X *
X *	file name has the form [user@]system:/dev/????
X#ifdef COMPAT
X *	file name has the form system[.user]:/dev/????
X#endif
X */
X
X#define MAXHOSTLEN	257	/* BSD allows very long host names... */
X
Xint __rmt_open (path, oflag, mode, bias)
Xchar *path;
Xint oflag;
Xint mode;
Xint bias;
X{
X	int i, rc;
X	char buffer[BUFMAGIC];
X	char system[MAXHOSTLEN];
X	char device[BUFMAGIC];
X	char login[BUFMAGIC];
X	char *sys, *dev, *user;
X
X	sys = system;
X	dev = device;
X	user = login;
X
X/*
X *	first, find an open pair of file descriptors
X */
X
X	for (i = 0; i < MAXUNIT; i++)
X		if (READ(i) == -1 && WRITE(i) == -1)
X			break;
X
X	if (i == MAXUNIT)
X	{
X		errno = EMFILE;
X		return(-1);
X	}
X
X/*
X *	pull apart system and device, and optional user
X *	don't munge original string
X *	if COMPAT is defined, also handle old (4.2) style person.site notation.
X */
X
X	while (*path != '@'
X#ifdef COMPAT
X			&& *path != '.'
X#endif
X			&& *path != ':') {
X		*sys++ = *path++;
X	}
X	*sys = '\0';
X	path++;
X
X	if (*(path - 1) == '@')
X	{
X		(void) strcpy (user, system);	/* saw user part of user@host */
X		sys = system;			/* start over */
X		while (*path != ':') {
X			*sys++ = *path++;
X		}
X		*sys = '\0';
X		path++;
X	}
X#ifdef COMPAT
X	else if (*(path - 1) == '.')
X	{
X		while (*path != ':') {
X			*user++ = *path++;
X		}
X		*user = '\0';
X		path++;
X	}
X#endif
X	else
X		*user = '\0';
X
X	while (*path) {
X		*dev++ = *path++;
X	}
X	*dev = '\0';
X
X#ifdef USE_REXEC
X/* 
X *	Execute the remote command using rexec 
X */
X	READ(i) = WRITE(i) = _rmt_rexec(system, login);
X	if (READ(i) < 0)
X		return -1;
X#else
X/*
X *	setup the pipes for the 'rsh' command and fork
X */
X
X	if (pipe(Ptc[i]) == -1 || pipe(Ctp[i]) == -1)
X		return(-1);
X
X	if ((rc = fork()) == -1)
X		return(-1);
X
X	if (rc == 0)
X	{
X		close(0);
X		dup(Ptc[i][0]);
X		close(Ptc[i][0]); close(Ptc[i][1]);
X		close(1);
X		dup(Ctp[i][1]);
X		close(Ctp[i][0]); close(Ctp[i][1]);
X		(void) setuid (getuid ());
X		(void) setgid (getgid ());
X		if (*login)
X		{
X			execl("/usr/ucb/rsh", "rsh", system, "-l", login,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bin/remsh", "remsh", system, "-l", login,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bin/rsh", "rsh", system, "-l", login,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bsd/rsh", "rsh", system, "-l", login,
X				"/etc/rmt", (char *)0);
X			execl("/usr/bin/nsh", "nsh", system, "-l", login,
X			        "/etc/rmt", (char *)0);
X		}
X		else
X		{
X			execl("/usr/ucb/rsh", "rsh", system,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bin/remsh", "remsh", system,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bin/rsh", "rsh", system,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bsd/rsh", "rsh", system,
X				"/etc/rmt", (char *) 0);
X			execl("/usr/bin/nsh", "nsh", system,
X			        "/etc/rmt", (char *)0);
X		}
X
X/*
X *	bad problems if we get here
X */
X
X		perror("remote shell exec");
X		exit(1);
X	}
X
X	close(Ptc[i][0]); close(Ctp[i][1]);
X#endif
X
X/*
X *	now attempt to open the tape device
X */
X
X	sprintf(buffer, "O%s\n%d\n", device, oflag);
X	if (command(i, buffer) == -1 || status(i) == -1)
X		return(-1);
X
X	return(i+bias);
X}
X
X
X
X/*
X *	_rmt_close --- close a remote magtape unit and shut down
X */
X
X int __rmt_close(fildes)
Xint fildes;
X{
X	int rc;
X
X	if (command(fildes, "C\n") != -1)
X	{
X		rc = status(fildes);
X
X		_rmt_panic(fildes);
X		return(rc);
X	}
X
X	return(-1);
X}
X
X
X
X/*
X *	_rmt_read --- read a buffer from a remote tape
X */
X
Xint __rmt_read(fildes, buf, nbyte)
Xint fildes;
Xchar *buf;
Xunsigned int nbyte;
X{
X	int rc, i;
X	char buffer[BUFMAGIC];
X
X	sprintf(buffer, "R%d\n", nbyte);
X	if (command(fildes, buffer) == -1 || (rc = status(fildes)) == -1)
X		return(-1);
X
X	for (i = 0; i < rc; i += nbyte, buf += nbyte)
X	{
X		nbyte = read(READ(fildes), buf, rc);
X		if (nbyte <= 0)
X		{
X			_rmt_panic(fildes);
X			errno = EIO;
X			return(-1);
X		}
X	}
X
X	return(rc);
X}
X
X
X
X/*
X *	_rmt_write --- write a buffer to the remote tape
X */
X
Xint __rmt_write(fildes, buf, nbyte)
Xint fildes;
Xchar *buf;
Xunsigned int nbyte;
X{
X	char buffer[BUFMAGIC];
X#ifdef SIGNAL_VOID
X	void (*pstat)();
X#else
X	int (*pstat)();
X#endif
X
X	sprintf(buffer, "W%d\n", nbyte);
X	if (command(fildes, buffer) == -1)
X		return(-1);
X
X	pstat = signal(SIGPIPE, SIG_IGN);
X	if (write(WRITE(fildes), buf, nbyte) == nbyte)
X	{
X		signal (SIGPIPE, pstat);
X		return(status(fildes));
X	}
X
X	signal (SIGPIPE, pstat);
X	_rmt_panic(fildes);
X	errno = EIO;
X	return(-1);
X}
X
X
X
X/*
X *	_rmt_lseek --- perform an imitation lseek operation remotely
X */
X
Xlong __rmt_lseek(fildes, offset, whence)
Xint fildes;
Xlong offset;
Xint whence;
X{
X	char buffer[BUFMAGIC];
X
X	sprintf(buffer, "L%d\n%d\n", offset, whence);
X	if (command(fildes, buffer) == -1)
X		return(-1);
X
X	return(status(fildes));
X}
X
X
X/*
X *	_rmt_ioctl --- perform raw tape operations remotely
X */
X
X#ifndef NO_RMTIOCTL
X__rmt_ioctl(fildes, op, arg)
Xint fildes, op;
Xchar *arg;
X{
X	char c;
X	int rc, cnt;
X	char buffer[BUFMAGIC];
X
X/*
X *	MTIOCOP is the easy one. nothing is transfered in binary
X */
X
X	if (op == MTIOCTOP)
X	{
X		sprintf(buffer, "I%d\n%d\n", ((struct mtop *) arg)->mt_op,
X			((struct mtop *) arg)->mt_count);
X		if (command(fildes, buffer) == -1)
X			return(-1);
X		return(status(fildes));
X	}
X
X/*
X *	we can only handle 2 ops, if not the other one, punt
X */
X
X	if (op != MTIOCGET)
X	{
X		errno = EINVAL;
X		return(-1);
X	}
X
X/*
X *	grab the status and read it directly into the structure
X *	this assumes that the status buffer is (hopefully) not
X *	padded and that 2 shorts fit in a long without any word
X *	alignment problems, ie - the whole struct is contiguous
X *	NOTE - this is probably NOT a good assumption.
X */
X
X	if (command(fildes, "S") == -1 || (rc = status(fildes)) == -1)
X		return(-1);
X
X	for (; rc > 0; rc -= cnt, arg += cnt)
X	{
X		cnt = read(READ(fildes), arg, rc);
X		if (cnt <= 0)
X		{
X			_rmt_panic(fildes);
X			errno = EIO;
X			return(-1);
X		}
X	}
X
X/*
X *	now we check for byte position. mt_type is a small integer field
X *	(normally) so we will check its magnitude. if it is larger than
X *	256, we will assume that the bytes are swapped and go through
X *	and reverse all the bytes
X */
X
X	if (((struct mtget *) arg)->mt_type < 256)
X		return(0);
X
X	for (cnt = 0; cnt < rc; cnt += 2)
X	{
X		c = arg[cnt];
X		arg[cnt] = arg[cnt+1];
X		arg[cnt+1] = c;
X	}
X
X	return(0);
X  }
X#endif /* NO_RMTIOCTL */
END_OF_FILE
if test 13040 -ne `wc -c <'rtape_lib.c'`; then
    echo shar: \"'rtape_lib.c'\" unpacked with wrong size!
fi
# end of 'rtape_lib.c'
fi
if test -f 'getdate.y' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'getdate.y'\"
else
echo shar: Extracting \"'getdate.y'\" \(21433 characters\)
sed "s/^X//" >'getdate.y' <<'END_OF_FILE'
X%{
X/* $Revision: 2.1 $
X**
X**  Originally written by Steven M. Bellovin <smb@research.att.com> while
X**  at the University of North Carolina at Chapel Hill.  Later tweaked by
X**  a couple of people on Usenet.  Completely overhauled by Rich $alz
X**  <rsalz@bbn.com> and Jim Berets <jberets@bbn.com> in August, 1990;
X**  send any email to Rich.
X**
X**  This grammar has eight shift/reduce conflicts.
X**
X**  This code is in the public domain and has no copyright.
X*/
X/* SUPPRESS 287 on yaccpar_sccsid *//* Unusd static variable */
X/* SUPPRESS 288 on yyerrlab *//* Label unused */
X
X#ifdef __GNUC__
X#define alloca __builtin_alloca
X#else
X#ifdef sparc
X#include <alloca.h>
X#else
X#ifdef _AIX /* for Bison */
X#pragma alloca
X#else
Xchar *alloca ();
X#endif
X#endif
X#endif
X
X#include <stdio.h>
X#include <ctype.h>
X
X#if	defined(vms)
X#include <types.h>
X#include <time.h>
X#else
X#include <sys/types.h>
X#if	defined(USG)
X/*
X**  Uncomment the next line if you need to do a tzset() call to set the
X**  timezone, and don't have ftime().  Some SystemV releases, I think.
X*/
X/*#define NEED_TZSET */
Xstruct timeb {
X    time_t		time;		/* Seconds since the epoch	*/
X    unsigned short	millitm;	/* Field not used		*/
X    short		timezone;
X    short		dstflag;	/* Field not used		*/
X};
X#else
X#include <sys/timeb.h>
X#endif	/* defined(USG) */
X#if	defined(BSD4_2) || defined(BSD4_1C)
X#include <sys/time.h>
X#else
X#include <time.h>
X#endif	/* defined(BSD4_2) */
X#endif	/* defined(vms) */
X
X#if defined (STDC_HEADERS) || defined (USG)
X#include <string.h>
X#endif
X
Xextern struct tm	*localtime();
X
X#define yyparse getdate_yyparse
X#define yylex getdate_yylex
X#define yyerror getdate_yyerror
X
X#if	!defined(lint) && !defined(SABER)
Xstatic char RCS[] =
X	"$Header: str2date.y,v 2.1 90/09/06 08:15:06 cronan Exp $";
X#endif	/* !defined(lint) && !defined(SABER) */
X
X
X#define EPOCH		1970
X#define HOUR(x)		(x * 60)
X#define SECSPERDAY	(24L * 60L * 60L)
X
X
X/*
X**  An entry in the lexical lookup table.
X*/
Xtypedef struct _TABLE {
X    char	*name;
X    int		type;
X    time_t	value;
X} TABLE;
X
X
X/*
X**  Daylight-savings mode:  on, off, or not yet known.
X*/
Xtypedef enum _DSTMODE {
X    DSTon, DSToff, DSTmaybe
X} DSTMODE;
X
X/*
X**  Meridian:  am, pm, or 24-hour style.
X*/
Xtypedef enum _MERIDIAN {
X    MERam, MERpm, MER24
X} MERIDIAN;
X
X
X/*
X**  Global variables.  We could get rid of most of these by using a good
X**  union as the yacc stack.  (This routine was originally written before
X**  yacc had the %union construct.)  Maybe someday; right now we only use
X**  the %union very rarely.
X*/
Xstatic char	*yyInput;
Xstatic DSTMODE	yyDSTmode;
Xstatic time_t	yyDayOrdinal;
Xstatic time_t	yyDayNumber;
Xstatic int	yyHaveDate;
Xstatic int	yyHaveDay;
Xstatic int	yyHaveRel;
Xstatic int	yyHaveTime;
Xstatic int	yyHaveZone;
Xstatic time_t	yyTimezone;
Xstatic time_t	yyDay;
Xstatic time_t	yyHour;
Xstatic time_t	yyMinutes;
Xstatic time_t	yyMonth;
Xstatic time_t	yySeconds;
Xstatic time_t	yyYear;
Xstatic MERIDIAN	yyMeridian;
Xstatic time_t	yyRelMonth;
Xstatic time_t	yyRelSeconds;
X
X%}
X
X%union {
X    time_t		Number;
X    enum _MERIDIAN	Meridian;
X}
X
X%token	tAGO tDAY tDAYZONE tID tMERIDIAN tMINUTE_UNIT tMONTH tMONTH_UNIT
X%token	tSEC_UNIT tSNUMBER tUNUMBER tZONE
X
X%type	<Number>	tDAY tDAYZONE tMINUTE_UNIT tMONTH tMONTH_UNIT
X%type	<Number>	tSEC_UNIT tSNUMBER tUNUMBER tZONE
X%type	<Meridian>	tMERIDIAN o_merid
X
X%%
X
Xspec	: /* NULL */
X	| spec item
X	;
X
Xitem	: time {
X	    yyHaveTime++;
X	}
X	| zone {
X	    yyHaveZone++;
X	}
X	| date {
X	    yyHaveDate++;
X	}
X	| day {
X	    yyHaveDay++;
X	}
X	| rel {
X	    yyHaveRel++;
X	}
X	| number
X	;
X
Xtime	: tUNUMBER tMERIDIAN {
X	    yyHour = $1;
X	    yyMinutes = 0;
X	    yySeconds = 0;
X	    yyMeridian = $2;
X	}
X	| tUNUMBER ':' tUNUMBER o_merid {
X	    yyHour = $1;
X	    yyMinutes = $3;
X	    yySeconds = 0;
X	    yyMeridian = $4;
X	}
X	| tUNUMBER ':' tUNUMBER tSNUMBER {
X	    yyHour = $1;
X	    yyMinutes = $3;
X	    yyMeridian = MER24;
X	    yyDSTmode = DSToff;
X	    yyTimezone = - ($4 % 100 + ($4 / 100) * 60);
X	}
X	| tUNUMBER ':' tUNUMBER ':' tUNUMBER o_merid {
X	    yyHour = $1;
X	    yyMinutes = $3;
X	    yySeconds = $5;
X	    yyMeridian = $6;
X	}
X	| tUNUMBER ':' tUNUMBER ':' tUNUMBER tSNUMBER {
X	    yyHour = $1;
X	    yyMinutes = $3;
X	    yySeconds = $5;
X	    yyMeridian = MER24;
X	    yyDSTmode = DSToff;
X	    yyTimezone = - ($6 % 100 + ($6 / 100) * 60);
X	}
X	;
X
Xzone	: tZONE {
X	    yyTimezone = $1;
X	    yyDSTmode = DSToff;
X	}
X	| tDAYZONE {
X	    yyTimezone = $1;
X	    yyDSTmode = DSTon;
X	}
X	;
X
Xday	: tDAY {
X	    yyDayOrdinal = 1;
X	    yyDayNumber = $1;
X	}
X	| tDAY ',' {
X	    yyDayOrdinal = 1;
X	    yyDayNumber = $1;
X	}
X	| tUNUMBER tDAY {
X	    yyDayOrdinal = $1;
X	    yyDayNumber = $2;
X	}
X	;
X
Xdate	: tUNUMBER '/' tUNUMBER {
X	    yyMonth = $1;
X	    yyDay = $3;
X	}
X	| tUNUMBER '/' tUNUMBER '/' tUNUMBER {
X	    yyMonth = $1;
X	    yyDay = $3;
X	    yyYear = $5;
X	}
X	| tMONTH tUNUMBER {
X	    yyMonth = $1;
X	    yyDay = $2;
X	}
X	| tMONTH tUNUMBER ',' tUNUMBER {
X	    yyMonth = $1;
X	    yyDay = $2;
X	    yyYear = $4;
X	}
X	| tUNUMBER tMONTH {
X	    yyMonth = $2;
X	    yyDay = $1;
X	}
X	| tUNUMBER tMONTH tUNUMBER {
X	    yyMonth = $2;
X	    yyDay = $1;
X	    yyYear = $3;
X	}
X	;
X
Xrel	: relunit tAGO {
X	    yyRelSeconds = -yyRelSeconds;
X	    yyRelMonth = -yyRelMonth;
X	}
X	| relunit
X	;
X
Xrelunit	: tUNUMBER tMINUTE_UNIT {
X	    yyRelSeconds += $1 * $2 * 60L;
X	}
X	| tSNUMBER tMINUTE_UNIT {
X	    yyRelSeconds += $1 * $2 * 60L;
X	}
X	| tMINUTE_UNIT {
X	    yyRelSeconds += $1 * 60L;
X	}
X	| tSNUMBER tSEC_UNIT {
X	    yyRelSeconds += $1;
X	}
X	| tUNUMBER tSEC_UNIT {
X	    yyRelSeconds += $1;
X	}
X	| tSEC_UNIT {
X	    yyRelSeconds++;
X	}
X	| tSNUMBER tMONTH_UNIT {
X	    yyRelMonth += $1 * $2;
X	}
X	| tUNUMBER tMONTH_UNIT {
X	    yyRelMonth += $1 * $2;
X	}
X	| tMONTH_UNIT {
X	    yyRelMonth += $1;
X	}
X	;
X
Xnumber	: tUNUMBER {
X	    if (yyHaveTime && yyHaveDate && !yyHaveRel)
X		yyYear = $1;
X	    else {
X		if($1>10000) {
X		    time_t date_part;
X
X		    date_part= $1/10000;
X		    yyHaveDate++;
X		    yyDay= (date_part)%100;
X		    yyMonth= (date_part/100)%100;
X		    yyYear = date_part/10000;
X		} 
X	        yyHaveTime++;
X		if ($1 < 100) {
X		    yyHour = $1;
X		    yyMinutes = 0;
X		}
X		else {
X		    yyHour = $1 / 100;
X		    yyMinutes = $1 % 100;
X		}
X		yySeconds = 0;
X		yyMeridian = MER24;
X	    }
X	}
X	;
X
Xo_merid	: /* NULL */ {
X	    $$ = MER24;
X	}
X	| tMERIDIAN {
X	    $$ = $1;
X	}
X	;
X
X%%
X
X/* Month and day table. */
Xstatic TABLE	MonthDayTable[] = {
X    { "january",	tMONTH,  1 },
X    { "february",	tMONTH,  2 },
X    { "march",		tMONTH,  3 },
X    { "april",		tMONTH,  4 },
X    { "may",		tMONTH,  5 },
X    { "june",		tMONTH,  6 },
X    { "july",		tMONTH,  7 },
X    { "august",		tMONTH,  8 },
X    { "september",	tMONTH,  9 },
X    { "sept",		tMONTH,  9 },
X    { "october",	tMONTH, 10 },
X    { "november",	tMONTH, 11 },
X    { "december",	tMONTH, 12 },
X    { "sunday",		tDAY, 0 },
X    { "monday",		tDAY, 1 },
X    { "tuesday",	tDAY, 2 },
X    { "tues",		tDAY, 2 },
X    { "wednesday",	tDAY, 3 },
X    { "wednes",		tDAY, 3 },
X    { "thursday",	tDAY, 4 },
X    { "thur",		tDAY, 4 },
X    { "thurs",		tDAY, 4 },
X    { "friday",		tDAY, 5 },
X    { "saturday",	tDAY, 6 },
X    { NULL }
X};
X
X/* Time units table. */
Xstatic TABLE	UnitsTable[] = {
X    { "year",		tMONTH_UNIT,	12 },
X    { "month",		tMONTH_UNIT,	1 },
X    { "fortnight",	tMINUTE_UNIT,	14 * 24 * 60 },
X    { "week",		tMINUTE_UNIT,	7 * 24 * 60 },
X    { "day",		tMINUTE_UNIT,	1 * 24 * 60 },
X    { "hour",		tMINUTE_UNIT,	60 },
X    { "minute",		tMINUTE_UNIT,	1 },
X    { "min",		tMINUTE_UNIT,	1 },
X    { "second",		tSEC_UNIT,	1 },
X    { "sec",		tSEC_UNIT,	1 },
X    { NULL }
X};
X
X/* Assorted relative-time words. */
Xstatic TABLE	OtherTable[] = {
X    { "tomorrow",	tMINUTE_UNIT,	1 * 24 * 60 },
X    { "yesterday",	tMINUTE_UNIT,	-1 * 24 * 60 },
X    { "today",		tMINUTE_UNIT,	0 },
X    { "now",		tMINUTE_UNIT,	0 },
X    { "last",		tUNUMBER,	-1 },
X    { "this",		tMINUTE_UNIT,	0 },
X    { "next",		tUNUMBER,	2 },
X    { "first",		tUNUMBER,	1 },
X/*  { "second",		tUNUMBER,	2 }, */
X    { "third",		tUNUMBER,	3 },
X    { "fourth",		tUNUMBER,	4 },
X    { "fifth",		tUNUMBER,	5 },
X    { "sixth",		tUNUMBER,	6 },
X    { "seventh",	tUNUMBER,	7 },
X    { "eighth",		tUNUMBER,	8 },
X    { "ninth",		tUNUMBER,	9 },
X    { "tenth",		tUNUMBER,	10 },
X    { "eleventh",	tUNUMBER,	11 },
X    { "twelfth",	tUNUMBER,	12 },
X    { "ago",		tAGO,	1 },
X    { NULL }
X};
X
X/* The timezone table. */
Xstatic TABLE	TimezoneTable[] = {
X    { "gmt",	tZONE,     HOUR( 0) },	/* Greenwich Mean */
X    { "ut",	tZONE,     HOUR( 0) },	/* Universal (Coordinated) */
X    { "utc",	tZONE,     HOUR( 0) },
X    { "wet",	tZONE,     HOUR( 0) },	/* Western European */
X    { "bst",	tDAYZONE,  HOUR( 0) },	/* British Summer */
X    { "wat",	tZONE,     HOUR( 1) },	/* West Africa */
X    { "at",	tZONE,     HOUR( 2) },	/* Azores */
X#if	0
X    /* For completeness.  BST is also British Summer, and GST is
X     * also Guam Standard. */
X    { "bst",	tZONE,     HOUR( 3) },	/* Brazil Standard */
X    { "gst",	tZONE,     HOUR( 3) },	/* Greenland Standard */
X#endif
X    { "nft",	tZONE,     HOUR(3.5) },	/* Newfoundland */
X    { "nst",	tZONE,     HOUR(3.5) },	/* Newfoundland Standard */
X    { "ndt",	tDAYZONE,  HOUR(3.5) },	/* Newfoundland Daylight */
X    { "ast",	tZONE,     HOUR( 4) },	/* Atlantic Standard */
X    { "adt",	tDAYZONE,  HOUR( 4) },	/* Atlantic Daylight */
X    { "est",	tZONE,     HOUR( 5) },	/* Eastern Standard */
X    { "edt",	tDAYZONE,  HOUR( 5) },	/* Eastern Daylight */
X    { "cst",	tZONE,     HOUR( 6) },	/* Central Standard */
X    { "cdt",	tDAYZONE,  HOUR( 6) },	/* Central Daylight */
X    { "mst",	tZONE,     HOUR( 7) },	/* Mountain Standard */
X    { "mdt",	tDAYZONE,  HOUR( 7) },	/* Mountain Daylight */
X    { "pst",	tZONE,     HOUR( 8) },	/* Pacific Standard */
X    { "pdt",	tDAYZONE,  HOUR( 8) },	/* Pacific Daylight */
X    { "yst",	tZONE,     HOUR( 9) },	/* Yukon Standard */
X    { "ydt",	tDAYZONE,  HOUR( 9) },	/* Yukon Daylight */
X    { "hst",	tZONE,     HOUR(10) },	/* Hawaii Standard */
X    { "hdt",	tDAYZONE,  HOUR(10) },	/* Hawaii Daylight */
X    { "cat",	tZONE,     HOUR(10) },	/* Central Alaska */
X    { "ahst",	tZONE,     HOUR(10) },	/* Alaska-Hawaii Standard */
X    { "nt",	tZONE,     HOUR(11) },	/* Nome */
X    { "idlw",	tZONE,     HOUR(12) },	/* International Date Line West */
X    { "cet",	tZONE,     -HOUR(1) },	/* Central European */
X    { "met",	tZONE,     -HOUR(1) },	/* Middle European */
X    { "mewt",	tZONE,     -HOUR(1) },	/* Middle European Winter */
X    { "mest",	tDAYZONE,  -HOUR(1) },	/* Middle European Summer */
X    { "swt",	tZONE,     -HOUR(1) },	/* Swedish Winter */
X    { "sst",	tDAYZONE,  -HOUR(1) },	/* Swedish Summer */
X    { "fwt",	tZONE,     -HOUR(1) },	/* French Winter */
X    { "fst",	tDAYZONE,  -HOUR(1) },	/* French Summer */
X    { "eet",	tZONE,     -HOUR(2) },	/* Eastern Europe, USSR Zone 1 */
X    { "bt",	tZONE,     -HOUR(3) },	/* Baghdad, USSR Zone 2 */
X    { "it",	tZONE,     -HOUR(3.5) },/* Iran */
X    { "zp4",	tZONE,     -HOUR(4) },	/* USSR Zone 3 */
X    { "zp5",	tZONE,     -HOUR(5) },	/* USSR Zone 4 */
X    { "ist",	tZONE,     -HOUR(5.5) },/* Indian Standard */
X    { "zp6",	tZONE,     -HOUR(6) },	/* USSR Zone 5 */
X#if	0
X    /* For completeness.  NST is also Newfoundland Stanard, nad SST is
X     * also Swedish Summer. */
X    { "nst",	tZONE,     -HOUR(6.5) },/* North Sumatra */
X    { "sst",	tZONE,     -HOUR(7) },	/* South Sumatra, USSR Zone 6 */
X#endif	/* 0 */
X    { "wast",	tZONE,     -HOUR(7) },	/* West Australian Standard */
X    { "wadt",	tDAYZONE,  -HOUR(7) },	/* West Australian Daylight */
X    { "jt",	tZONE,     -HOUR(7.5) },/* Java (3pm in Cronusland!) */
X    { "cct",	tZONE,     -HOUR(8) },	/* China Coast, USSR Zone 7 */
X    { "jst",	tZONE,     -HOUR(9) },	/* Japan Standard, USSR Zone 8 */
X    { "cast",	tZONE,     -HOUR(9.5) },/* Central Australian Standard */
X    { "cadt",	tDAYZONE,  -HOUR(9.5) },/* Central Australian Daylight */
X    { "east",	tZONE,     -HOUR(10) },	/* Eastern Australian Standard */
X    { "eadt",	tDAYZONE,  -HOUR(10) },	/* Eastern Australian Daylight */
X    { "gst",	tZONE,     -HOUR(10) },	/* Guam Standard, USSR Zone 9 */
X    { "nzt",	tZONE,     -HOUR(12) },	/* New Zealand */
X    { "nzst",	tZONE,     -HOUR(12) },	/* New Zealand Standard */
X    { "nzdt",	tDAYZONE,  -HOUR(12) },	/* New Zealand Daylight */
X    { "idle",	tZONE,     -HOUR(12) },	/* International Date Line East */
X    {  NULL  }
X};
X
X/* Military timezone table. */
Xstatic TABLE	MilitaryTable[] = {
X    { "a",	tZONE,	HOUR(  1) },
X    { "b",	tZONE,	HOUR(  2) },
X    { "c",	tZONE,	HOUR(  3) },
X    { "d",	tZONE,	HOUR(  4) },
X    { "e",	tZONE,	HOUR(  5) },
X    { "f",	tZONE,	HOUR(  6) },
X    { "g",	tZONE,	HOUR(  7) },
X    { "h",	tZONE,	HOUR(  8) },
X    { "i",	tZONE,	HOUR(  9) },
X    { "k",	tZONE,	HOUR( 10) },
X    { "l",	tZONE,	HOUR( 11) },
X    { "m",	tZONE,	HOUR( 12) },
X    { "n",	tZONE,	HOUR(- 1) },
X    { "o",	tZONE,	HOUR(- 2) },
X    { "p",	tZONE,	HOUR(- 3) },
X    { "q",	tZONE,	HOUR(- 4) },
X    { "r",	tZONE,	HOUR(- 5) },
X    { "s",	tZONE,	HOUR(- 6) },
X    { "t",	tZONE,	HOUR(- 7) },
X    { "u",	tZONE,	HOUR(- 8) },
X    { "v",	tZONE,	HOUR(- 9) },
X    { "w",	tZONE,	HOUR(-10) },
X    { "x",	tZONE,	HOUR(-11) },
X    { "y",	tZONE,	HOUR(-12) },
X    { "z",	tZONE,	HOUR(  0) },
X    { NULL }
X};
X
X
X
X
X/* ARGSUSED */
Xint
Xyyerror(s)
X    char	*s;
X{
X  return 0;
X}
X
X
Xstatic time_t
XToSeconds(Hours, Minutes, Seconds, Meridian)
X    time_t	Hours;
X    time_t	Minutes;
X    time_t	Seconds;
X    MERIDIAN	Meridian;
X{
X    if (Minutes < 0 || Minutes > 59 || Seconds < 0 || Seconds > 59)
X	return -1;
X    switch (Meridian) {
X    case MER24:
X	if (Hours < 0 || Hours > 23)
X	    return -1;
X	return (Hours * 60L + Minutes) * 60L + Seconds;
X    case MERam:
X	if (Hours < 1 || Hours > 12)
X	    return -1;
X	return (Hours * 60L + Minutes) * 60L + Seconds;
X    case MERpm:
X	if (Hours < 1 || Hours > 12)
X	    return -1;
X	return ((Hours + 12) * 60L + Minutes) * 60L + Seconds;
X    }
X    /* NOTREACHED */
X}
X
X
Xstatic time_t
XConvert(Month, Day, Year, Hours, Minutes, Seconds, Meridian, DSTmode)
X    time_t	Month;
X    time_t	Day;
X    time_t	Year;
X    time_t	Hours;
X    time_t	Minutes;
X    time_t	Seconds;
X    MERIDIAN	Meridian;
X    DSTMODE	DSTmode;
X{
X    static int	DaysInMonth[12] = {
X	31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
X    };
X    time_t	tod;
X    time_t	Julian;
X    int		i;
X
X    if (Year < 0)
X	Year = -Year;
X    if (Year < 100)
X	Year += 1900;
X    DaysInMonth[1] = Year % 4 == 0 && (Year % 100 != 0 || Year % 400 == 0)
X		    ? 29 : 28;
X    if (Year < EPOCH || Year > 1999
X     || Month < 1 || Month > 12
X     /* Lint fluff:  "conversion from long may lose accuracy" */
X     || Day < 1 || Day > DaysInMonth[(int)--Month])
X	return -1;
X
X    for (Julian = Day - 1, i = 0; i < Month; i++)
X	Julian += DaysInMonth[i];
X    for (i = EPOCH; i < Year; i++)
X	Julian += 365 + (i % 4 == 0);
X    Julian *= SECSPERDAY;
X    Julian += yyTimezone * 60L;
X    if ((tod = ToSeconds(Hours, Minutes, Seconds, Meridian)) < 0)
X	return -1;
X    Julian += tod;
X    if (DSTmode == DSTon
X     || (DSTmode == DSTmaybe && localtime(&Julian)->tm_isdst))
X	Julian -= 60 * 60;
X    return Julian;
X}
X
X
Xstatic time_t
XDSTcorrect(Start, Future)
X    time_t	Start;
X    time_t	Future;
X{
X    time_t	StartDay;
X    time_t	FutureDay;
X
X    StartDay = (localtime(&Start)->tm_hour + 1) % 24;
X    FutureDay = (localtime(&Future)->tm_hour + 1) % 24;
X    return (Future - Start) + (StartDay - FutureDay) * 60L * 60L;
X}
X
X
Xstatic time_t
XRelativeDate(Start, DayOrdinal, DayNumber)
X    time_t	Start;
X    time_t	DayOrdinal;
X    time_t	DayNumber;
X{
X    struct tm	*tm;
X    time_t	now;
X
X    now = Start;
X    tm = localtime(&now);
X    now += SECSPERDAY * ((DayNumber - tm->tm_wday + 7) % 7);
X    now += 7 * SECSPERDAY * (DayOrdinal <= 0 ? DayOrdinal : DayOrdinal - 1);
X    return DSTcorrect(Start, now);
X}
X
X
Xstatic time_t
XRelativeMonth(Start, RelMonth)
X    time_t	Start;
X    time_t	RelMonth;
X{
X    struct tm	*tm;
X    time_t	Month;
X    time_t	Year;
X
X    if (RelMonth == 0)
X	return 0;
X    tm = localtime(&Start);
X    Month = 12 * tm->tm_year + tm->tm_mon + RelMonth;
X    Year = Month / 12;
X    Month = Month % 12 + 1;
X    return DSTcorrect(Start,
X	    Convert(Month, (time_t)tm->tm_mday, Year,
X		(time_t)tm->tm_hour, (time_t)tm->tm_min, (time_t)tm->tm_sec,
X		MER24, DSTmaybe));
X}
X
X
Xstatic int
XLookupWord(buff)
X    char		*buff;
X{
X    register char	*p;
X    register char	*q;
X    register TABLE	*tp;
X    int			i;
X    int			abbrev;
X
X    /* Make it lowercase. */
X    for (p = buff; *p; p++)
X	if (isupper(*p))
X	    *p = tolower(*p);
X
X    if (strcmp(buff, "am") == 0 || strcmp(buff, "a.m.") == 0) {
X	yylval.Meridian = MERam;
X	return tMERIDIAN;
X    }
X    if (strcmp(buff, "pm") == 0 || strcmp(buff, "p.m.") == 0) {
X	yylval.Meridian = MERpm;
X	return tMERIDIAN;
X    }
X
X    /* See if we have an abbreviation for a month. */
X    if (strlen(buff) == 3)
X	abbrev = 1;
X    else if (strlen(buff) == 4 && buff[3] == '.') {
X	abbrev = 1;
X	buff[3] = '\0';
X    }
X    else
X	abbrev = 0;
X
X    for (tp = MonthDayTable; tp->name; tp++) {
X	if (abbrev) {
X	    if (strncmp(buff, tp->name, 3) == 0) {
X		yylval.Number = tp->value;
X		return tp->type;
X	    }
X	}
X	else if (strcmp(buff, tp->name) == 0) {
X	    yylval.Number = tp->value;
X	    return tp->type;
X	}
X    }
X
X    for (tp = TimezoneTable; tp->name; tp++)
X	if (strcmp(buff, tp->name) == 0) {
X	    yylval.Number = tp->value;
X	    return tp->type;
X	}
X
X    for (tp = UnitsTable; tp->name; tp++)
X	if (strcmp(buff, tp->name) == 0) {
X	    yylval.Number = tp->value;
X	    return tp->type;
X	}
X
X    /* Strip off any plural and try the units table again. */
X    i = strlen(buff) - 1;
X    if (buff[i] == 's') {
X	buff[i] = '\0';
X	for (tp = UnitsTable; tp->name; tp++)
X	    if (strcmp(buff, tp->name) == 0) {
X		yylval.Number = tp->value;
X		return tp->type;
X	    }
X	buff[i] = 's';		/* Put back for "this" in OtherTable. */
X    }
X
X    for (tp = OtherTable; tp->name; tp++)
X	if (strcmp(buff, tp->name) == 0) {
X	    yylval.Number = tp->value;
X	    return tp->type;
X	}
X
X    /* Military timezones. */
X    if (buff[1] == '\0' && isalpha(*buff)) {
X	for (tp = MilitaryTable; tp->name; tp++)
X	    if (strcmp(buff, tp->name) == 0) {
X		yylval.Number = tp->value;
X		return tp->type;
X	    }
X    }
X
X    /* Drop out any periods and try the timezone table again. */
X    for (i = 0, p = q = buff; *q; q++)
X	if (*q != '.')
X	    *p++ = *q;
X	else
X	    i++;
X    *p = '\0';
X    if (i)
X	for (tp = TimezoneTable; tp->name; tp++)
X	    if (strcmp(buff, tp->name) == 0) {
X		yylval.Number = tp->value;
X		return tp->type;
X	    }
X
X    return tID;
X}
X
X
Xint
Xyylex()
X{
X    register char	c;
X    register char	*p;
X    char		buff[20];
X    int			Count;
X    int			sign;
X
X    for ( ; ; ) {
X	while (isspace(*yyInput))
X	    yyInput++;
X
X	if (isdigit(c = *yyInput) || c == '-' || c == '+') {
X	    if (c == '-' || c == '+') {
X		sign = c == '-' ? -1 : 1;
X		if (!isdigit(*++yyInput))
X		    /* skip the '-' sign */
X		    continue;
X	    }
X	    else
X		sign = 0;
X	    for (yylval.Number = 0; isdigit(c = *yyInput++); )
X		yylval.Number = 10 * yylval.Number + c - '0';
X	    yyInput--;
X	    if (sign < 0)
X		yylval.Number = -yylval.Number;
X	    return sign ? tSNUMBER : tUNUMBER;
X	}
X	if (isalpha(c)) {
X	    for (p = buff; isalpha(c = *yyInput++) || c == '.'; )
X		if (p < &buff[sizeof buff - 1])
X		    *p++ = c;
X	    *p = '\0';
X	    yyInput--;
X	    return LookupWord(buff);
X	}
X	if (c != '(')
X	    return *yyInput++;
X	Count = 0;
X	do {
X	    c = *yyInput++;
X	    if (c == '\0')
X		return c;
X	    if (c == '(')
X		Count++;
X	    else if (c == ')')
X		Count--;
X	} while (Count > 0);
X    }
X}
X
X
Xtime_t
Xget_date(p, now)
X    char		*p;
X    struct timeb	*now;
X{
X    struct tm		*tm;
X    struct timeb	ftz;
X    time_t		Start;
X    time_t		tod;
X
X    yyInput = p;
X    if (now == NULL) {
X	now = &ftz;
X#if	defined(NEED_TZSET)
X	(void)time(&ftz.time);
X	/* Set the timezone global. */
X	tzset();
X	ftz.timezone = (int) timezone / 60;
X#else
X	(void)ftime(&ftz);
X#endif	/* defined(NEED_TZSET) */
X    }
X
X    tm = localtime(&now->time);
X    yyYear = tm->tm_year;
X    yyMonth = tm->tm_mon + 1;
X    yyDay = tm->tm_mday;
X    yyTimezone = now->timezone;
X    yyDSTmode = DSTmaybe;
X    yyHour = 0;
X    yyMinutes = 0;
X    yySeconds = 0;
X    yyMeridian = MER24;
X    yyRelSeconds = 0;
X    yyRelMonth = 0;
X    yyHaveDate = 0;
X    yyHaveDay = 0;
X    yyHaveRel = 0;
X    yyHaveTime = 0;
X    yyHaveZone = 0;
X
X    if (yyparse()
X     || yyHaveTime > 1 || yyHaveZone > 1 || yyHaveDate > 1 || yyHaveDay > 1)
X	return -1;
X
X    if (yyHaveDate || yyHaveTime || yyHaveDay) {
X	Start = Convert(yyMonth, yyDay, yyYear, yyHour, yyMinutes, yySeconds,
X		    yyMeridian, yyDSTmode);
X	if (Start < 0)
X	    return -1;
X    }
X    else {
X	Start = now->time;
X	if (!yyHaveRel)
X	    Start -= ((tm->tm_hour * 60L + tm->tm_min) * 60L) + tm->tm_sec;
X    }
X
X    Start += yyRelSeconds;
X    Start += RelativeMonth(Start, yyRelMonth);
X
X    if (yyHaveDay && !yyHaveDate) {
X	tod = RelativeDate(Start, yyDayOrdinal, yyDayNumber);
X	Start += tod;
X    }
X
X    /* Have to do *something* with a legitimate -1 so it's distinguishable
X     * from the error return value.  (Alternately could set errno on error.) */
X    return Start == -1 ? 0 : Start;
X}
X
X
X#if	defined(TEST)
X
X/* ARGSUSED */
Xmain(ac, av)
X    int		ac;
X    char	*av[];
X{
X    char	buff[128];
X    time_t	d;
X
X    (void)printf("Enter date, or blank line to exit.\n\t> ");
X    (void)fflush(stdout);
X    while (gets(buff) && buff[0]) {
X	d = get_date(buff, (struct timeb *)NULL);
X	if (d == -1)
X	    (void)printf("Bad format - couldn't convert.\n");
X	else
X	    (void)printf("%s", ctime(&d));
X	(void)printf("\t> ");
X	(void)fflush(stdout);
X    }
X    exit(0);
X    /* NOTREACHED */
X}
X#endif	/* defined(TEST) */
END_OF_FILE
if test 21433 -ne `wc -c <'getdate.y'`; then
    echo shar: \"'getdate.y'\" unpacked with wrong size!
fi
# end of 'getdate.y'
fi
if test -f 'getopt.h' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'getopt.h'\"
else
echo shar: Extracting \"'getopt.h'\" \(3560 characters\)
sed "s/^X//" >'getopt.h' <<'END_OF_FILE'
X/* declarations for getopt
X   Copyright (C) 1989, 1990, 1991 Free Software Foundation, Inc.
X
X   This program is free software; you can redistribute it and/or modify
X   it under the terms of the GNU General Public License as published by
X   the Free Software Foundation; either version 2, or (at your option)
X   any later version.
X
X   This program is distributed in the hope that it will be useful,
X   but WITHOUT ANY WARRANTY; without even the implied warranty of
X   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
X   GNU General Public License for more details.
X
X   You should have received a copy of the GNU General Public License
X   along with this program; if not, write to the Free Software
X   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X/* For communication from `getopt' to the caller.
X   When `getopt' finds an option that takes an argument,
X   the argument value is returned here.
X   Also, when `ordering' is RETURN_IN_ORDER,
X   each non-option ARGV-element is returned here.  */
X
Xextern char *optarg;
X
X/* Index in ARGV of the next element to be scanned.
X   This is used for communication to and from the caller
X   and for communication between successive calls to `getopt'.
X
X   On entry to `getopt', zero means this is the first call; initialize.
X
X   When `getopt' returns EOF, this is the index of the first of the
X   non-option elements that the caller should itself scan.
X
X   Otherwise, `optind' communicates from one call to the next
X   how much of ARGV has been scanned so far.  */
X
Xextern int optind;
X
X/* Callers store zero here to inhibit the error message `getopt' prints
X   for unrecognized options.  */
X
Xextern int opterr;
X
X/* Describe the long-named options requested by the application.
X   _GETOPT_LONG_OPTIONS is a vector of `struct option' terminated by an
X   element containing a name which is zero.
X
X   The field `has_arg' is:
X   0 if the option does not take an argument,
X   1 if the option requires an argument,
X   2 if the option takes an optional argument.
X
X   If the field `flag' is nonzero, it points to a variable that is set
X   to the value given in the field `val' when the option is found, but
X   left unchanged if the option is not found.
X
X   To have a long-named option do something other than set an `int' to
X   a compiled-in constant, such as set a value from `optarg', set the
X   option's `flag' field to zero and its `val' field to a nonzero
X   value (the equivalent single-letter option character, if there is
X   one).  For long options that have a zero `flag' field, `getopt'
X   returns the contents of the `val' field.  */
X
Xstruct option
X{
X  char *name;
X  int has_arg;
X  int *flag;
X  int val;
X};
X
X#ifdef __STDC__
Xextern const struct option *_getopt_long_options;
X#else
Xextern struct option *_getopt_long_options;
X#endif
X
X/* If nonzero, '-' can introduce long-named options.
X   Set by getopt_long_only.  */
X
Xextern int _getopt_long_only;
X
X/* The index in GETOPT_LONG_OPTIONS of the long-named option found.
X   Only valid when a long-named option has been found by the most
X   recent call to `getopt'.  */
X
Xextern int option_index;
X
X#ifdef __STDC__
Xint getopt (int argc, char **argv, const char *shortopts);
Xint getopt_long (int argc, char **argv, const char *shortopts,
X		 const struct option *longopts, int *longind);
Xint getopt_long_only (int argc, char **argv, const char *shortopts,
X		      const struct option *longopts, int *longind);
Xvoid envopt(int *pargc, char ***pargv, char *optstr);
X#else
Xint getopt ();
Xint getopt_long ();
Xint getopt_long_only ();
Xvoid envopt();
X#endif
END_OF_FILE
if test 3560 -ne `wc -c <'getopt.h'`; then
    echo shar: \"'getopt.h'\" unpacked with wrong size!
fi
# end of 'getopt.h'
fi
if test -f 'regex.h' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'regex.h'\"
else
echo shar: Extracting \"'regex.h'\" \(9584 characters\)
sed "s/^X//" >'regex.h' <<'END_OF_FILE'
X/* Definitions for data structures callers pass the regex library.
X
X   Copyright (C) 1985, 1989-90 Free Software Foundation, Inc.
X
X   This program is free software; you can redistribute it and/or modify
X   it under the terms of the GNU General Public License as published by
X   the Free Software Foundation; either version 2, or (at your option)
X   any later version.
X
X   This program is distributed in the hope that it will be useful,
X   but WITHOUT ANY WARRANTY; without even the implied warranty of
X   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
X   GNU General Public License for more details.
X
X   You should have received a copy of the GNU General Public License
X   along with this program; if not, write to the Free Software
X   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.  */
X
X
X#ifdef __GNUC__
X  #pragma once
X#endif
X
X#ifndef __REGEXP_LIBRARY
X#define __REGEXP_LIBRARY
X
X/* Define number of parens for which we record the beginnings and ends.
X   This affects how much space the `struct re_registers' type takes up.  */
X#ifndef RE_NREGS
X#define RE_NREGS 10
X#endif
X
X#define BYTEWIDTH 8
X
X
X/* Maximum number of duplicates an interval can allow.  */
X#define RE_DUP_MAX  ((1 << 15) - 1) 
X
X
X/* This defines the various regexp syntaxes.  */
Xextern int obscure_syntax;
X
X
X/* The following bits are used in the obscure_syntax variable to choose among
X   alternative regexp syntaxes.  */
X
X/* If this bit is set, plain parentheses serve as grouping, and backslash
X     parentheses are needed for literal searching.
X   If not set, backslash-parentheses are grouping, and plain parentheses
X     are for literal searching.  */
X#define RE_NO_BK_PARENS	1
X
X/* If this bit is set, plain | serves as the `or'-operator, and \| is a 
X     literal.
X   If not set, \| serves as the `or'-operator, and | is a literal.  */
X#define RE_NO_BK_VBAR (1 << 1)
X
X/* If this bit is not set, plain + or ? serves as an operator, and \+, \? are 
X     literals.
X   If set, \+, \? are operators and plain +, ? are literals.  */
X#define RE_BK_PLUS_QM (1 << 2)
X
X/* If this bit is set, | binds tighter than ^ or $.
X   If not set, the contrary.  */
X#define RE_TIGHT_VBAR (1 << 3)
X
X/* If this bit is set, then treat newline as an OR operator.
X   If not set, treat it as a normal character.  */
X#define RE_NEWLINE_OR (1 << 4)
X
X/* If this bit is set, then special characters may act as normal
X   characters in some contexts. Specifically, this applies to:
X	^ -- only special at the beginning, or after ( or |;
X	$ -- only special at the end, or before ) or |;
X	*, +, ? -- only special when not after the beginning, (, or |.
X   If this bit is not set, special characters (such as *, ^, and $)
X   always have their special meaning regardless of the surrounding
X   context.  */
X#define RE_CONTEXT_INDEP_OPS (1 << 5)
X
X/* If this bit is not set, then \ before anything inside [ and ] is taken as 
X     a real \.
X   If set, then such a \ escapes the following character.  This is a
X     special case for awk.  */
X#define RE_AWK_CLASS_HACK (1 << 6)
X
X/* If this bit is set, then \{ and \} or { and } serve as interval operators.
X   If not set, then \{ and \} and { and } are treated as literals.  */
X#define RE_INTERVALS (1 << 7)
X
X/* If this bit is not set, then \{ and \} serve as interval operators and 
X     { and } are literals.
X   If set, then { and } serve as interval operators and \{ and \} are 
X     literals.  */
X#define RE_NO_BK_CURLY_BRACES (1 << 8)
X
X/* If this bit is set, then character classes are supported; they are:
X     [:alpha:],	[:upper:], [:lower:],  [:digit:], [:alnum:], [:xdigit:],
X     [:space:], [:print:], [:punct:], [:graph:], and [:cntrl:].
X   If not set, then character classes are not supported.  */
X#define RE_CHAR_CLASSES (1 << 9)
X
X/* If this bit is set, then the dot re doesn't match a null byte.
X   If not set, it does.  */
X#define RE_DOT_NOT_NULL (1 << 10)
X
X/* If this bit is set, then [^...] doesn't match a newline.
X   If not set, it does.  */
X#define RE_HAT_NOT_NEWLINE (1 << 11)
X
X/* If this bit is set, back references are recognized.
X   If not set, they aren't.  */
X#define RE_NO_BK_REFS (1 << 12)
X
X/* If this bit is set, back references must refer to a preceding
X   subexpression.  If not set, a back reference to a nonexistent
X   subexpression is treated as literal characters.  */
X#define RE_NO_EMPTY_BK_REF (1 << 13)
X
X/* If this bit is set, bracket expressions can't be empty.  
X   If it is set, they can be empty.  */
X#define RE_NO_EMPTY_BRACKETS (1 << 14)
X
X/* If this bit is set, then *, +, ? and { cannot be first in an re or
X   immediately after a |, or a (.  Furthermore, a | cannot be first or
X   last in an re, or immediately follow another | or a (.  Also, a ^
X   cannot appear in a nonleading position and a $ cannot appear in a
X   nontrailing position (outside of bracket expressions, that is).  */
X#define RE_CONTEXTUAL_INVALID_OPS (1 << 15)
X
X/* If this bit is set, then +, ? and | aren't recognized as operators.
X   If it's not, they are.  */
X#define RE_LIMITED_OPS (1 << 16)
X
X/* If this bit is set, then an ending range point has to collate higher
X     or equal to the starting range point.
X   If it's not set, then when the ending range point collates higher
X     than the starting range point, the range is just considered empty.  */
X#define RE_NO_EMPTY_RANGES (1 << 17)
X
X/* If this bit is set, then a hyphen (-) can't be an ending range point.
X   If it isn't, then it can.  */
X#define RE_NO_HYPHEN_RANGE_END (1 << 18)
X
X
X/* Define combinations of bits for the standard possibilities.  */
X#define RE_SYNTAX_POSIX_AWK (RE_NO_BK_PARENS | RE_NO_BK_VBAR \
X			| RE_CONTEXT_INDEP_OPS)
X#define RE_SYNTAX_AWK (RE_NO_BK_PARENS | RE_NO_BK_VBAR \
X			| RE_CONTEXT_INDEP_OPS | RE_AWK_CLASS_HACK)
X#define RE_SYNTAX_EGREP (RE_NO_BK_PARENS | RE_NO_BK_VBAR \
X			| RE_CONTEXT_INDEP_OPS | RE_NEWLINE_OR)
X#define RE_SYNTAX_GREP (RE_BK_PLUS_QM | RE_NEWLINE_OR)
X#define RE_SYNTAX_EMACS 0
X#define RE_SYNTAX_POSIX_BASIC (RE_INTERVALS | RE_BK_PLUS_QM 		\
X			| RE_CHAR_CLASSES | RE_DOT_NOT_NULL 		\
X                        | RE_HAT_NOT_NEWLINE | RE_NO_EMPTY_BK_REF 	\
X                        | RE_NO_EMPTY_BRACKETS | RE_LIMITED_OPS		\
X                        | RE_NO_EMPTY_RANGES | RE_NO_HYPHEN_RANGE_END)	
X                        
X#define RE_SYNTAX_POSIX_EXTENDED (RE_INTERVALS | RE_NO_BK_CURLY_BRACES	   \
X			| RE_NO_BK_VBAR | RE_NO_BK_PARENS 		   \
X                        | RE_HAT_NOT_NEWLINE | RE_CHAR_CLASSES 		   \
X                        | RE_NO_EMPTY_BRACKETS | RE_CONTEXTUAL_INVALID_OPS \
X                        | RE_NO_BK_REFS | RE_NO_EMPTY_RANGES 		   \
X                        | RE_NO_HYPHEN_RANGE_END)
X
X
X/* This data structure is used to represent a compiled pattern.  */
X
Xstruct re_pattern_buffer
X  {
X    char *buffer;	/* Space holding the compiled pattern commands.  */
X    long allocated;	/* Size of space that `buffer' points to. */
X    long used;		/* Length of portion of buffer actually occupied  */
X    char *fastmap;	/* Pointer to fastmap, if any, or zero if none.  */
X			/* re_search uses the fastmap, if there is one,
X			   to skip over totally implausible characters.  */
X    char *translate;	/* Translate table to apply to all characters before 
X		           comparing, or zero for no translation.
X			   The translation is applied to a pattern when it is 
X                           compiled and to data when it is matched.  */
X    char fastmap_accurate;
X			/* Set to zero when a new pattern is stored,
X			   set to one when the fastmap is updated from it.  */
X    char can_be_null;   /* Set to one by compiling fastmap
X			   if this pattern might match the null string.
X			   It does not necessarily match the null string
X			   in that case, but if this is zero, it cannot.
X			   2 as value means can match null string
X			   but at end of range or before a character
X			   listed in the fastmap.  */
X  };
X
X
X/* search.c (search_buffer) needs this one value.  It is defined both in
X   regex.c and here.  */
X#define RE_EXACTN_VALUE 1
X
X
X/* Structure to store register contents data in.
X
X   Pass the address of such a structure as an argument to re_match, etc.,
X   if you want this information back.
X
X   For i from 1 to RE_NREGS - 1, start[i] records the starting index in
X   the string of where the ith subexpression matched, and end[i] records
X   one after the ending index.  start[0] and end[0] are analogous, for
X   the entire pattern.  */
X
Xstruct re_registers
X  {
X    int start[RE_NREGS];
X    int end[RE_NREGS];
X  };
X
X
X
X#ifdef __STDC__
X
Xextern char *re_compile_pattern (char *, int, struct re_pattern_buffer *);
X/* Is this really advertised?  */
Xextern void re_compile_fastmap (struct re_pattern_buffer *);
Xextern int re_search (struct re_pattern_buffer *, char*, int, int, int,
X		      struct re_registers *);
Xextern int re_search_2 (struct re_pattern_buffer *, char *, int,
X			char *, int, int, int,
X			struct re_registers *, int);
Xextern int re_match (struct re_pattern_buffer *, char *, int, int,
X		     struct re_registers *);
Xextern int re_match_2 (struct re_pattern_buffer *, char *, int,
X		       char *, int, int, struct re_registers *, int);
X
X/* 4.2 bsd compatibility.  */
Xextern char *re_comp (char *);
Xextern int re_exec (char *);
X
X#else /* !__STDC__ */
X
Xextern char *re_compile_pattern ();
X/* Is this really advertised? */
Xextern void re_compile_fastmap ();
Xextern int re_search (), re_search_2 ();
Xextern int re_match (), re_match_2 ();
X
X/* 4.2 bsd compatibility.  */
Xextern char *re_comp ();
Xextern int re_exec ();
X
X#endif /* __STDC__ */
X
X
X#ifdef SYNTAX_TABLE
Xextern char *re_syntax_table;
X#endif
X
X#endif /* !__REGEXP_LIBRARY */
END_OF_FILE
if test 9584 -ne `wc -c <'regex.h'`; then
    echo shar: \"'regex.h'\" unpacked with wrong size!
fi
# end of 'regex.h'
fi
if test -f 'level-0' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'level-0'\"
else
echo shar: Extracting \"'level-0'\" \(4297 characters\)
sed "s/^X//" >'level-0' <<'END_OF_FILE'
X#!/bin/sh
X#
X# Run this script as root on the machine that has the tape drive, to make a
X# full dump.
X#
X# If you give `now' as an argument, the dump is done immediately.
X# Otherwise, it waits until 1am, or until the hour given as argument.
X# Specify the hour as a number from 0 to 23.
X#
X# You must edit the file `backup-specs' to set the parameters for your site.
X
Xif [ ! -w / ]; then
X   echo The backup must be run as root,
X   echo or else some files will fail to be dumped.
X   exit 1
Xelse
X   false
Xfi
X
X# This is undesirable -- rms.
X# rsh albert /usr/local/adm/motd-backup-start
X
X# Get the values of BACKUP_DIRS and BACKUP_FILES, and other variables.
X. ./backup-specs
X
X# Maybe sleep until around specified or default hour.
X#
Xif [ "$1" != "now" ]; then
X   if [ "$1"x != x ]; then
X      spec=$1
X   else
X      spec=$BACKUP_HOUR
X   fi
X   pausetime=`date | awk '{hr=substr($4,1,2);\\
X      mn=substr($4,4,2);\\
X      if((hr+0)<spec)\\
X         print 3600*(spec-hr)-60*mn;\\
X      else\\
X         print 3600*(spec+(24-hr))-60*mn; }' spec=$spec`
X   clear
X   cat ./dont_touch
X   sleep $pausetime
Xfi
X
X# start doing things
X
Xhere=`pwd`
XLOGFILE=log-`date | awk '{print $2 "-" $3 "-" $6}'`-full
XHOST=`hostname | sed 's/\..*//'`
XTAR_PART1="/usr/local/bin/tar -c +multi-volume +one-file-system +block=$BLOCKING +sparse"
X#TAR_PART1="/usr/local/bin/tar -c +multi-volume +one-file-system +block=$BLOCKING "
X
X# Make sure the log file did not already exist.  Create it.
X
Xif [ -f $LOGFILE ] ; then
X   echo Log file $LOGFILE already exists.
X   exit 1
Xelse
X   touch $LOGFILE
Xfi
X
Xmt -f $TAPE_FILE rewind
X
Xset $BACKUP_DIRS
Xwhile [ $# -ne 0 ] ; do
X   host=`echo $1 | sed 's/:.*$//'`
X   fs=`echo $1 | sed 's/^.*://'`
X   date=`date`
X   fsname=`echo $1 | sed 's/\//:/g'`
X
X   TAR_PART2="+listed=/etc/tar-backup/temp.level-0"
X   TAR_PART3="+label='Full backup of $fs on $host at $date' -C $fs ."
X
X   echo Backing up $1 at $date | tee -a $LOGFILE
X
X   # Actually back things up.
X
X   if [ $HOST != $host ] ; then
X      rsh $host "mkdir /etc/tar-backup 2>&1/dev/null; \
X	rm -f /etc/tar-backup/temp.level-0; \
X      	$TAR_PART1 -f $HOST:$TAPE_FILE $TAR_PART2 $TAR_PART3" \
X	 2>&1 | tee -a $LOGFILE
X   else
X      mkdir /etc/tar-backup 2>&1/dev/null
X      rm -f /etc/tar-backup/temp.level-0
X# Using `sh -c exec' causes nested quoting and shell substitution
X# to be handled here in the same way rsh handles it.
X      sh -c "exec $TAR_PART1 -f $TAPE_FILE $TAR_PART2 $TAR_PART3" 2>&1 | tee -a $LOGFILE
X   fi
X   if [ $? -ne 0 ] ; then
X      echo Backup of $1 failed. | tee -a $LOGFILE
X      # I'm assuming that the tar will have written an empty
X      # file to the tape, otherwise I should do a cat here.
X   else
X      if [ $HOST != $host ] ; then
X	rsh $host mv -f /etc/tar-backup/temp.level-0 /etc/tar-backup/$fsname.level-0 2>&1 | tee -a $LOGFILE
X      else
X        mv -f /etc/tar-backup/temp.level-0 /etc/tar-backup/$fsname.level-0 2>&1 | tee -a $LOGFILE
X      fi
X   fi
X   $TAPE_STATUS | tee -a $LOGFILE
X   sleep 60
X   shift
Xdone
X
X# Dump any individual files requested.
X
Xif [ x != "x$BACKUP_FILES" ] ; then
X   date=`date`
X
X   TAR_PART2="+listed=/etc/tar-backup/temp.level-0"
X   TAR_PART3="+label='Full backup of miscellaneous files at $date'"
X
X   mkdir /etc/tar-backup 2>&1/dev/null
X   rm -f /etc/tar-backup/temp.level-0
X
X   echo Backing up miscellaneous files at $date | tee -a $LOGFILE
X# Using `sh -c exec' causes nested quoting and shell substitution
X# to be handled here in the same way rsh handles it.
X   sh -c "exec $TAR_PART1 -f $TAPE_FILE $TAR_PART2 $TAR_PART3 \
X    $BACKUP_FILES" 2>&1 | tee -a $LOGFILE
X   if [ $? -ne 0 ] ; then
X     echo Backup of miscellaneous files failed. | tee -a $LOGFILE
X     # I'm assuming that the tar will have written an empty
X     # file to the tape, otherwise I should do a cat here.
X   else
X     mv -f /etc/tar-backup/temp.level-0 /etc/tar-backup/misc.level-0 2>&1 | tee -a $LOGFILE
X   fi
X   $TAPE_STATUS | tee -a $LOGFILE
Xelse
X   echo No miscellaneous files specified | tee -a $LOGFILE
X   false
Xfi
X
Xmt -f $TAPE_FILE rewind
Xmt -f $TAPE_FILE offl
X
Xecho Sending the dump log to $ADMINISTRATOR
Xcat $LOGFILE | sed -f logfile.sed > $LOGFILE.tmp
X/usr/ucb/mail -s "Results of backup on `date`" $ADMINISTRATOR < $LOGFILE.tmp
X
X# This is undesirable -- rms.
X#rsh albert /usr/local/adm/motd-backup-done &
END_OF_FILE
if test 4297 -ne `wc -c <'level-0'`; then
    echo shar: \"'level-0'\" unpacked with wrong size!
fi
chmod +x 'level-0'
# end of 'level-0'
fi
if test -f 'level-1' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'level-1'\"
else
echo shar: Extracting \"'level-1'\" \(4708 characters\)
sed "s/^X//" >'level-1' <<'END_OF_FILE'
X#!/bin/sh 
X#
X# Run this script as root on the machine that has the tape drive, to make a
X# level-1 dump containing all files changed since the last full dump.
X#
X# If you give `now' as an argument, the dump is done immediately.
X# Otherwise, it waits until 1am.
X#
X# You must edit the file `backup-specs' to set the parameters for your site.
X
Xif [ ! -w / ]; then
X   echo The backup must be run as root,
X   echo or else some files will fail to be dumped.
X   exit 1
Xelse
X   false
Xfi
X
X# Get the values of BACKUP_DIRS and BACKUP_FILES, and other variables.
X. ./backup-specs
X
X# Maybe sleep until around specified or default hour.
X#
Xif [ "$1" != "now" ]; then
X   if [ "$1"x != x ]; then
X      spec=$1
X   else
X      spec=$BACKUP_HOUR
X   fi
X   pausetime=`date | awk '{hr=substr($4,1,2);\\
X      mn=substr($4,4,2);\\
X      if((hr+0)<spec)\\
X         print 3600*(spec-hr)-60*mn;\\
X      else\\
X         print 3600*(spec+(24-hr))-60*mn; }' spec=$spec`
X   clear
X   cat ./dont_touch
X   sleep $pausetime
Xfi
X
X# start doing things
X
Xhere=`pwd`
XLOGFILE=log-`date | awk '{print $2 "-" $3 "-" $6}'`-level-1
XHOST=`hostname | sed 's/\..*//'`
XTAR_PART1="/usr/local/bin/tar -c +multi-volume +one-file-system +block=$BLOCKING +sparse"
X#TAR_PART1="/usr/local/bin/tar -c +multi-volume +one-file-system +block=$BLOCKING "
X
X# Make sure the log file did not already exist.  Create it.
X
Xif [ -f $LOGFILE ] ; then
X   echo Log file $LOGFILE already exists.
X   exit 1
Xelse
X   touch $LOGFILE
Xfi
X
Xmt -f $TAPE_FILE rewind
X
Xset $BACKUP_DIRS
Xwhile [ $# -ne 0 ] ; do
X   host=`echo $1 | sed 's/:.*$//'`
X   fs=`echo $1 | sed 's/^.*://'`
X   date=`date`
X   fsname=`echo $1 | sed 's/\//:/g'`
X
X# This filename must be absolute; it is opened on the machine that runs tar.
X   TAR_PART2="+listed=/etc/tar-backup/temp.level-1"
X   TAR_PART3="+label='level 1 backup of $fs on $host at $date' -C $fs ."
X
X   echo Backing up $1 at $date | tee -a $LOGFILE
X   echo Last full dump on this filesystem: | tee -a $LOGFILE
X
X   if [ $HOST != $host ] ; then
X     rsh $host "ls -l /etc/tar-backup/$fsname.level-0; \
X	cp /etc/tar-backup/$fsname.level-0 /etc/tar-backup/temp.level-1" \
X	2>&1 | tee -a $LOGFILE
X   else
X     ls -l /etc/tar-backup/$fsname.level-0 2>&1 | tee -a $LOGFILE
X     cp /etc/tar-backup/$fsname.level-0 /etc/tar-backup/temp.level-1 2>&1 | tee -a $LOGFILE
X   fi
X
X   # Actually back things up.
X
X   if [ $HOST != $host ] ; then
X      rsh $host $TAR_PART1 -f $HOST:$TAPE_FILE $TAR_PART2 $TAR_PART3 2>&1 | tee -a $LOGFILE
X   else
X# Using `sh -c exec' causes nested quoting and shell substitution
X# to be handled here in the same way rsh handles it.
X      sh -c "exec $TAR_PART1 -f $TAPE_FILE $TAR_PART2 $TAR_PART3" 2>&1 | tee -a $LOGFILE
X   fi
X   if [ $? -ne 0 ] ; then
X      echo Backup of $1 failed. | tee -a $LOGFILE
X      # I'm assuming that the tar will have written an empty
X      # file to the tape, otherwise I should do a cat here.
X   else
X      if [ $HOST != $host ] ; then
X	rsh $host mv -f /etc/tar-backup/temp.level-1 /etc/tar-backup/$fsname.level-1 2>&1 | tee -a $LOGFILE
X      else
X        mv -f /etc/tar-backup/temp.level-1 /etc/tar-backup/$fsname.level-1 2>&1 | tee -a $LOGFILE
X      fi
X   fi
X   $TAPE_STATUS  | tee -a $LOGFILE
X   sleep 60
X   shift
Xdone
X
X# Dump any individual files requested.
X
Xif [ x != "x$BACKUP_FILES" ] ; then
X   date=`date`
X   TAR_PART2="+listed=/etc/tar-backup/temp.level-1"
X   TAR_PART3="+label='Incremental backup of miscellaneous files at $date'"
X
X   echo Backing up miscellaneous files at $date | tee -a $LOGFILE
X   echo Last full dump of these files: | tee -a $LOGFILE  
X   ls -l /etc/tar-backup/misc.level-0 2>&1 | tee -a $LOGFILE
X
X   rm -f /etc/tar-backup/temp.level-1 2>&1 | tee -a $LOGFILE
X   cp /etc/tar-backup/misc.level-0 /etc/tar-backup/temp.level-1 2>&1 | tee -a $LOGFILE
X
X   echo Backing up miscellaneous files at $date | tee -a $LOGFILE
X# Using `sh -c exec' causes nested quoting and shell substitution
X# to be handled here in the same way rsh handles it.
X   sh -c "exec $TAR_PART1 -f $TAPE_FILE $TAR_PART2 $TAR_PART3 \
X    $BACKUP_FILES" 2>&1 | tee -a $LOGFILE
X   if [ $? -ne 0 ] ; then
X     echo Backup of miscellaneous files failed. | tee -a $LOGFILE
X     # I'm assuming that the tar will have written an empty
X     # file to the tape, otherwise I should do a cat here.
X   else
X     mv -f /etc/tar-backup/temp.level-1 /etc/tar-backup/misc.level-1 2>&1 | tee -a $LOGFILE
X   fi
X   $TAPE_STATUS | tee -a $LOGFILE
Xelse
X   echo No miscellaneous files specified | tee -a $LOGFILE
X   false
Xfi
X
Xmt -f $TAPE_FILE rewind
Xmt -f $TAPE_FILE offl
X
Xecho Sending the dump log to $ADMINISTRATOR
Xcat $LOGFILE | sed -f logfile.sed > $LOGFILE.tmp
X/usr/ucb/mail -s "Results of backup on `date`" $ADMINISTRATOR < $LOGFILE.tmp
END_OF_FILE
if test 4708 -ne `wc -c <'level-1'`; then
    echo shar: \"'level-1'\" unpacked with wrong size!
fi
chmod +x 'level-1'
# end of 'level-1'
fi
if test -f 'backup-specs' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'backup-specs'\"
else
echo shar: Extracting \"'backup-specs'\" \(1574 characters\)
sed "s/^X//" >'backup-specs' <<'END_OF_FILE'
X# site-specific parameters for file system backup.
X
X# User name of administrator of backups.
XADMINISTRATOR=friedman
X
X# Hour at which backups are normally done.
X# This should be a number from 0 to 23.
XBACKUP_HOUR=1
X
X# Device to use for dumping.  It should be on the host
X# on which the dump scripts are run.
XTAPE_FILE=/dev/nrsmt0
X
X# Command to obtain status of tape drive, including error count.
X# On some tape drives there may not be such a command;
X# then simply use `TAPE_STATUS=false'.
XTAPE_STATUS="mts -t $TAPE_FILE"
X
X# Blocking factor to use for writing the dump.
XBLOCKING=124
X
X# List of file systems to be dumped.
X# Actually, any directory may be used,
X# but if it has subdirectories on other file systems,
X# they are not included.
X
X# The host name specifies which host to run tar on.
X# It should normally be the host that actually has the file system.
X# If GNU tar is not installed on that machine,
X# then you can specify some other host which can access
X# the file system through NFS.
X# Although these are arranged one per line, that is not mandatory.
X# It does not work to use # for comments within the string.
XBACKUP_DIRS="
X	albert:/fs/fsf
X	apple-gunkies:/gd
X	albert:/fs/gd2
X	godwin:/fs/gp
X	geech:/usr/jla
X	churchy:/usr/roland
X	albert:/
X	albert:/usr
X	apple-gunkies:/
X	apple-gunkies:/usr
X	ernst:/usr1
X	gnu:/
X	gnu:/usr
X	godwin:/
X	apple-gunkies:/com/mailer/gnu
X	apple-gunkies:/com/archive/gnu"
X
X# List of individual files to be dumped.
X# These should be accesible from the machine on which the dump is run.
XBACKUP_FILES="/com/mailer/aliases /com/mailer/league*[a-z]"
END_OF_FILE
if test 1574 -ne `wc -c <'backup-specs'`; then
    echo shar: \"'backup-specs'\" unpacked with wrong size!
fi
# end of 'backup-specs'
fi
if test -f 'testpad.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'testpad.c'\"
else
echo shar: Extracting \"'testpad.c'\" \(1343 characters\)
sed "s/^X//" >'testpad.c' <<'END_OF_FILE'
X/* Find out if we need the pad field in the header for this machine
X   Copyright (C) 1991 Free Software Foundation
X
X   This program is free software; you can redistribute it and/or
X   modify it under the terms of the GNU General Public License as
X   published by the Free Software Foundation; either version 1, or (at
X   your option) any later version.
X
X   This program is distributed in the hope that it will be useful, but
X   WITHOUT ANY WARRANTY; without even the implied warranty of
X   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
X   General Public License for more details.
X
X   You should have received a copy of the GNU General Public License
X   along with this program; if not, write to the Free Software
X   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
X*/
X
X#include <stdio.h>
X
Xstruct inc
X{
X  char a[20];
X  char b[20];
X};
X
Xstruct test1
X{
X  char a;
X  struct inc in[5];
X};
X
Xstruct test2
X{
X  char a;
X  char b;
X  struct inc in[5];
X};
X
Xmain ()
X{
X  struct test1 t1;
X  struct test2 t2;
X  int t1diff, t2diff;
X  
X  t1diff = (char *)&t1.in - (char *)&t1;
X  t2diff = (char *)&t2.in - (char *)&t2;
X  
X  if (t2diff == t1diff + 1)
X    printf ("#define NEEDPAD\n");
X  else if (t1diff != t2diff)
X    fprintf (stderr, "Cannot determine padding for tar struct, \n\
Xwill try with none.\n");
X
X  exit (0);
X}
X
X      
X    
X  
END_OF_FILE
if test 1343 -ne `wc -c <'testpad.c'`; then
    echo shar: \"'testpad.c'\" unpacked with wrong size!
fi
# end of 'testpad.c'
fi
echo shar: End of shell archive.
exit 0
