/*
lwcc/cpp-main.c

Copyright © 2013 William Astle

This file is part of LWTOOLS.

LWTOOLS is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lw_alloc.h>
#include <lw_stringlist.h>
#include <lw_cmdline.h>
#include <lw_string.h>

#include <version.h>

#include "cpp.h"

int process_file(const char *);
static void do_error(const char *f, ...);

/* command line option handling */
#define PROGVER "lwcc-cpp from " PACKAGE_STRING
char *program_name;

/* input files */
lw_stringlist_t input_files;
lw_stringlist_t includedirs;
lw_stringlist_t sysincludedirs;
lw_stringlist_t macrolist;
lw_stringlist_t sysmacrolist;

/* various flags */
int trigraphs = 0;
char *output_file = NULL;
FILE *output_fp = NULL;

static struct lw_cmdline_options options[] =
{
	{ "output",		'o',	"FILE",		0,							"Output to FILE"},
	{ "include",	'i',	"FILE",		0,							"Pre-include FILE" },
	{ "includedir",	'I',	"PATH",		0,							"Add entry to the user include path" },
	{ "sincludedir", 'S',	"PATH",		0,							"Add entry to the system include path" },
	{ "define", 	'D',	"SYM[=VAL]",0, 							"Automatically define SYM to be VAL (or 1)"},
	{ "undefine",   'U',    "SYM",      0,                          "Undefine SYM"},
	{ "trigraphs",	0x100,	NULL,		0,							"Enable interpretation of trigraphs" },
	{ "language",   'x',    "LANG",     0,                          "Specify language; currently ignored" },
	{ "nostdinc",   0x101,  NULL,       lw_cmdline_opt_single,      "Disable standard include paths" },
	{ "undef",      0x102,  NULL,       lw_cmdline_opt_single,      "Do not define any standard system or language macros" },
	{ 0 }
};

static int parse_opts(int key, char *arg, void *state)
{
	switch (key)
	{
	case 'o':
		if (output_file)
			do_error("Output file specified more than once.");
		output_file = arg;
		break;

	case 'x':
		break;

	case 0x100:
		trigraphs = 1;
		break;

	// -nostdinc
	case 0x101:
		lw_stringlist_destroy(sysincludedirs);
		sysincludedirs = lw_stringlist_create();
		break;

	case 0x102:
		lw_stringlist_destroy(sysmacrolist);
		sysmacrolist = lw_stringlist_create();
		break;

	case 'I':
		lw_stringlist_addstring(includedirs, arg);
		break;
	
	case 'S':
		lw_stringlist_addstring(sysincludedirs, arg);
		break;

	case 'D':
		lw_stringlist_addstring(macrolist, arg);
		break;

	case 'U':
		{
			lw_stringlist_t *nl;
			char *s;
			int c;
			nl = lw_stringlist_create();
			lw_stringlist_reset(macrolist);
			while ((s = lw_stringlist_current(macrolist)))
			{
				lw_stringlist_addstring(nl, s);
				for (c = 0; arg[c] && s[c] && arg[c] == s[c]; c++)
					if (s[c] == '=' || arg[c] == '=')
						break;
				if (!arg[c] && (!s[c] || s[c] == '='))
					continue;
				lw_stringlist_next(macrolist);
			}
			lw_stringlist_destroy(macrolist);
			macrolist = nl;
		}
		break;

	case lw_cmdline_key_end:
		break;
	
	case lw_cmdline_key_arg:
		lw_stringlist_addstring(input_files, arg);
		break;
		
	default:
		return lw_cmdline_err_unknown;
	}
	return 0;
}

static struct lw_cmdline_parser cmdline_parser =
{
	options,
	parse_opts,
	"INPUTFILE",
	"lwcc-cpp - C preprocessor for lwcc",
	PROGVER
};

int main(int argc, char **argv)
{
	program_name = argv[0];
	int retval = 0;
	
	input_files = lw_stringlist_create();
	includedirs = lw_stringlist_create();
	sysincludedirs = lw_stringlist_create();
	macrolist = lw_stringlist_create();
	
	/* parse command line arguments */	
	lw_cmdline_parse(&cmdline_parser, argc, argv, 0, 0, NULL);

	/* set up output file */
	if (output_file == NULL || strcmp(output_file, "-") == 0)
	{
		output_fp = stdout;
	}
	else
	{
		output_fp = fopen(output_file, "wb");
		if (output_fp == NULL)
		{
			do_error("Failed to create output file %s: %s", output_file, strerror(errno)); 
		}
	}
	
	if (lw_stringlist_nstrings(input_files) == 0)
	{
		/* if no input files, work on stdin */
		retval = process_file("-");
	}
	else
	{
		char *s;
		lw_stringlist_reset(input_files);
		for (s = lw_stringlist_current(input_files); s; s = lw_stringlist_next(input_files))
		{
			retval = process_file(s);
			if (retval != 0)
				break;
		}
	}
	lw_stringlist_destroy(input_files);
	lw_stringlist_destroy(includedirs);
	lw_stringlist_destroy(sysincludedirs);
	lw_stringlist_destroy(macrolist);
	exit(retval);
}

static void print_line_marker(FILE *fp, int line, const char *fn, int flag)
{
	fprintf(fp, "\n# %d \"", line);
	while (*fn)
	{
		if (*fn < 32 || *fn == 34 || *fn > 126)
		{
			fprintf(fp, "\\%03o", *fn);
		}
		else
		{
			fprintf(fp, "%c", *fn);
		}
		fn++;
	}
	fprintf(fp, "\" %d", flag);
}

int process_file(const char *fn)
{
	struct preproc_info *pp;
	struct token *tok = NULL;
	int last_line = 0;
	char *last_fn = NULL;
	char *tstr;
		
	pp = preproc_init(fn);
	if (!pp)
		return -1;

	/* set up the include paths */
	lw_stringlist_reset(includedirs);
	for (tstr = lw_stringlist_current(includedirs); tstr; tstr = lw_stringlist_next(includedirs))
	{
		preproc_add_include(pp, tstr, 0);
	}

	lw_stringlist_reset(sysincludedirs);
	for (tstr = lw_stringlist_current(sysincludedirs); tstr; tstr = lw_stringlist_next(sysincludedirs))
	{
		preproc_add_include(pp, tstr, 1);
	}

	/* set up pre-defined macros */
	lw_stringlist_reset(sysmacrolist);
	for (tstr = lw_stringlist_current(sysmacrolist); tstr; tstr = lw_stringlist_next(sysmacrolist))
	{
		preproc_add_macro(pp, tstr);
	}

	/* set up command line defined macros */
	lw_stringlist_reset(macrolist);
	for (tstr = lw_stringlist_current(macrolist); tstr; tstr = lw_stringlist_next(macrolist))
	{
		preproc_add_macro(pp, tstr);
	}

	print_line_marker(output_fp, 1, fn, 1);
	last_fn = lw_strdup(fn);	
	for (;;)
	{
		tok = preproc_next(pp);
		if (tok -> ttype == TOK_EOF)
			break;
		if (strcmp(tok -> fn, last_fn) != 0)
		{
			int lt = 1;
			if (tok -> lineno != 1)
			{
				lt = 2;
			}
			lw_free(last_fn);
			last_fn = lw_strdup(tok -> fn);
			last_line = tok -> lineno;
			print_line_marker(output_fp, last_line, last_fn, lt);
		}
		else
		{
			while (tok -> lineno > last_line)
			{
				fprintf(output_fp, "\n");
				last_line++;
			}
		}
		token_print(tok, output_fp);
		if (tok -> ttype == TOK_EOL)
			last_line++;
		token_free(tok);
	}
	token_free(tok);
	lw_free(last_fn);
//	symtab_dump(pp);
	preproc_finish(pp);
	return 0;
}

static void do_error(const char *f, ...)
{
	va_list args;
	va_start(args, f);
	fprintf(stderr, "ERROR: ");
	vfprintf(stderr, f, args);
	va_end(args);
	fprintf(stderr, "\n");
	exit(1);
}
