package com.widedot.m6809.gamebuilder.spi.media;

public interface MediaDataInterface {
	byte[] write(String location, byte[] data) throws Exception;
	byte[] getInterleavedData() throws Exception;
}
