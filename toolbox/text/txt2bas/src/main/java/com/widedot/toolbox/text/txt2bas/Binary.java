package com.widedot.toolbox.text.txt2bas;

import java.util.List;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;

public class Binary implements ObjectDataInterface {

	public byte[] bytes;
	
	public Binary() {
		bytes = new byte[0];
	}

	@Override
	public byte[] getBytes() throws Exception {
		return bytes;
	}

	@Override
	public List<byte[]> getExportAbs() throws Exception {
		return null;
	}

	@Override
	public List<byte[]> getExportRel() throws Exception {
		return null;
	}

	@Override
	public List<byte[]> getIntern() throws Exception {
		return null;
	}

	@Override
	public List<byte[]> getExtern8() throws Exception {
		return null;
	}

	@Override
	public List<byte[]> getExtern16() throws Exception {
		return null;
	}

}
