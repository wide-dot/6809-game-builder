package com.widedot.m6809.gamebuilder.spi.media;

public interface MediaDataInterface {
	void write(String location, byte[] data) throws Exception;
	byte[] getBytes() throws Exception;
	void interleave() throws Exception;
}
