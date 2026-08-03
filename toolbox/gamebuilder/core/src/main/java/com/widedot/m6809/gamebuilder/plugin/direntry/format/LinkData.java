package com.widedot.m6809.gamebuilder.plugin.direntry.format;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;

// load time link data
// -----------------------------------------------------------------------------------------------
//
// file link data :
//
//		- export absolute           ; export a 16 bit constant (will be processed as a 8 or 16 bits extern when applying value)
// 
//		03 0100 :    0002           ; [nb of elements]
//		             0047 0003      ; key of symbol, value of symbol
//		             0048 0004      ; key of symbol, value of symbol
//
//      - export relative           ; export a 16 bit relative constant (will be processed as a 8 or 16 bits extern when applying value)
//
//		03 0106 :    0001           ; [nb of elements]
//		             0059 0586      ; key of symbol, value of symbol (should add section base address to this value before applying)
//		             
//		- intern                    ; relocation of local variables
//		            
//		03 010A :    0001           ; [nb of elements]
//		             0162 00C3      ; [offset to write location] [PLUS operand] - example : intern ( I16=195 IS=\02code OP=PLUS ) @ 0162
//
//		- extern (8bit)             ; link to extern 8 bit variables
//		             
//		03 0122 :    0001           ; [nb of elements]
//		             0014 0000 0001 ; [offset to write location] [PLUS operand] [symbol id] - example : extern 8bit ( FLAGS=01 ES=ymm.NO_LOOP ) @ 0014
//
//		- extern (16bit)            ; link to extern 16 bit variables
//		             
//		03 0110 :    0002           ; [nb of elements]
//		             0001 FFF4 0002 ; [offset to write location] [PLUS operand] [symbol id] - example : extern ( I16=-12 ES=Obj_Index_Address OP=PLUS ) @ 0001
//		             003E 0000 0003 ;                                                                   extern ( ES=ymm.music.processFrame ) @ 003E
//
// custom link data :
//		             
//		- extern memory page (8bit) ; link to extern 8 bit variables that store memory page by file id
//		             
//		03 0122 :    0001           ; [nb of elements]
//		             0014 0000 0001 ; [offset to write location] [PLUS operand] [file id] - example : extern 8bit ( FLAGS=01 ES=music.stage1$PAGE ) @ 0014

public class LinkData {
	
	public byte[] data;
	private List<byte[]> exportAbs;
	private List<byte[]> exportRel;
	private List<byte[]> intern;
	private List<byte[]> extern8;
	private List<byte[]> extern16;
	private List<byte[]> externPage;
	
	public LinkData() {
		exportAbs = new ArrayList<byte[]>();
		exportRel = new ArrayList<byte[]>();
		intern = new ArrayList<byte[]>();
		extern8 = new ArrayList<byte[]>();
		extern16 = new ArrayList<byte[]>();
		externPage = new ArrayList<byte[]>();
	}
	
	/**
	 * Appends the link data of one object.
	 *
	 * A direntry may hold several objects, whose binaries are concatenated in
	 * the order they are added. Offsets produced by an object are relative to
	 * that object, so everything but the absolute exports has to be shifted by
	 * the total size of the objects added before it. Without this, only a first
	 * object bearing exports relocates correctly, which is what kept a group
	 * limited to a single meaningful member.
	 *
	 * @param obj  object to append
	 * @param base size of the objects already added
	 */
	public void add(ObjectDataInterface obj, int base) throws Exception {
		// absolute exports carry a value, not a position : never shifted
		exportAbs.addAll(obj.getExportAbs());

		exportRel.addAll(shift(obj.getExportRel(), base, 2));
		intern.addAll(shift(obj.getIntern(), base, 0));
		extern8.addAll(shift(obj.getExtern8(), base, 0));
		extern16.addAll(shift(obj.getExtern16(), base, 0));
		externPage.addAll(shift(obj.getExternPage(), base, 0));
	}

	public void add(ObjectDataInterface obj) throws Exception {
		add(obj, 0);
	}

	/**
	 * Adds base to the big endian word at position pos of every entry.
	 */
	private static List<byte[]> shift(List<byte[]> entries, int base, int pos) throws Exception {
		if (base == 0) return entries;

		List<byte[]> out = new ArrayList<byte[]>(entries.size());
		for (byte[] e : entries) {
			byte[] c = e.clone();
			int v = (((c[pos] & 0xff) << 8) | (c[pos+1] & 0xff)) + base;
			if (v > 0xffff) {
				throw new Exception("link data offset " + v + " does not fit 16 bits");
			}
			c[pos]   = (byte) ((v & 0xff00) >> 8);
			c[pos+1] = (byte) (v & 0xff);
			out.add(c);
		}
		return out;
	}
	
	public int countExportAbs()  { return exportAbs.size(); }
	public int countExportRel()  { return exportRel.size(); }
	public int countIntern()     { return intern.size(); }
	public int countExtern8()    { return extern8.size(); }
	public int countExtern16()   { return extern16.size(); }
	public int countExternPage() { return externPage.size(); }

	public void process() {
		int length =	2 + 4 * exportAbs.size() +
						2 + 4 * exportRel.size() +
						2 + 4 * intern.size() +
						2 + 6 * extern8.size() +
						2 + 6 * extern16.size() +
						2 + 6 * externPage.size();
		
		data = new byte[length];
		int i = 0;
		
		data[i++] = (byte) ((exportAbs.size() & 0xff00) >> 8);
		data[i++] = (byte) (exportAbs.size() & 0xff);
		byte[] flatExportAbs = exportAbs.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatExportAbs, 0, data, i, flatExportAbs.length);
		i += flatExportAbs.length;
		
		data[i++] = (byte) ((exportRel.size() & 0xff00) >> 8);
		data[i++] = (byte) (exportRel.size() & 0xff);
		byte[] flatExportRel = exportRel.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatExportRel, 0, data, i, flatExportRel.length);
		i += flatExportRel.length;
		
		data[i++] = (byte) ((intern.size() & 0xff00) >> 8);
		data[i++] = (byte) (intern.size() & 0xff);
		byte[] flatIntern = intern.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatIntern, 0, data, i, flatIntern.length);
		i += flatIntern.length;
		
		data[i++] = (byte) ((extern8.size() & 0xff00) >> 8);
		data[i++] = (byte) (extern8.size() & 0xff);
		byte[] flatExtern8 = extern8.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatExtern8, 0, data, i, flatExtern8.length);
		i += flatExtern8.length;
		
		data[i++] = (byte) ((extern16.size() & 0xff00) >> 8);
		data[i++] = (byte) (extern16.size() & 0xff);
		byte[] flatExtern16 = extern16.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatExtern16, 0, data, i, flatExtern16.length);
		i += flatExtern16.length;
		
		data[i++] = (byte) ((externPage.size() & 0xff00) >> 8);
		data[i++] = (byte) (externPage.size() & 0xff);
		byte[] flatExternPage = externPage.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatExternPage, 0, data, i, flatExternPage.length);
		i += flatExternPage.length;
	}
	
}
