package com.widedot.m6809.gamebuilder.spi;

import java.util.Collections;
import java.util.List;

import com.widedot.m6809.gamebuilder.spi.media.MediaFactory;

// https://medium.com/geekculture/designing-a-lightweight-plugin-architecture-in-java-5eedfeaa92a9

public interface Plugin {

	default List<DefaultFactory> getDefaultFactories() {
		return Collections.emptyList();
	}
	
	default List<ObjectFactory> getObjectFactories() {
		return Collections.emptyList();
	}
	
	default List<MediaFactory> getMediaFactories() {
		return Collections.emptyList();
	}
	
	default List<FileFactory> getFileFactories() {
		return Collections.emptyList();
	}
	
}
