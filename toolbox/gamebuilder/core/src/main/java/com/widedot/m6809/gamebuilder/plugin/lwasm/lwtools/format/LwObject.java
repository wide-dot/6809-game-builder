package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.nio.charset.StandardCharsets;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.struct.LWExprStack;
import com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.struct.LWExprStackNode;
import com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.struct.LWExprTerm;
import com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.struct.Reloc;
import com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.struct.LWSection;
import com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.struct.Symbol;
import com.widedot.m6809.gamebuilder.spi.ObjectDataType;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LwObject implements ObjectDataType{

	public Path path;
	public List<LWSection> secLst;
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
	
	private byte[] filedata;
	byte[] bin; // contains all sections data as ordered by lwasm
	private int cc;
	private static final int numopers = 13;
	
	public LwObject(String filename) throws Exception {
		
		path = Paths.get(filename);
		
		// do not use cache here, performance is worst by a factor of 7x
		//if (!loadCache(fileName))
		{
			filedata = Files.readAllBytes(path);

			if (filedata.length < MAGIC_NUMBER.length)
			{
				throw new Exception("Invalid LW object file : " + filename);
			}
			
			for (int i=0; i < MAGIC_NUMBER.length; i++)
			{
				if (MAGIC_NUMBER[i] != filedata[i]) 
					throw new Exception("Invalid LW object file : " + filename);
			}
			
			read_lwobj16v0();
			//saveCache(fileName);
		}
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
		secLst = new ArrayList<LWSection>();
		
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
			LWSection section = new LWSection();
			secLst.add(section);
			
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
					section.flags |= LWSection.SECTION_BSS;
					bss = 1;
					break;
				case 0x02:
					System.out.printf("    FLAG: CONSTANT\n");
					section.flags |= LWSection.SECTION_CONST;
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
						if (tt > 0x7fff) tt -= 0x10000;
						System.out.printf(" I16=%d", tt);
						term = new LWExprTerm(tt, LWExprTerm.LW_TERM_INT);
						break;
					
					case 0x02:
						// external symbol reference
						fp = CURSTR();
						System.out.printf(" ES=%s", string_cleanup(fp));
						term = new LWExprTerm(fp, 0);
						break;
						
					case 0x03:
						// internal symbol reference
						fp = CURSTR();
						System.out.printf(" IS=%s", string_cleanup(fp));
						term = new LWExprTerm(fp, 1);
						break;
					
					case 0x04:
						// operator
						if (CURBYTE() > 0 && CURBYTE() <= numopers) {
							System.out.printf(" OP=%s", opernames[CURBYTE()]);
						} else {
							System.out.printf(" OP=?");
						}
						term = new LWExprTerm(tt, LWExprTerm.LW_TERM_OPER);
						NEXTBYTE();
						break;

					case 0x05:
						// section base reference (NULL internal reference is
						// the section base address
						System.out.printf(" SB");
						term = new LWExprTerm(null, 1);
						break;
					
					case 0xFF:
						// reloc flags (1 means 8 bits)
						System.out.printf(" FLAGS=%02X", CURBYTE());
						tt = CURBYTE();
						rel.flags = tt;
						NEXTBYTE();
						term = null;
						break;
						
					default:
						throw new Exception (String.format("%s (%s): bad relocation expression (%02X)\n", path.toString(), section.name, tt));
					}
					
					if (term != null) {
						lw_expr_stack_push(rel.expr, term);
					}
					
				}
				// skip the NUL
				NEXTBYTE();
				
				// fetch the offset
				val = CURBYTE() << 8;
				NEXTBYTE();
				val |= CURBYTE();
				rel.offset = val;
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
			section.codesize = val;
			NEXTBYTE();
			
			section.code = new byte[section.codesize];
			
			System.out.printf("    CODE %04X bytes", section.codesize);
			
			// skip the code if we're not in a BSS section
			if (bss==0)
			{
				int i;
				for (i = 0; i < section.codesize; i++)
				{
					if ((i % 16)==0)
					{
						System.out.printf("\n    %04X ", i);
					}
					System.out.printf("%02X", CURBYTE());
					section.code[i] = (byte) CURBYTE();
					NEXTBYTE();
				}
			}
			System.out.printf("\n");
		}
	}
	

	private void lw_expr_stack_push(LWExprStack s, LWExprTerm t) throws Exception
	{
		LWExprStackNode n;

		if (s == null)
		{
			throw new Exception();
		}
		
		n = new LWExprStackNode();
		n.next = null;
		n.prev = s.tail;
		n.term = new LWExprTerm(t.symbol, t.value, t.term_type);
		
		if (s.head != null)
		{
			s.tail.next = n;
			s.tail = n;
		}
		else
		{
			s.head = n;
			s.tail = n;
		}
	}

	public boolean loadCache(String fileName) {
		
		log.debug(fileName);
		
		String serFileName = fileName+".ser";
		File serFile = new File(serFileName);
        long serTime = serFile.lastModified();
        
        if (serTime == 0L) return false;
        
		File file = new File(fileName);
        long time = file.lastModified();
        
        if (serTime < time) return false;
		
        try {
            FileInputStream fileIn = new FileInputStream(serFileName);
            ObjectInputStream in = new ObjectInputStream(fileIn);
            secLst = (List<LWSection>) in.readObject();
            in.close();
            fileIn.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
		return true;
	}
	
	public void saveCache(String fileName) {	
        try {
            FileOutputStream fileOut = new FileOutputStream(fileName+".ser");
            ObjectOutputStream out = new ObjectOutputStream(fileOut);
            out.writeObject(secLst);
            out.close();
            fileOut.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
	}

	@Override
	public byte[] getBytes() throws Exception {

		if (bin == null) {
			int length = 0;
			for(LWSection section : secLst) {
				length += section.code.length;
			}
			
			bin = new byte[length];
			int outpos = 0;
			for(LWSection section : secLst) {
				for (int i=0; i<section.code.length; i++) {
					bin[outpos++] = section.code[i];
				}
			}
		}
		
		return bin;
	}

}