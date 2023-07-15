package com.widedot.m6809.gamebuilder.plugin.bin;

import com.widedot.m6809.gamebuilder.spi.ObjectDataType;

public class Binary implements ObjectDataType {

	public byte[] bytes;
	
	public Binary() {
	}

	@Override
	public byte[] getBytes() throws Exception {
		return bytes;
	}

}
