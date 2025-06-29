package com.widedot.toolbox.audio.vgm2sfx;

import java.util.ArrayList;
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
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getExportRel() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getIntern() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getExtern8() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getExtern16() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getExternPage() throws Exception {
		return new ArrayList<byte[]>();
	}

}
