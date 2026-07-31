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
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.globals.LinkSymbols;
import com.widedot.m6809.util.ByteUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LwObject implements ObjectDataInterface{

	public Path path;
	public List<LWSection> secLst;
	private LwMap lwMap; // Cache for the associated .lwmap file
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
	
	private final LinkSymbols linkSymbols;

	public LwObject(String filename, LinkSymbols linkSymbols) throws Exception {
		this.linkSymbols = linkSymbols;
		
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
		String LogText = ""; 
		
		while (true)
		{
			bss = 0;
			
			// bail out if no more sections
			if (CURBYTE()==0)
				break;
			
			fp = CURSTR();
			if (log.isDebugEnabled()) LogText += String.format("SECTION %s\n", fp);
			
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
					if (log.isDebugEnabled()) LogText += String.format("    FLAG: BSS\n");
					section.flags |= LWSection.SECTION_BSS;
					bss = 1;
					break;
				case 0x02:
					if (log.isDebugEnabled()) LogText += String.format("    FLAG: CONSTANT\n");
					section.flags |= LWSection.SECTION_CONST;
					break;
					
				default:
					if (log.isDebugEnabled()) LogText += String.format("    FLAG: %02X (unknown)\n", CURBYTE());
					break;
				}
				NEXTBYTE();
			}
			// skip NUL terminating flags
			NEXTBYTE();
			
			if (log.isDebugEnabled()) LogText += String.format("    Local symbols:\n");
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
				
				if (log.isDebugEnabled()) LogText += String.format("        %s=%04X\n", string_cleanup(fp), val);
				
				// create symbol table entry
				Symbol sbl = new Symbol();
				section.localsyms.add(sbl);
				sbl.sym = fp;
				sbl.offset = val;
				
			}
			// skip terminating NUL
			NEXTBYTE();

			if (log.isDebugEnabled()) LogText += String.format("    Exported symbols\n");
					
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
				
				if (log.isDebugEnabled()) LogText += String.format("        %s=%04X\n", string_cleanup(fp), val);
				
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
			if (log.isDebugEnabled()) LogText += String.format("    Incomplete references\n");
			
			while (CURBYTE()!=0)
			{
				if (log.isDebugEnabled()) LogText += String.format("        (");
				
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
						if (log.isDebugEnabled()) LogText += String.format(" I16=%d", tt);
						term = new LWExprTerm(tt, LWExprTerm.LW_TERM_INT);
						break;
					
					case 0x02:
						// external symbol reference
						fp = CURSTR();
						if (log.isDebugEnabled()) LogText += String.format(" ES=%s", string_cleanup(fp));
						term = new LWExprTerm(fp, 0);
						break;
						
					case 0x03:
						// internal symbol reference
						fp = CURSTR();
						if (log.isDebugEnabled()) LogText += String.format(" IS=%s", string_cleanup(fp));
						term = new LWExprTerm(fp, 1);
						break;
					
					case 0x04:
						// operator
						if (CURBYTE() > 0 && CURBYTE() <= numopers) {
							if (log.isDebugEnabled()) LogText += String.format(" OP=%s", opernames[CURBYTE()]);
						} else {
							if (log.isDebugEnabled()) LogText += String.format(" OP=?");
						}
						term = new LWExprTerm(CURBYTE(), LWExprTerm.LW_TERM_OPER);
						NEXTBYTE();
						break;

					case 0x05:
						// section base reference (NULL internal reference is
						// the section base address
						if (log.isDebugEnabled()) LogText += String.format(" SB");
						term = new LWExprTerm(null, 1);
						break;
					
					case 0xFF:
						// reloc flags (1 means 8 bits)
						if (log.isDebugEnabled()) LogText += String.format(" FLAGS=%02X", CURBYTE());
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
				
				if (log.isDebugEnabled()) LogText += String.format(" ) @ %04X\n", val);
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
			
			if (log.isDebugEnabled()) LogText += String.format("    CODE %04X bytes", section.codesize);
			
			// skip the code if we're not in a BSS section
			if (bss==0)
			{
				int i;
				for (i = 0; i < section.codesize; i++)
				{
					if ((i % 16)==0)
					{
						if (log.isDebugEnabled()) LogText += String.format("\n    %04X ", i);
					}
					if (log.isDebugEnabled()) LogText += String.format("%02X", CURBYTE());
					section.code[i] = (byte) CURBYTE();
					NEXTBYTE();
				}
			}
			if (log.isDebugEnabled()) LogText += String.format("\n");
			log.debug("{}", LogText);
			if (log.isDebugEnabled()) LogText = "";
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

	/**
	 * Get the associated LwMap file for this object file
	 * @return LwMap instance or null if the map file doesn't exist
	 */
	private LwMap getLwMap() {
		if (lwMap == null) {
			try {
				// Convert .o file path to .lwmap path
				String mapFilename = path.toString().replaceAll("\\.obj$", ".lwmap");
				lwMap = new LwMap(mapFilename);
			} catch (Exception e) {
				log.debug("Could not load LwMap file for {}: {}", path, e.getMessage());
				// Return null lwMap - will be handled gracefully
			}
		}
		return lwMap;
	}

	@SuppressWarnings("unchecked")
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
	
	private List<byte[]> exportAbs;

	@Override
	public List<byte[]> getExportAbs() throws Exception {
		
		if (exportAbs == null) {
			exportAbs = new ArrayList<byte[]>();
			for (LWSection section : secLst) {
				if (section.flags == LWSection.SECTION_CONST) {
					for (Symbol symbol : section.exportedsyms) {
						
						int symid = linkSymbols.export(symbol.sym, path.getFileName().toString());
						
						byte[] val = new byte[4];
						val[0] = (byte) ((symid & 0xff00) >> 8);
						val[1] = (byte) (symid & 0xff);
						val[2] = (byte) ((symbol.offset & 0xff00) >> 8);
						val[3] = (byte) (symbol.offset & 0xff);
						
						log.debug("EXPORTABS: {}:{} {}", symbol.sym, symid, ByteUtil.bytesToHex(val));
						exportAbs.add(val);
					}
				}
			}
		}
		return exportAbs;
	}

	private List<byte[]> exportRel;
	
	@Override
	public List<byte[]> getExportRel() throws Exception {
		
		if (exportRel == null) {
			exportRel = new ArrayList<byte[]>();
			for (LWSection section : secLst) {
				if (section.flags != LWSection.SECTION_CONST) {
					int base = sectionBase(section);
					for (Symbol symbol : section.exportedsyms) {
						
						int symid = linkSymbols.export(symbol.sym, path.getFileName().toString());
						int offset = base + symbol.offset;
						
						byte[] val = new byte[4];
						val[0] = (byte) ((symid & 0xff00) >> 8);
						val[1] = (byte) (symid & 0xff);
						val[2] = (byte) ((offset & 0xff00) >> 8);
						val[3] = (byte) (offset & 0xff);
						
						log.debug("EXPORTREL: {}:{} {}", symbol.sym, symid, ByteUtil.bytesToHex(val));
						
						exportRel.add(val);
					}
				}
			}
		}
		return exportRel;
	}

	/**
	 * Result of evaluating the expression attached to an incomplete reference.
	 * lwasm folds these into a single symbol plus a constant, which is all the
	 * 6809 loader knows how to apply.
	 */
	private static class RelocValue {
		int value;        // the PLUS constant
		String symbol;    // "" when the expression carries no symbol
		boolean internal; // resolved inside this object, not by the loader
	}

	/**
	 * Evaluates one incomplete reference. Shared by the four emitters so that
	 * they cannot drift apart in what they accept: a single symbol, a single
	 * constant and at most one PLUS.
	 */
	/**
	 * Offset of a section inside the binary returned by getBytes(), which
	 * concatenates them in this order. Relocation and symbol offsets are
	 * section relative, so they must be shifted by this base : without it a
	 * second code-bearing section relocates at the wrong place.
	 */
	private int sectionBase(LWSection target) {
		int base = 0;
		for (LWSection section : secLst) {
			if (section == target) return base;
			base += section.code.length;
		}
		return base;
	}

	private RelocValue evalReloc(Reloc reloc) throws Exception {
		RelocValue r = new RelocValue();
		r.symbol = "";

		int opers = 0, ints = 0, syms = 0;

		LWExprStackNode node = reloc.expr.head;
		while (node != null) {
			switch (node.term.term_type) {
				case LWExprTerm.LW_TERM_INT:
					if (++ints > 1) {
						throw new Exception("expression with several constants is not supported"
								+ " at offset " + reloc.offset);
					}
					r.value = node.term.value;
					break;

				case LWExprTerm.LW_TERM_SYM:
					if (++syms > 1) {
						throw new Exception("expression with several symbols is not supported"
								+ " at offset " + reloc.offset + " (second one is "
								+ node.term.symbol + ")");
					}
					r.symbol = node.term.symbol == null ? "" : node.term.symbol;
					// value 1 marks a symbol of this object, 0 an imported one
					r.internal = (node.term.value == 1);
					break;

				case LWExprTerm.LW_TERM_OPER:
					// check the operator before using it as an index, an unknown
					// one used to throw ArrayIndexOutOfBounds instead of saying so
					if (node.term.value < 0 || node.term.value > numopers) {
						throw new Exception("unknown operator " + node.term.value
								+ " at offset " + reloc.offset);
					}
					if (node.term.value != LWExprTerm.LW_OPER_PLUS) {
						throw new Exception("unsupported operator type: " + opernames[node.term.value]);
					}
					if (++opers > 1) {
						throw new Exception("multiple PLUS operator is not supported");
					}
					break;

				default:
					throw new Exception("unexpected term type: " + node.term.term_type);
			}
			node = node.next;
		}

		return r;
	}

	private List<byte[]> intern;

	@Override
	public List<byte[]> getIntern() throws Exception {

		if (intern == null) {
			intern = new ArrayList<byte[]>();
			for (LWSection section : secLst) {
				int base = sectionBase(section);
				for (Reloc reloc : section.incompletes) {

					// only 16 bit relocations : an 8 bit one emitted here would
					// be applied as a word by the loader and clobber the next byte
					if (reloc.flags != 0) continue;

					RelocValue r = evalReloc(reloc);
					if (!r.internal && !r.symbol.isEmpty()) continue; // imported, not ours

					int offset = base + reloc.offset;
					byte[] val = new byte[4];
					val[0] = (byte) ((offset & 0xff00) >> 8);
					val[1] = (byte) (offset & 0xff);
					val[2] = (byte) ((r.value & 0xff00) >> 8);
					val[3] = (byte) (r.value & 0xff);

					log.debug("INTERN   : {}", ByteUtil.bytesToHex(val));
					intern.add(val);
				}
			}
		}

		return intern;
	}
	
	private List<byte[]> extern8;

	@Override
	public List<byte[]> getExtern8() throws Exception {

		if (extern8 == null) {
			extern8 = new ArrayList<byte[]>();
			for (LWSection section : secLst) {
				int base = sectionBase(section);
				for (Reloc reloc : section.incompletes) {

					if (reloc.flags != 1) continue; // 8 bit relocations only

					RelocValue r = evalReloc(reloc);
					if (r.internal) continue;                 // resolved locally
					if (r.symbol.isEmpty()) continue;         // nothing to import
					if (r.symbol.endsWith("$PAGE")) continue; // handled as a page reference

					int symid = linkSymbols.add(r.symbol);

					int offset = base + reloc.offset;
					byte[] val = new byte[6];
					val[0] = (byte) ((offset & 0xff00) >> 8);
					val[1] = (byte) (offset & 0xff);
					val[2] = (byte) ((r.value & 0xff00) >> 8);
					val[3] = (byte) (r.value & 0xff);
					val[4] = (byte) ((symid & 0xff00) >> 8);
					val[5] = (byte) (symid & 0xff);

					log.debug("EXTERN8  : {}:{} {}", r.symbol, symid, ByteUtil.bytesToHex(val));
					extern8.add(val);
				}
			}
		}

		return extern8;
	}

	private List<byte[]> extern16;
	
	@Override
	public List<byte[]> getExtern16() throws Exception {

		if (extern16 == null) {
			extern16 = new ArrayList<byte[]>();
			for (LWSection section : secLst) {
				int base = sectionBase(section);
				for (Reloc reloc : section.incompletes) {

					if (reloc.flags != 0) continue; // 16 bit relocations only

					RelocValue r = evalReloc(reloc);
					if (r.internal) continue;                 // resolved locally
					if (r.symbol.isEmpty()) continue;         // nothing to import
					// a 16 bit reference to xxx$PAGE has no exporter : it used to
					// be emitted here and silently resolved to 0 at load time
					if (r.symbol.endsWith("$PAGE")) {
						throw new Exception("symbol " + r.symbol + " is a page reference,"
								+ " it can only be used as an 8 bit operand (offset "
								+ reloc.offset + ")");
					}

					int symid = linkSymbols.add(r.symbol);

					int offset = base + reloc.offset;
					byte[] val = new byte[6];
					val[0] = (byte) ((offset & 0xff00) >> 8);
					val[1] = (byte) (offset & 0xff);
					val[2] = (byte) ((r.value & 0xff00) >> 8);
					val[3] = (byte) (r.value & 0xff);
					val[4] = (byte) ((symid & 0xff00) >> 8);
					val[5] = (byte) (symid & 0xff);

					log.debug("EXTERN16 : {}:{} {}", r.symbol, symid, ByteUtil.bytesToHex(val));
					extern16.add(val);
				}
			}
		}

		return extern16;
	}	

	private List<byte[]> externPage;
	
	@Override
	public List<byte[]> getExternPage() throws Exception {

		if (externPage == null) {
			externPage = new ArrayList<byte[]>();
			for (LWSection section : secLst) {
				int base = sectionBase(section);
				for (Reloc reloc : section.incompletes) {

					if (reloc.flags != 1) continue; // 8 bit operand holds a page

					RelocValue r = evalReloc(reloc);
					if (r.internal) continue;
					if (!r.symbol.endsWith("$PAGE")) continue;

					// Extract the file identifier from the .lwmap file
					String fileIdentifier = r.symbol.substring(0, r.symbol.length() - 5);

					LwMap map = getLwMap();
					if (map == null) {
						throw new Exception("Could not load .lwmap file for file ID lookup of symbol: " + fileIdentifier);
					}

					Integer symbolValue = map.getSymbolValue(fileIdentifier);
					if (symbolValue == null) {
						throw new Exception("File ID not found in .lwmap for symbol: " + fileIdentifier);
					}

					int fileId = symbolValue;
					log.debug("Found file ID for '{}': {}", fileIdentifier, fileId);

					int offset = base + reloc.offset;
					byte[] val = new byte[6];
					val[0] = (byte) ((offset & 0xff00) >> 8);
					val[1] = (byte) (offset & 0xff);
					val[2] = (byte) ((r.value & 0xff00) >> 8);
					val[3] = (byte) (r.value & 0xff);
					val[4] = (byte) ((fileId & 0xff00) >> 8);
					val[5] = (byte) (fileId & 0xff);

					log.debug("EXTERNPAGE: {}:{} {}", r.symbol, fileId, ByteUtil.bytesToHex(val));
					externPage.add(val);
				}
			}
		}

		return externPage;
	}

}