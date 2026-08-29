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

	/**
	 * Write that REFUSES to leave the section's declared track and face.
	 *
	 * The loader reads a directory as CONTIGUOUS sectors of one track/face :
	 * its multi-sector read only increments the sector index. The generic
	 * write, meant for big data payloads, silently rolls onto the next face
	 * when a track runs out — legitimate for files, fatal for a directory :
	 * the spilled tail reads back as garbage on the machine. Lived twice on
	 * dir2 (2026-08 : evicted from track 0 by the gouger's entries, then its
	 * new home on track 79 overflowed when the stage-2 cast grew) — each time
	 * the build stayed green and the game froze at run time, in the loader,
	 * on a garbage size. Callers whose bytes must honour the loader's
	 * contiguity contract use THIS entry point ; media without a geometry
	 * simply inherit the plain write.
	 */
	default void writeContiguous(String location, byte[] srcData, String name) throws Exception {
		write(location, srcData, name);
	}
}
