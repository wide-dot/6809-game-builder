package com.widedot.m6809.gamebuilder.plugin.bin;

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
	public List<byte[]> getExportedConst() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getExported() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getInternal() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getIncomplete8() throws Exception {
		return new ArrayList<byte[]>();
	}

	@Override
	public List<byte[]> getIncomplete16() throws Exception {
		return new ArrayList<byte[]>();
	}

}
