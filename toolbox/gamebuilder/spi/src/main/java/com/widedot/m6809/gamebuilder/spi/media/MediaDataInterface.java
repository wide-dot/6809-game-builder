package com.widedot.m6809.gamebuilder.spi.media;

import java.util.List;

public interface MediaDataInterface {
	byte[] write(String location, byte[] data) throws Exception;
	byte[] getInterleavedData() throws Exception;
	void addDirEntry(DirEntry entry) throws Exception;
	List<DirEntry> getDirEntries() throws Exception;
}
