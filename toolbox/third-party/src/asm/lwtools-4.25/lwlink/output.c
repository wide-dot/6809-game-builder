/*
output.c
Copyright © 2009 William Astle

This file is part of LWLINK.

LWLINK is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <http://www.gnu.org/licenses/>.


Actually output the binary
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lwlink.h"

// this prevents warnings about not using the return value of fwrite()
// and, theoretically, can be replaced with a function that handles things
// better in the future
//#define writebytes(s, l, c, f)	do { int r; r = fwrite((s), (l), (c), (f)); (void)r; } while (0)
#define writebytes(s, l, c, f)	do { (void)(fwrite((s), (l), (c), (f)) && 1); } while (0)

void do_output_flex(FILE *of);
void do_output_os9(FILE *of);
void do_output_decb(FILE *of);
void do_output_raw(FILE *of);
void do_output_raw2(FILE *of);
void do_output_lwex0(FILE *of);
void do_output_srec(FILE *of);
void do_output_ihex(FILE *of);
void do_output_uniflex(FILE *of);

void do_output(void)
{
	FILE *of;
	
	of = fopen(outfile, "wb");
	if (!of)
	{
		fprintf(stderr, "Cannot open output file %s: ", outfile);
		perror("");
		exit(1);
	}
	
	switch (outformat)
	{
	case OUTPUT_DECB:
		do_output_decb(of);
		break;
	
	case OUTPUT_RAW:
		do_output_raw(of);
		break;

	case OUTPUT_RAW2:
		do_output_raw2(of);
		break;

	case OUTPUT_LWEX0:
		do_output_lwex0(of);
		break;
	
	case OUTPUT_FLEX:
		do_output_flex(of);
		break;
		
	case OUTPUT_OS9:
		do_output_os9(of);
		break;
		
	case OUTPUT_SREC:
		do_output_srec(of);
		break;

	case OUTPUT_IHEX:
		do_output_ihex(of);
		break;

	case OUTPUT_UNIFLEX:
		do_output_uniflex(of);
		break;

	default:
		fprintf(stderr, "Unknown output format doing output!\n");
		exit(111);
	}
	
	fclose(of);
}

void do_output_decb(FILE *of)
{
	int sn, sn2;
	int cloc, olen;
	unsigned char buf[5];
	
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
		{
			// no output for a BSS section
			continue;
		}
		if (sectlist[sn].ptr -> codesize == 0)
		{
			// don't generate output for a zero size section
			continue;
		}
		
		// calculate the length of this output block
		cloc = sectlist[sn].ptr -> loadaddress;
		olen = 0;
		for (sn2 = sn; sn2 < nsects; sn2++)
		{
			// ignore BSS sections
			if (sectlist[sn2].ptr -> flags & SECTION_BSS)
				continue;
			// ignore zero length sections
			if (sectlist[sn2].ptr -> codesize == 0)
				continue;
			if (cloc != sectlist[sn2].ptr -> loadaddress)
				break;
			olen += sectlist[sn2].ptr -> codesize;
			cloc += sectlist[sn2].ptr -> codesize;
		}
		
		// write a preamble
		buf[0] = 0x00;
		buf[1] = olen >> 8;
		buf[2] = olen & 0xff;
		buf[3] = sectlist[sn].ptr -> loadaddress >> 8;
		buf[4] = sectlist[sn].ptr -> loadaddress & 0xff;
		writebytes(buf, 1, 5, of);
		for (; sn < sn2; sn++)
		{
			if (sectlist[sn].ptr -> flags & SECTION_BSS)
				continue;
			if (sectlist[sn].ptr -> codesize == 0)
				continue;
			writebytes(sectlist[sn].ptr -> code, 1, sectlist[sn].ptr -> codesize, of);
		}
		sn--;
	}
	// write a postamble
	buf[0] = 0xff;
	buf[1] = 0x00;
	buf[2] = 0x00;
	buf[3] = linkscript.execaddr >> 8;
	buf[4] = linkscript.execaddr & 0xff;
	writebytes(buf, 1, 5, of);
}

/*
This is very similar to the decb format. The preamble here begins
with $02 instead of $00 for load segments, and the length and load
address fields are swapped. For the transfer address, the preamble
begins with $16 instead of $FF, and the next two bytes are thre
transfer addess. The transfer address preamble is only three bytes
long.
*/
void do_output_flex(FILE *of)
{
	int sn, sn2;
	int cloc, olen;
	unsigned char buf[5];
	
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
		{
			// no output for a BSS section
			continue;
		}
		if (sectlist[sn].ptr -> codesize == 0)
		{
			// don't generate output for a zero size section
			continue;
		}
		
		// calculate the length of this output block
		cloc = sectlist[sn].ptr -> loadaddress;
		olen = 0;
		for (sn2 = sn; sn2 < nsects; sn2++)
		{
			// ignore BSS sections
			if (sectlist[sn2].ptr -> flags & SECTION_BSS)
				continue;
			// ignore zero length sections
			if (sectlist[sn2].ptr -> codesize == 0)
				continue;
			if (cloc != sectlist[sn2].ptr -> loadaddress)
				break;
			olen += sectlist[sn2].ptr -> codesize;
			cloc += sectlist[sn2].ptr -> codesize;
		}
		
		// write a preamble
		buf[0] = 0x02;
		buf[1] = sectlist[sn].ptr -> loadaddress >> 8;
		buf[2] = sectlist[sn].ptr -> loadaddress & 0xff;
		buf[3] = olen >> 8;
		buf[4] = olen & 0xff;
		writebytes(buf, 1, 5, of);
		for (; sn < sn2; sn++)
		{
			if (sectlist[sn].ptr -> flags & SECTION_BSS)
				continue;
			if (sectlist[sn].ptr -> codesize == 0)
				continue;
			writebytes(sectlist[sn].ptr -> code, 1, sectlist[sn].ptr -> codesize, of);
		}
		sn--;
	}
	// write a postamble
	buf[0] = 0x16;
	buf[1] = linkscript.execaddr >> 8;
	buf[2] = linkscript.execaddr & 0xff;
	writebytes(buf, 1, 3, of);
}

void do_output_raw(FILE *of)
{
	int sn;

	
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
		{
			// no output for a BSS section
			continue;
		}
		writebytes(sectlist[sn].ptr -> code, 1, sectlist[sn].ptr -> codesize, of);
	}
}

void do_output_raw2(FILE *of)
{
	int nskips = 0;		// used to output blanks for BSS inline
	int sn;

	
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
		{
			// no output for a BSS section
			nskips += sectlist[sn].ptr -> codesize;
			continue;
		}
		while (nskips > 0)
		{
			// the "" is not an error - it turns into a single NUL byte!
			writebytes("", 1, 1, of);
			nskips--;
		}
		writebytes(sectlist[sn].ptr -> code, 1, sectlist[sn].ptr -> codesize, of);
	}
}

void do_output_srec(FILE *of)
{
	const int SRECLEN = 16;

	int sn;	
	int remainingcodebytes;
	
	int codeaddr;
	int i;
	int recaddr = 0;
	int recdlen = 0;
	int recsum;
	unsigned char* sectcode;
	// no header yet; unnecessary

	for (sn = 0; sn < nsects; sn++)				// check all sections
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)	// ignore BSS sections
			continue;
		if (sectlist[sn].ptr -> codesize == 0)		// ignore empty sections
			continue;

		recaddr = sectlist[sn].ptr -> loadaddress;
		remainingcodebytes = sectlist[sn].ptr -> codesize;
		sectcode = sectlist[sn].ptr -> code;
		
		while (remainingcodebytes) 
		{
			recdlen = (SRECLEN>remainingcodebytes)?remainingcodebytes:SRECLEN;
			recsum = recdlen + 3;
			codeaddr = recaddr - sectlist[sn].ptr -> loadaddress;			
			fprintf(of, "S1%02X%04X", recdlen + 3, recaddr & 0xffff);
			for (i = 0; i < recdlen; i++)
			{
				fprintf(of, "%02X", sectcode[codeaddr+i]);
				recsum += sectcode[codeaddr+i];
			}
			recsum += (recaddr >> 8) & 0xFF;
			recsum += recaddr & 0xFF;
			fprintf(of, "%02X\r\n", (unsigned char)(~recsum));
			remainingcodebytes -= recdlen;
			recaddr += recdlen;
		}
	}
	// S9 record as a footer to inform about start addr
	recsum = 3;
	recsum += (linkscript.execaddr >> 8) & 0xFF;
	recsum += linkscript.execaddr & 0xFF;
	fprintf(of,"S903%04X%02X\r\n",linkscript.execaddr,(unsigned char)(~recsum));
}

void do_output_ihex(FILE *of)
{
	const int IRECLEN = 16;

	int sn;	
	int remainingcodebytes;
	
	int codeaddr;
	int i;
	int recaddr = 0;
	int recdlen = 0;
	int recsum;
	int reccnt = -1;
	unsigned char* sectcode;
	// no header yet; unnecessary

	for (sn = 0; sn < nsects; sn++)				// check all sections
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)	// ignore BSS sections
			continue;
		if (sectlist[sn].ptr -> codesize == 0)		// ignore empty sections
			continue;

		recaddr = sectlist[sn].ptr -> loadaddress;
		remainingcodebytes = sectlist[sn].ptr -> codesize;
		sectcode = sectlist[sn].ptr -> code;
		
		while (remainingcodebytes) 
		{
			recdlen = (IRECLEN>remainingcodebytes)?remainingcodebytes:IRECLEN;
			recsum = recdlen;
			codeaddr = recaddr - sectlist[sn].ptr -> loadaddress;			
			fprintf(of, ":%02X%04X00", recdlen, recaddr & 0xffff);
			for (i = 0; i < recdlen; i++)
			{
				fprintf(of, "%02X", sectcode[codeaddr+i]);
				recsum += sectcode[codeaddr+i];
			}
			recsum += (recaddr >> 8) & 0xFF;
			recsum += recaddr & 0xFF;
			fprintf(of, "%02X\r\n", (unsigned char)(256 - recsum));
			reccnt += 1;
			remainingcodebytes -= recdlen;
			recaddr += recdlen;
		}
	}
	if (reccnt > 0)
	{
		fprintf(of, ":00%04X01FF\r\n", linkscript.execaddr);
	}
}

void do_output_lwex0(FILE *of)
{
	int nskips = 0;		// used to output blanks for BSS inline
	int sn;
	int codedatasize = 0;
	unsigned char buf[32];
	
	// calculate items for the file header
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
		{
			// no output for a BSS section
			nskips += sectlist[sn].ptr -> codesize;
			continue;
		}
		codedatasize += nskips;
		nskips = 0;
		codedatasize += sectlist[sn].ptr -> codesize;
	}

	// output the file header
	buf[0] = 'L';
	buf[1] = 'W';
	buf[2] = 'E';
	buf[3] = 'X';
	buf[4] = 0;		// version 0
	buf[5] = 0;		// low stack
	buf[6] = linkscript.stacksize / 256;
	buf[7] = linkscript.stacksize & 0xff;
	buf[8] = nskips / 256;
	buf[9] = nskips & 0xff;
	buf[10] = codedatasize / 256;
	buf[11] = codedatasize & 0xff;
	buf[12] = linkscript.execaddr / 256;
	buf[13] = linkscript.execaddr & 0xff;
	memset(buf + 14, 0, 18);
	
	writebytes(buf, 1, 32, of);
	// output the data
	// NOTE: disjoint load addresses will not work correctly!!!!!
	nskips = 0;
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
		{
			// no output for a BSS section
			nskips += sectlist[sn].ptr -> codesize;
			continue;
		}
		while (nskips > 0)
		{
			// the "" is not an error - it turns into a single NUL byte!
			writebytes("", 1, 1, of);
			nskips--;
		}
		writebytes(sectlist[sn].ptr -> code, 1, sectlist[sn].ptr -> codesize, of);
	}
}

void os9crc(unsigned char crc[3], unsigned char b)
{
	b ^= crc[0];
	crc[0] = crc[1];
	crc[1] = crc[2];
	crc[1] ^= b >> 7;
	crc[2] = b << 1;
	crc[1] ^= b >> 2;
	crc[2] ^= b << 6;
	b ^= b << 1;
	b ^= b << 2;
	b ^= b << 4;
	if (b & 0x80)
	{
		crc[0] ^= 0x80;
		crc[2] ^= 0x21;
	}
}
 

void do_output_os9(FILE *of)
{
	int sn;
	int codedatasize = 0;
	int bsssize = 0;
	int nameoff;
	int i;
		
	unsigned char buf[16];
	unsigned char crc[3];
	
	// calculate items for the file header
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
		{
			// no output for a BSS section
			bsssize += sectlist[sn].ptr -> codesize;
			continue;
		}
		codedatasize += sectlist[sn].ptr -> codesize;
	}
	bsssize += linkscript.stacksize;

	// now bss size is the data size for the module
	// and codesize is the length of the module minus the module header
	// and CRC

	codedatasize += 13; // add in headers
	nameoff = codedatasize; // we'll put the name at the end
	codedatasize += 3;	// add in CRC
	codedatasize += strlen(linkscript.name); // add in name length
	if (linkscript.edition >= 0)
		codedatasize += 1;
	
	// output the file header
	buf[0] = 0x87;
	buf[1] = 0xCD;
	buf[2] = (codedatasize >> 8) & 0xff;
	buf[3] = codedatasize & 0xff;
	buf[4] = (nameoff >> 8) & 0xff;
	buf[5] = nameoff & 0xff;
	buf[6] = (linkscript.modtype << 4) | (linkscript.modlang);
	buf[7] = (linkscript.modattr << 4) | (linkscript.modrev);
	buf[8] = (~(buf[0] ^ buf[1] ^ buf[2] ^ buf[3] ^ buf[4] ^ buf[5] ^ buf[6] ^ buf[7])) & 0xff;
	buf[9] = (linkscript.execaddr >> 8) & 0xff;
	buf[10] = linkscript.execaddr & 0xff;
	buf[11] = (bsssize >> 8) & 0xff;
	buf[12] = bsssize & 0xff;
	
	crc[0] = 0xff;
	crc[1] = 0xff;
	crc[2] = 0xff;
	
	os9crc(crc, buf[0]);
	os9crc(crc, buf[1]);
	os9crc(crc, buf[2]);
	os9crc(crc, buf[3]);
	os9crc(crc, buf[4]);
	os9crc(crc, buf[5]);
	os9crc(crc, buf[6]);
	os9crc(crc, buf[7]);
	os9crc(crc, buf[8]);
	os9crc(crc, buf[9]);
	os9crc(crc, buf[10]);
	os9crc(crc, buf[11]);
	os9crc(crc, buf[12]);
	
	
	writebytes(buf, 1, 13, of);
	
	// output the data
	// NOTE: disjoint load addresses will not work correctly!!!!!
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
		{
			// no output for a BSS section
			continue;
		}
		writebytes(sectlist[sn].ptr -> code, 1, sectlist[sn].ptr -> codesize, of);
		for (i = 0; i < sectlist[sn].ptr -> codesize; i++)
			os9crc(crc, sectlist[sn].ptr -> code[i]);
	}
	
	// output the name
	for (i = 0; linkscript.name[i + 1]; i++)
	{
		writebytes(linkscript.name + i, 1, 1, of);
		os9crc(crc, linkscript.name[i]);
	}
	buf[0] = linkscript.name[i] | 0x80;
	writebytes(buf, 1, 1, of);
	os9crc(crc, buf[0]);
	
	if (linkscript.edition >= 0)
	{
		buf[0] = linkscript.edition & 0xff;
		writebytes(buf, 1, 1, of);
		os9crc(crc, buf[0]);
	}
	
	crc[0] ^= 0xff;
	crc[1] ^= 0xff;
	crc[2] ^= 0xff;
	writebytes(crc, 1, 3, of);
}

/*
UniFLEX binary executable format.

The UniFLEX binary header is 24 bytes:
  Offset  Size  Field   Description
  0       1     bhhdr   Header byte ($02 = binary)
  1       1     bhdes   Descriptor (bit0=RO text, bit1=absolute, bit2=no new mem)
  2       2     bhtxt   Text segment size
  4       2     bhdat   Initialized data size
  6       2     bhbss   BSS (uninitialized data) size
  8       2     bhrls   Relocation info size (0 for absolute)
  10      2     bhxfr   Transfer (entry) address
  12      2     bhstk   Stack size
  14      2     bhsym   Symbol table size (0)
  16      2     bhcom   Comments size (0)
  18      4     bhspr   Spare bytes (0)
  22      2     bhsrn   Serial number (0)

Sections named "text" or starting with "code" go into the text segment.
Sections named "data" or "rwdata" go into the data segment.
BSS-flagged sections go into the BSS segment.
Everything else goes into text.

The file layout after the header is: text bytes, then data bytes.
BSS is not stored in the file.
*/
void do_output_uniflex(FILE *of)
{
	int sn;
	int textsize = 0;
	int datasize = 0;
	int bsssize = 0;
	unsigned char buf[24];

	// calculate segment sizes
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
		{
			bsssize += sectlist[sn].ptr -> codesize;
			continue;
		}
		if (sectlist[sn].ptr -> name &&
		    (!strcasecmp((char *)sectlist[sn].ptr -> name, "data") ||
		     !strcasecmp((char *)sectlist[sn].ptr -> name, "rwdata")))
		{
			datasize += sectlist[sn].ptr -> codesize;
		}
		else
		{
			textsize += sectlist[sn].ptr -> codesize;
		}
	}

	// build the 24-byte binary header
	memset(buf, 0, 24);
	buf[0] = 0x02;		// bhhdr: binary header marker
	buf[1] = 0x00;		// bhdes: descriptor (0 = normal)
	buf[2] = (textsize >> 8) & 0xff;	// bhtxt high
	buf[3] = textsize & 0xff;			// bhtxt low
	buf[4] = (datasize >> 8) & 0xff;	// bhdat high
	buf[5] = datasize & 0xff;			// bhdat low
	buf[6] = (bsssize >> 8) & 0xff;		// bhbss high
	buf[7] = bsssize & 0xff;			// bhbss low
	buf[8] = 0x00;		// bhrls high (no relocation for now)
	buf[9] = 0x00;		// bhrls low
	buf[10] = (linkscript.execaddr >> 8) & 0xff;	// bhxfr high
	buf[11] = linkscript.execaddr & 0xff;			// bhxfr low
	buf[12] = (linkscript.stacksize >> 8) & 0xff;	// bhstk high
	buf[13] = linkscript.stacksize & 0xff;			// bhstk low
	// bytes 14-23: sym, com, spare, serial = all zero

	writebytes(buf, 1, 24, of);

	// output text sections
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
			continue;
		if (sectlist[sn].ptr -> name &&
		    (!strcasecmp((char *)sectlist[sn].ptr -> name, "data") ||
		     !strcasecmp((char *)sectlist[sn].ptr -> name, "rwdata")))
			continue;
		writebytes(sectlist[sn].ptr -> code, 1, sectlist[sn].ptr -> codesize, of);
	}

	// output data sections
	for (sn = 0; sn < nsects; sn++)
	{
		if (sectlist[sn].ptr -> flags & SECTION_BSS)
			continue;
		if (sectlist[sn].ptr -> name &&
		    (!strcasecmp((char *)sectlist[sn].ptr -> name, "data") ||
		     !strcasecmp((char *)sectlist[sn].ptr -> name, "rwdata")))
		{
			writebytes(sectlist[sn].ptr -> code, 1, sectlist[sn].ptr -> codesize, of);
		}
	}
}
