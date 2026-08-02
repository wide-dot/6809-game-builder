/*
os9.c
Copyright © 2009 William Astle

This file is part of LWASM.

LWASM is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <http://www.gnu.org/licenses/>.


This file implements the various pseudo operations related to OS9 target
*/
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <lw_alloc.h>
#include <lw_expr.h>

#include "lwasm.h"
#include "instab.h"


// OS9 syscall
PARSEFUNC(pseudo_parse_os9)
{
	lw_expr_t e;
	
	if (as -> output_format != OUTPUT_OS9 && as -> output_format != OUTPUT_OBJ)
	{
		lwasm_register_error2(as, l, E_DIRECTIVE_OS9_ONLY, "%s", "os9");
		return;
	}
	
	// fetch immediate value
	e = lwasm_parse_expr(as, p);
	if (!e)
	{
		lwasm_register_error(as, l, E_OPERAND_BAD);
		return;
	}
	lwasm_save_expr(l, 0, e);
	l -> len = 3;
}

EMITFUNC(pseudo_emit_os9)
{
	lw_expr_t e;
	
	e = lwasm_fetch_expr(l, 0);

	lwasm_emitop(l, 0x103f);
	lwasm_emitexpr(l, e, 1);
}

PARSEFUNC(pseudo_parse_mod)
{
	lw_expr_t e;
	int i;
	
	if (as -> inmod)
	{
		lwasm_register_error(as, l, E_MODULE_IN);
		skip_operand(p);
		return;
	}

	// parse 6 (or 4) expressions...
	for (i = 0; i < 5; i++)
	{
		e = lwasm_parse_expr(as, p);
		if (!e)
		{
			lwasm_register_error(as, l, E_OPERAND_BAD);
			return;
		}

		lwasm_save_expr(l, i, e);

		if (**p != ',')
		{
			if (i == 3)
			{
				// we don't have the extra items; flag it and don't bother
				// with them later; goto is to short circuit the rest of
				// the expression parsing
				l -> lint = 4;
				goto doneexpr;
			}
			lwasm_register_error(as, l, E_OPERAND_BAD);
			return;
		}
		(*p)++;
	}
	e = lwasm_parse_expr(as, p);
	if (!e)
	{
		lwasm_register_error(as, l, E_OPERAND_BAD);
		return;
	}
	lwasm_save_expr(l, 5, e);
	l -> lint = 6;

doneexpr:
	l -> inmod = 1;
	
	// we have an implicit ORG 0 with "mod"
	lw_expr_destroy(l -> addr);
	l -> addr = lw_expr_build(lw_expr_type_int, 0);

	// likewise for data pointer
	lw_expr_destroy(l -> daddr);
	l -> daddr = lw_expr_build(lw_expr_type_int, 0);

	// In os9 format, set inmod so ORG uses module-relative addressing.
	// In other formats (e.g. rawrel), keep inmod=0 so ORG still updates
	// addr normally (needed for structured macro backpatching). EMOD will
	// recompute CRC from scratch over the final output bytes regardless.
	if (as -> output_format == OUTPUT_OS9)
		as -> inmod = 1;

	l -> len = (l -> lint == 6) ? 13 : 9;
}

EMITFUNC(pseudo_emit_mod)
{
	lw_expr_t e1, e2, e3, e4;
	int csum;
	
	as -> crc[0] = 0xff;
	as -> crc[1] = 0xff;
	as -> crc[2] = 0xff;

	// sync bytes
	lwasm_emit(l, 0x87);
	lwasm_emit(l, 0xcd);
	
	// mod length
	lwasm_emitexpr(l, e1 = lwasm_fetch_expr(l, 0), 2);
	
	// name offset
	lwasm_emitexpr(l, e2 = lwasm_fetch_expr(l, 1), 2);
	
	// type
	lwasm_emitexpr(l, e3 = lwasm_fetch_expr(l, 2), 1);
	
	// flags/rev
	lwasm_emitexpr(l, e4 = lwasm_fetch_expr(l, 3), 1);
	
	// header check
	csum = ~(0x87 ^ 0xCD ^(lw_expr_intval(e1) >> 8) ^ (lw_expr_intval(e1) & 0xff)
		^ (lw_expr_intval(e2) >> 8) ^ (lw_expr_intval(e2) & 0xff)
		^ lw_expr_intval(e3) ^ lw_expr_intval(e4));
	lwasm_emit(l, csum);

	if (l -> lint == 6)
	{
		// module type specific output, if provided
		// note that these are handled the same for all so
		// there need not be any special casing

		// exec offset or fmgr name offset
		lwasm_emitexpr(l, lwasm_fetch_expr(l, 4), 2);

		// data size or drvr name offset
		lwasm_emitexpr(l, lwasm_fetch_expr(l, 5), 2);
	}
}

PARSEFUNC(pseudo_parse_emod)
{
	skip_operand(p);

	// In os9 format, inmod tracks module state. In other formats,
	// MOD may not set inmod (to preserve ORG behavior), so skip check.
	if (as -> output_format == OUTPUT_OS9 && !(as -> inmod))
	{
		lwasm_register_error(as, l, E_MODULE_NOTIN);
		return;
	}

	as -> inmod = 0;
	l -> len = 3;
}

static void os9_crc_update(unsigned char crc[3], unsigned char byte)
{
	// CRC-24 used by OS-9 modules
	// direct transliteration from nitros9 asm source
	byte ^= crc[0];
	crc[0] = crc[1];
	crc[1] = crc[2];
	crc[1] ^= (byte >> 7);
	crc[2] = (byte << 1);
	crc[1] ^= (byte >> 2);
	crc[2] ^= (byte << 6);
	byte ^= (byte << 1);
	byte ^= (byte << 2);
	byte ^= (byte << 4);
	if (byte & 0x80)
	{
		crc[0] ^= 0x80;
		crc[2] ^= 0x21;
	}
}

EMITFUNC(pseudo_emit_emod)
{
	unsigned char crc[3];
	unsigned char *image;
	line_t *cl;
	int i, addr, modsize;

	// Build a flat byte image of the module, then compute CRC over it.
	// This correctly handles ORG backpatching (used by structured macros)
	// where later lines overwrite bytes emitted by earlier lines.
	modsize = lw_expr_intval(l -> addr);
	if (modsize <= 0)
		modsize = 0x10000;  // fallback
	image = lw_alloc(modsize);
	memset(image, 0, modsize);

	for (cl = as -> line_head; cl != l; cl = cl -> next)
	{
		if (cl -> outputl > 0 && cl -> output)
		{
			addr = lw_expr_intval(cl -> addr);
			if (addr >= 0 && addr + cl -> outputl <= modsize)
			{
				memcpy(image + addr, cl -> output, cl -> outputl);
			}
		}
	}

	crc[0] = 0xff;
	crc[1] = 0xff;
	crc[2] = 0xff;
	for (i = 0; i < modsize; i++)
		os9_crc_update(crc, image[i]);

	lw_free(image);

	crc[0] ^= 0xff;
	crc[1] ^= 0xff;
	crc[2] ^= 0xff;
	lwasm_emit(l, crc[0]);
	lwasm_emit(l, crc[1]);
	lwasm_emit(l, crc[2]);
}
