package com.widedot.m6809.gamebuilder.spi;

/**
 * Plain binary data with no link information, which is what every producer
 * other than the assembler returns. This used to be copied verbatim into each
 * plugin.
 */
public class Binary implements ObjectDataInterface {

	private final byte[] bytes;

	public Binary(byte[] bytes) {
		this.bytes = bytes;
	}

	@Override
	public byte[] getBytes() {
		return bytes;
	}
}
