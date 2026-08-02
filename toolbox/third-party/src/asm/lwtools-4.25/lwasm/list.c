/*
list.c

Copyright © 2010 William Astle

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

#include <ctype.h>
#include <stdio.h>
#include <string.h>

#include <lw_alloc.h>
#include <lw_string.h>

#include "lwasm.h"
#include "instab.h"

void list_symbols(asmstate_t *as, FILE *of);

/*
Print source line with columnar formatting.
Parses line into label/mnemonic/operand/comment fields and
prints each at the configured column position.
*/
static void list_pad_to(FILE *of, int *col, int target)
{
	if (!of) return;
	if (*col >= target) { fputc(' ', of); (*col)++; return; }
	while (*col < target) { fputc(' ', of); (*col)++; }
}

static void list_source_columnar(asmstate_t *as, line_t *cl, char *line, FILE *of)
{
	char *p = line;
	char *label = NULL, *mnem = NULL, *oper = NULL, *comment = NULL;
	int llen = 0, mlen = 0, olen = 0;
	int col = 0;

	if (!of || !line || !*line) return;

	/* Full-line comment: * or ; at column 0 — print as-is */
	if (*p == '*' || *p == ';')
	{
		fputs(p, of);
		return;
	}

	/* Label: non-whitespace starting at column 0 */
	if (*p && !isspace((unsigned char)*p))
	{
		label = p;
		while (*p && !isspace((unsigned char)*p))
			p++;
		llen = p - label;
	}

	/* Skip whitespace to mnemonic */
	while (*p && isspace((unsigned char)*p))
		p++;

	/* Mnemonic */
	if (*p && *p != '*' && *p != ';')
	{
		mnem = p;
		while (*p && !isspace((unsigned char)*p))
			p++;
		mlen = p - mnem;
	}

	/* Skip whitespace to operand */
	while (*p && (*p == ' ' || *p == '\t'))
		p++;

	/* If the parser determined this line has no operand,
	   everything after the mnemonic is comment */
	if (!cl -> hasoperand)
	{
		if (*p)
			comment = p;
		goto do_print;
	}

	/* Operand: everything up to a comment or end of line.
	   Note: * mid-line is current PC or multiply, not a comment. */
	if (*p && *p != ';')
	{
		oper = p;
		/* Find end of operand - tricky because of string literals */
		while (*p && *p != ';')
		{
			if (*p == '\'' || *p == '"' || *p == '/')
			{
				/* String literal - skip to matching delimiter */
				char q = *p++;
				while (*p && *p != q)
					p++;
				if (*p) p++;
			}
			else if (*p == '#' && p[1] == '\'')
			{
				/* Character literal #'x - skip the 3 chars */
				p += 2;
				if (*p) p++;
			}
			else if (isspace((unsigned char)*p))
			{
				/* whitespace could be separator before comment */
				char *t = p;
				while (*t && isspace((unsigned char)*t))
					t++;
				if (!*t || *t == ';')
					break;
				/* it's whitespace in the middle - could be comment text */
				/* heuristic: if next word looks like an instruction, it's not a comment */
				/* simpler: treat remaining text as comment */
				break;
			}
			else
				p++;
		}
		/* trim trailing whitespace from operand */
		olen = p - oper;
		while (olen > 0 && isspace((unsigned char)oper[olen - 1]))
			olen--;
	}

	/* Skip whitespace to comment */
	while (*p && isspace((unsigned char)*p))
		p++;

	/* Comment: rest of line */
	if (*p)
		comment = p;

do_print:
	/* Now print each field at its column */
	col = 0;

	/* Label */
	if (label && llen > 0)
	{
		list_pad_to(of, &col, as -> listcol[0]);
		fwrite(label, 1, llen, of);
		col += llen;
	}

	/* Mnemonic */
	if (mnem && mlen > 0)
	{
		list_pad_to(of, &col, as -> listcol[1]);
		fwrite(mnem, 1, mlen, of);
		col += mlen;
	}

	/* Operand */
	if (oper && olen > 0)
	{
		list_pad_to(of, &col, as -> listcol[2]);
		fwrite(oper, 1, olen, of);
		col += olen;
	}

	/* Comment */
	if (comment)
	{
		list_pad_to(of, &col, as -> listcol[3]);
		fputs(comment, of);
	}
}

/*
Do listing
*/
void do_list(asmstate_t *as)
{
	line_t *cl, *nl, *nl2;
	FILE *of = NULL;
	int i;
	unsigned char *obytes = NULL;
	int obytelen = 0;
	
	char *tc;
		
	if (!(as -> flags & FLAG_LIST))
	{
		of = NULL;
	}
	else
	{		
		if (as -> list_file)
		{
			if (strcmp(as -> list_file, "-") == 0)
			{
				of = stdout;
			}
			else
				of = fopen(as -> list_file, "w");
		}
		else
			of = stdout;

		if (!of)
		{
			fprintf(stderr, "Cannot open list file; list not generated\n");
			return;
		}
	}

	for (cl = as -> line_head; cl; cl = nl)
	{
		char *linespec;

		nl = cl -> next;
		if (CURPRAGMA(cl, PRAGMA_NOLISTCODE))
		{
			continue;
		}
		if (CURPRAGMA(cl, PRAGMA_NOLIST))
		{
			if (cl -> outputl <= 0)
				continue;
		}
		if (cl -> noexpand_start)
		{
			obytelen = 0;
			int nc = 0;
			for (nl = cl; nl; nl = nl -> next)
			{
				if (nl -> noexpand_start)
					nc += nl -> noexpand_start;
				if (nl -> noexpand_end)
					nc -= nl -> noexpand_end;
				
				if (nl -> outputl > 0)
					obytelen += nl -> outputl;
				if (nl -> warn)
				{
					lwasm_error_t *e;
					for (e = nl -> warn; e; e = e -> next)
					{
						if (of != stdout) printf("Warning (%s:%d): %s\n", cl -> linespec, cl -> lineno,  e -> mess);
						if (of) fprintf(of, "Warning: %s\n", e -> mess);
					}
				}
				if (nc == 0)
					break;
			}
			obytes = lw_alloc(obytelen);
			nc = 0;
			for (nl2 = cl; ; nl2 = nl2 -> next)
			{
				int i;
				for (i = 0; i < nl2 -> outputl; i++)
				{
					obytes[nc++] = nl2 -> output[i];
				}
				if (nc >= obytelen)
					break;
			}
			if (nl)
				nl = nl -> next;
		}
		else
		{
			if (cl -> warn)
			{
				lwasm_error_t *e;
				for (e = cl -> warn; e; e = e -> next)
				{
					if (of != stdout) printf("Warning (%s:%d): %s\n", cl -> linespec, cl -> lineno, e -> mess);
					if (of) fprintf(of, "Warning: %s\n", e -> mess);
				}
			}
			obytelen = cl -> outputl;
			if (obytelen > 0)
			{
				obytes = lw_alloc(obytelen);
				memmove(obytes, cl -> output, cl -> outputl);
			}
		}
		if (cl -> hidecond && CURPRAGMA(cl, PRAGMA_NOEXPANDCOND))
			continue;
		if ((cl -> len < 1 && cl -> dlen < 1) && obytelen < 1 && (cl -> symset == 1 || cl -> sym == NULL) )
		{
			if (cl -> soff >= 0)
			{
				if (of) fprintf(of, "%04Xs                 ", cl -> soff & 0xffff);
			}
			else if (cl -> dshow >= 0)
			{
				if (cl -> dsize == 1)
				{
					if (of) fprintf(of, "     %02X               ", cl -> dshow & 0xff);
				}
				else
				{
					if (of) fprintf(of, "     %04X               ", cl -> dshow & 0xff);
				}
			}
			else if (cl -> dptr)
			{
				lw_expr_t te;
				te = lw_expr_copy(cl -> dptr -> value);
				as -> exportcheck = 1;
				as -> csect = cl -> csect;
				lwasm_reduce_expr(as, te);
				as -> exportcheck = 0;
				if (lw_expr_istype(te, lw_expr_type_int))
				{
					if (of) fprintf(of, "     %04X             ", lw_expr_intval(te) & 0xffff);
				}
				else
				{
					if (of) fprintf(of, "     ????             ");
				}
				lw_expr_destroy(te);
			}
			else
			{
				if (of) fprintf(of, "                      ");
			}
		}
		else
		{
			lw_expr_t te;
			if ((cl -> insn >= 0) && (instab[cl -> insn].flags & lwasm_insn_setdata))
				te = lw_expr_copy(cl -> daddr);
			else
				te = lw_expr_copy(cl -> addr);
			as -> exportcheck = 1;
			as -> csect = cl -> csect;
			lwasm_reduce_expr(as, te);
			as -> exportcheck = 0;
//			if (of) fprintf(of, "%s\n", lw_expr_print(te));
			if (of) fprintf(of, "%04X%c", lw_expr_intval(te) & 0xffff, ((cl -> inmod || (cl -> dlen != cl -> len)) && instab[cl -> insn].flags & lwasm_insn_setdata) ? '.' : ' ');
			lw_expr_destroy(te);
			for (i = 0; i < obytelen && i < 8; i++)
			{
				if (of) fprintf(of, "%02X", obytes[i]);
			}
			for (; i < 8; i++)
			{
				if (of) fprintf(of, "  ");
			}
			if (of) fprintf(of, " ");
		}

		/* the format specifier below is deliberately chosen so that the start of the line text is at
		a multiple of 8 from the start of the list line */

		#define max_linespec_len 17

		// trim "include:" if it appears
		if (as -> listnofile)
		{
			if (of) fprintf(of, "%05d ", cl->lineno);
		}
		else
		{
			linespec = cl -> linespec;
			if ((strlen(linespec) > 8) && (linespec[7] == ':')) linespec += 8;
			if (strlen(linespec) > max_linespec_len)
				linespec += strlen(linespec) - max_linespec_len;
			while (*linespec == ' ') linespec++;

			if (of) fprintf(of, "(%*.*s):%05d ", max_linespec_len, max_linespec_len, linespec, cl->lineno);
		}
		
		if (CURPRAGMA(cl, PRAGMA_CC))
		{
			as->cycle_total = 0;
		}

		/* display cycle counts */
		char s[64] = "";
		if (CURPRAGMA(cl, PRAGMA_C) || CURPRAGMA(cl, PRAGMA_CD))
		{
			char sch = '(', ech = ')';
			if (CURPRAGMA(cl, PRAGMA_6809))
	 		{
				sch = '[';
				ech = ']';
			}
			if (cl->cycle_base != 0)
			{
				int est = cl -> cycle_flags & CYCLE_ESTIMATED;

				if (CURPRAGMA(cl, PRAGMA_CD) && cl->cycle_flags & CYCLE_ADJ)
				{
					sprintf(s, "%c%d+%d%s%c", sch, cl->cycle_base, cl->cycle_adj, est ? "+?" : "", ech);	/* detailed cycle count */
				}
				else
				{
					sprintf(s, "%c%d%s%c", sch, cl->cycle_base + cl->cycle_adj, est ? "+?" : "", ech);   /* normal cycle count*/
				}
				as->cycle_total += cl->cycle_base + cl->cycle_adj;
			}
		}

		if (of) fprintf(of, "%-8s", s);

		if (CURPRAGMA(cl, PRAGMA_CT)) 
		{
			if (cl->cycle_base != 0)
			{
				if (of) fprintf(of, "%-8d", as->cycle_total);
			}
			else
			{
				if (of) fprintf(of, "        ");
			}
		}

		if (as -> listcol[1] > 0)
		{
			/* Column-formatted listing output */
			list_source_columnar(as, cl, cl -> ltext, of);
		}
		else if (as -> tabwidth == 0)
		{
			if (of) fputs(cl -> ltext, of);
		}
		else
		{
			i = 0;
			for (tc = cl -> ltext; *tc; tc++)
			{
				if ((*tc) == '\t')
				{
					if (i % as -> tabwidth == 0)
					{
						if (of) fputc(' ', of);
						i++;
					}
					while (i % as -> tabwidth)
					{
						if (of) fputc(' ', of);
						i++;
					}
				}
				else
				{
					if (of) fputc(*tc, of);
					i++;
				}
			}
		}
		if (of) fputc('\n', of);

		if (obytelen > 8)
		{
			for (i = 8; i < obytelen; i++)
			{
				if (i % 8 == 0)
				{
					if (i != 8)
					{
						if (of) fprintf(of, "\n     ");
					}
					else
					{
						if (of) fprintf(of, "     ");
					}
				}
				if (of) fprintf(of, "%02X", obytes[i]);
			}
			if (i > 8)
				if (of) fprintf(of, "\n");
		}
		lw_free(obytes);
		obytes = NULL;
	}
	if ((as -> flags & FLAG_SYMBOLS) && of)
		list_symbols(as, of);
	if (of && of != stdout)
		fclose(of);
}
