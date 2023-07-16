package com.widedot.m6809.gamebuilder.plugin.bin;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;

public class Binary implements ObjectDataInterface {

	public byte[] bytes;
	
	public Binary() {
	}

	@Override
	public byte[] getBytes() throws Exception {
		return bytes;
	}

}
