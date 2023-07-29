package com.widedot.m6809.gamebuilder.plugin.direntry.format;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;

// load time link data
// -----------------------------------------------------------------------------------------------
//
// file link data :
//
//		- exported constant
//
//		03 0100 :    0002                             ; [nb of elements]
//		             0003                             ; value of symbol 1
//		             0004                             ; value of symbol 2
//
//		- exported
//
//		03 0106 :    0001                             ; [nb of elements]
//		             0586                             ; value of symbol 0 (should add section base address to this value before applying)
//		             
//		- local                                       ; relocation of local variables
//		            
//		03 010A :    0001                             ; [nb of elements]
//		             0162 00C3                        ; [dest offset] [val offset] - example : internal ( I16=195 IS=\02code OP=PLUS ) @ 0162
//
//		- incomplete (8bit)
//		             
//		03 0122 :    0001                             ; [nb of elements]
//		             0014 0000 0003 0001              ; [dest offset] [val offset] [id block] [id ref] - example : external 8bit ( FLAGS=01 ES=ymm.NO_LOOP ) @ 0014
//
//		- incomplete (16bit)
//		             
//		03 0110 :    0002                             ; [nb of elements]
//		             0001 FFF4 0003 0001              ; [dest offset] [val offset] [id block] [id ref] - example : external ( I16=-12 ES=Obj_Index_Address OP=PLUS ) @ 0001
//		             003E 0000 0003 0002              ;                                                            external ( ES=ymm.music.processFrame ) @ 003E

public class LinkData {
	
	public byte[] data;
	private List<byte[]> exportedConst;
	private List<byte[]> exported;
	private List<byte[]> internal;
	private List<byte[]> incomplete8;
	private List<byte[]> incomplete16;
	
	public LinkData() {
		exportedConst = new ArrayList<byte[]>();
		exported = new ArrayList<byte[]>();
		internal = new ArrayList<byte[]>();
		incomplete8 = new ArrayList<byte[]>();
		incomplete16 = new ArrayList<byte[]>();
	}
	
	public void add(ObjectDataInterface obj) throws Exception {
		exportedConst.addAll(obj.getExportedConst());
		exported.addAll(obj.getExported());
		internal.addAll(obj.getInternal());
		incomplete8.addAll(obj.getIncomplete8());
		incomplete16.addAll(obj.getIncomplete16());
	}
	
	public void process() {
		int length =	2 + 2 * exportedConst.size() +
						2 + 2 * exported.size() +
						2 + 4 * internal.size() +
						2 + 8 * incomplete8.size() +
						2 + 8 * incomplete16.size();
		
		data = new byte[length];
		int i = 0;
		
		data[i++] = (byte) ((exportedConst.size() & 0xff00) >> 8);
		data[i++] = (byte) (exportedConst.size() & 0xff);
		byte[] flatExportedConst = exportedConst.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatExportedConst, 0, data, i, flatExportedConst.length);
		i += flatExportedConst.length;
		
		data[i++] = (byte) ((exported.size() & 0xff00) >> 8);
		data[i++] = (byte) (exported.size() & 0xff);
		byte[] flatExported = exported.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatExported, 0, data, i, flatExported.length);
		i += flatExported.length;
		
		data[i++] = (byte) ((internal.size() & 0xff00) >> 8);
		data[i++] = (byte) (internal.size() & 0xff);
		byte[] flatInternal = internal.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatInternal, 0, data, i, flatInternal.length);
		i += flatInternal.length;
		
		data[i++] = (byte) ((incomplete8.size() & 0xff00) >> 8);
		data[i++] = (byte) (incomplete8.size() & 0xff);
		byte[] flatIncomplete8 = incomplete8.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatIncomplete8, 0, data, i, flatIncomplete8.length);
		i += flatIncomplete8.length;
		
		data[i++] = (byte) ((incomplete16.size() & 0xff00) >> 8);
		data[i++] = (byte) (incomplete16.size() & 0xff);
		byte[] flatIncomplete16 = incomplete16.stream().collect(() -> new ByteArrayOutputStream(), (b, e) -> b.write(e, 0, e.length), (a, b) -> {}).toByteArray();
		System.arraycopy(flatIncomplete16, 0, data, i, flatIncomplete16.length);
		i += flatIncomplete16.length;
	}
	
}
