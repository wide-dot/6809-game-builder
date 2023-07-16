package com.widedot.toolbox.text.txt2bas;

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
