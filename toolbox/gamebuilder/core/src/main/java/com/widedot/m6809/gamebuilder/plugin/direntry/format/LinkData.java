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
//		- export absolute                             ; export a 16 bit constant (will be processed as a 8 or 16 bits extern when applying value)
// 
//		03 0100 :    0002                             ; [nb of elements]
//		             0047 0003                        ; key of symbol, value of symbol
//		             0048 0004                        ; key of symbol, value of symbol
//
//      - export relative                             ; export a 16 bit relative constant (will be processed as a 8 or 16 bits extern when applying value)
//
//		03 0106 :    0001                             ; [nb of elements]
//		             0059 0586                        ; key of symbol, value of symbol (should add section base address to this value before applying)
//		             
//		- intern                                      ; relocation of local variables
//		            
//		03 010A :    0001                             ; [nb of elements]
//		             0162 00C3                        ; [offset to write location] [PLUS operand] - example : intern ( I16=195 IS=\02code OP=PLUS ) @ 0162
//
//		- extern (8bit)                               ; link to extern 8 bit variables
//		             
//		03 0122 :    0001                             ; [nb of elements]
//		             0014 0000 0001                   ; [offset to write location] [PLUS operand] [symbol id] - example : extern 8bit ( FLAGS=01 ES=ymm.NO_LOOP ) @ 0014
//
//		- extern (16bit)                              ; link to extern 16 bit variables
//		             
//		03 0110 :    0002                             ; [nb of elements]
//		             0001 FFF4 0002                   ; [offset to write location] [PLUS operand] [symbol id] - example : extern ( I16=-12 ES=Obj_Index_Address OP=PLUS ) @ 0001
//		             003E 0000 0003                   ;                                                            extern ( ES=ymm.music.processFrame ) @ 003E

public class LinkData {
	
	public byte[] data;
	private List<byte[]> exportAbs;
	private List<byte[]> exportRel;
	private List<byte[]> intern;
	private List<byte[]> extern8;
	private List<byte[]> extern16;
	
	public LinkData() {
		exportAbs = new ArrayList<byte[]>();
		exportRel = new ArrayList<byte[]>();
		intern = new ArrayList<byte[]>();
		extern8 = new ArrayList<byte[]>();
		extern16 = new ArrayList<byte[]>();
	}
	
	public void add(ObjectDataInterface obj) throws Exception {
		exportAbs.addAll(obj.getExportAbs());
		exportRel.addAll(obj.getExportRel());
		intern.addAll(obj.getIntern());
		extern8.addAll(obj.getExtern8());
		extern16.addAll(obj.getExtern16());
	}
	
	public void process() {
		int length =	2 + 4 * exportAbs.size() +
						2 + 4 * exportRel.size() +
						2 + 4 * intern.size() +
						2 + 6 * extern8.size() +
						2 + 6 * extern16.size();
		
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
	}
	
}
