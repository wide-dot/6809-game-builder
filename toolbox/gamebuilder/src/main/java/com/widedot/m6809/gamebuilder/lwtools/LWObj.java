package com.widedot.m6809.gamebuilder.lwtools;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.gamebuilder.lwtools.struct.LWExprStack;
import com.widedot.m6809.gamebuilder.lwtools.struct.LWExprTerm;
import com.widedot.m6809.gamebuilder.lwtools.struct.Reloc;
import com.widedot.m6809.gamebuilder.lwtools.struct.Section;
import com.widedot.m6809.gamebuilder.lwtools.struct.Symbol;

public class LWObj {

	public byte[] filedata;
	public int cc;
	
	public List<Section> secLst;
	
	public static byte[] MAGIC_NUMBER = {0x4C, 0x57, 0x4F, 0x42, 0x4A, 0x31, 0x36, 0x00};
	public static String[] opernames = {
			"?",
			"PLUS",
			"MINUS",
			"TIMES",
			"DIVIDE",
			"MOD",
			"INTDIV",
			"BWAND",
			"BWOR",
			"BWXOR",
			"AND",
			"OR",
			"NEG",
			"COM"
		};
	public static final int numopers = 13;
	
	public static void main(String[] args) throws Exception {
		new LWObj("C:\\Users\\bhrou\\git\\builder-v2\\build\\boot\\fd.o");
	}
	
	public LWObj(String fileName) throws Exception {
		Path path = Paths.get(fileName);
		filedata = Files.readAllBytes(path);
		
		if (filedata.length < MAGIC_NUMBER.length) {
			throw new Exception("Invalid LW object file : " + fileName);
		}
		
		for (int i=0; i < MAGIC_NUMBER.length; i++) {
			if (MAGIC_NUMBER[i] != filedata[i])
				throw new Exception("Invalid LW object file : " + fileName);
		}
		
		read_lwobj16v0();
	}
	
	public String string_cleanup(String sym) {
		String symbuf = "";
		
		for (int i=0; i<sym.length(); i++)
		{
			int in = sym.charAt(i) & 0xff;
			
			if (in < 33 || in > 126)
			{
				byte c;
				symbuf += '\\';
				c = (byte) (in >> 4);
				c+= 48;
				if (c > 57)
					c += 7;
				symbuf += new String(new byte[] {(byte) c}, StandardCharsets.UTF_8);
				c = (byte) (sym.charAt(i) & 15);
				c += 48;
				if (c > 57)
					c += 7;
				symbuf += new String(new byte[] {(byte) c}, StandardCharsets.UTF_8);
			}
			else if (in == '\\')
			{
				symbuf += '\\';
				symbuf += '\\';
			}
			else
			{
				symbuf += sym.charAt(i);
			}
		}
		
		return symbuf;
	}
	
	private void NEXTBYTE() throws Exception	{
		cc++;
		if (cc > filedata.length) throw new Exception ("***invalid file format\n");
	}
	
	private int CURBYTE() {
		return filedata[(cc<filedata.length?cc:filedata.length-1)] & 0xff;
	}
	
	private String CURSTR() throws Exception {
		String fp = "";
		while (CURBYTE()!=0) {
			fp += new String(new byte[] {(byte) CURBYTE()}, StandardCharsets.UTF_8);
			NEXTBYTE();
		}
		NEXTBYTE(); // go past the null terminator of the string in the file
		return fp;
	}
	
	private void read_lwobj16v0() throws Exception
	{
		String fp;
		int val;
		int bss;
			
		// start reading *after* the magic number
		cc = 8;
		
		// init data
		secLst = new ArrayList<Section>();
		
		while (true)
		{
			bss = 0;
			
			// bail out if no more sections
			if (CURBYTE()==0)
				break;
			
			fp = CURSTR();
			System.out.printf("SECTION %s\n", fp);
			
			// we now have a section name in fp
			// create new section entry
			Section section = new Section();
			secLst.add(section);
			
			section.localsyms = null;
			section.flags = 0;
			section.codesize = 0;
			section.name = fp;
			section.loadaddress = 0;
			section.localsyms = new ArrayList<Symbol>();
			section.exportedsyms = new ArrayList<Symbol>();
			section.incompletes = new ArrayList<Reloc>();
			section.processed = 0;
			section.afterbytes = null;
			section.aftersize = 0;
			
			// read flags
			while (CURBYTE()!=0)
			{
				switch (CURBYTE())
				{
				case 0x01:
					System.out.printf("    FLAG: BSS\n");
					section.flags |= Section.SECTION_BSS;
					bss = 1;
					break;
				case 0x02:
					System.out.printf("    FLAG: CONSTANT\n");
					section.flags |= Section.SECTION_CONST;
					break;
					
				default:
					System.out.printf("    FLAG: %02X (unknown)\n", CURBYTE());
					break;
				}
				NEXTBYTE();
			}
			// skip NUL terminating flags
			NEXTBYTE();
			
			System.out.printf("    Local symbols:\n");
			// now parse the local symbol table
			while (CURBYTE()!=0)
			{
				fp = CURSTR();

				// fp is the symbol name
				val = (CURBYTE()) << 8;
				NEXTBYTE();
				val |= (CURBYTE());
				NEXTBYTE();
				// val is now the symbol value
				
				System.out.printf("        %s=%04X\n", string_cleanup(fp), val);
				
				// create symbol table entry
				Symbol sbl = new Symbol();
				section.localsyms.add(sbl);
				sbl.sym = fp;
				sbl.offset = val;
				
			}
			// skip terminating NUL
			NEXTBYTE();

			System.out.printf("    Exported symbols\n");
					
			// now parse the exported symbol table
			while (CURBYTE()!=0)
			{
				fp = CURSTR();

				// fp is the symbol name
				val = (CURBYTE()) << 8;
				NEXTBYTE();
				val |= (CURBYTE());
				NEXTBYTE();
				// val is now the symbol value
				
				System.out.printf("        %s=%04X\n", string_cleanup(fp), val);
				
				// create symbol table entry
				Symbol sbl = new Symbol();
				section.exportedsyms.add(sbl);
				sbl.sym = fp;
				sbl.offset = val;
			}
			// skip terminating NUL
			NEXTBYTE();
			
			// now parse the incomplete references and make a list of
			// external references that need resolution
			System.out.printf("    Incomplete references\n");
			while (CURBYTE()!=0)
			{
				System.out.printf("        (");
				
				LWExprTerm term = null;
				
				// we have a reference
				Reloc rel = new Reloc();
				section.incompletes.add(rel);
				rel.offset = 0;
				rel.expr = new LWExprStack();
				rel.flags = Reloc.RELOC_NORM;
				
				// parse the expression
				while (CURBYTE()!=0)
				{
					int tt = CURBYTE();
					NEXTBYTE();
					switch (tt)
					{
					case 0x01:
						// 16 bit integer
						tt = CURBYTE() << 8;
						NEXTBYTE();
						tt |= CURBYTE();
						NEXTBYTE();
						// normalize for negatives...
						if (tt > 0x7fff)
							tt -= 0x10000;
						System.out.printf(" I16=%d", tt);
						break;
					
					case 0x02:
						// external symbol reference
						System.out.printf(" ES=%s", string_cleanup(CURSTR()));
						break;
						
					case 0x03:
						// internal symbol reference
						System.out.printf(" IS=%s", string_cleanup(CURSTR()));
						break;
					
					case 0x04:
						// operator
						if (CURBYTE() > 0 && CURBYTE() <= numopers)
							System.out.printf(" OP=%s", opernames[CURBYTE()]);
						else
							System.out.printf(" OP=?");
						NEXTBYTE();
						break;

					case 0x05:
						// section base reference (NULL internal reference is
						// the section base address
						System.out.printf(" SB");
						break;
					
					case 0xFF:
						// section flags
						System.out.printf(" FLAGS=%02X", CURBYTE());
						NEXTBYTE();
						break;
						
					default:
						System.out.printf(" ERR");
					}
				}
				// skip the NUL
				NEXTBYTE();
				
				// fetch the offset
				val = CURBYTE() << 8;
				NEXTBYTE();
				val |= CURBYTE() & 0xff;
				NEXTBYTE();
				System.out.printf(" ) @ %04X\n", val);
			}
			// skip the NUL terminating the relocations
			NEXTBYTE();
					
			// now set code location and size and verify that the file
			// contains data going to the end of the code (if !SECTION_BSS)
			val = CURBYTE() << 8;
			NEXTBYTE();
			val |= CURBYTE();
			NEXTBYTE();
			
			System.out.printf("    CODE %04X bytes", val);
			
			// skip the code if we're not in a BSS section
			if (bss==0)
			{
				int i;
				for (i = 0; i < val; i++)
				{
					if ((i % 16)==0)
					{
						System.out.printf("\n    %04X ", i);
					}
					System.out.printf("%02X", CURBYTE());
					NEXTBYTE();
				}
			}
			System.out.printf("\n");
		}
	}

}