package com.widedot.toolbox.graphics.compiled.backupdrawerase.asm;

import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.gamebuilder.util.asm.Register;

public class Leau extends ASMCode {

	public Leau() {
	}

	public List<String> getCode (int offset) throws Exception {
		List<String> asmCode = new ArrayList<String>();		
		asmCode.add("\tLEAU "+offset+",U");
		return asmCode;
	}
	
	public int getCycles (int offset) throws Exception {
		int cycles = 0;
		cycles += Register.costIndexedLEA + Register.getIndexedOffsetCost(offset);
		return cycles;
	}
	
	public int getSize (int offset) throws Exception {
		int size = 0;
		size += Register.sizeIndexedLEA + Register.getIndexedOffsetSize(offset);
		return size;
	}
}

