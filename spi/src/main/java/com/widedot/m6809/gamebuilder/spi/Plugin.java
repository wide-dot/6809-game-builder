package com.widedot.m6809.gamebuilder.spi;

import java.util.Collections;
import java.util.List;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.MediaFactory;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.DirEntryFactory;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileFactory;

// https://medium.com/geekculture/designing-a-lightweight-plugin-architecture-in-java-5eedfeaa92a9

public interface Plugin {

	default List<MediaFactory> getMediaFactories() {
		return Collections.emptyList();
	}
	
	default List<DirEntryFactory> getDirEntryFactories() {
		return Collections.emptyList();
	}

	default List<FileFactory> getFileFactories() {
		return Collections.emptyList();
	}
	
}
