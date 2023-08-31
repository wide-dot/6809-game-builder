package com.widedot.m6809.gamebuilder.spi.media;

import java.util.List;

public interface MediaDataInterface {
	void write(String location, byte[] srcData) throws Exception;
	byte[] cwrite(String location, byte[] srcData) throws Exception;
	byte[] getInterleavedData() throws Exception;
	void addDirEntry(DirEntry entry) throws Exception;
	List<DirEntry> getDirEntries() throws Exception;
}
