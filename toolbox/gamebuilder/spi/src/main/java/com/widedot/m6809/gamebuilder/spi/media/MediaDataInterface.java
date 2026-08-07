package com.widedot.m6809.gamebuilder.spi.media;

import java.util.List;

public interface MediaDataInterface {
	void write(String location, byte[] srcData) throws Exception;
	byte[] cwrite(String location, byte[] srcData) throws Exception;
	byte[] getInterleavedData() throws Exception;
	void addDirEntry(DirEntry entry) throws Exception;
	List<DirEntry> getDirEntries() throws Exception;

	/**
	 * Same writes, carrying the NAME of what the bytes are — a file, a
	 * directory, a boot sector. The media is the only place that knows where
	 * the bytes land ; the caller is the only place that knows what they are.
	 * These meet the two for the occupancy report. Implementations that do
	 * not journal simply inherit the delegation.
	 */
	default void write(String location, byte[] srcData, String name) throws Exception {
		write(location, srcData);
	}

	default byte[] cwrite(String location, byte[] srcData, String name) throws Exception {
		return cwrite(location, srcData);
	}
}
