package com.widedot.m6809.gamebuilder.spi;

import java.util.Collections;
import java.util.List;

/**
 * A chunk of binary data produced by a handler, plus the load time link data it
 * carries.
 *
 * Only objects assembled by lwasm carry link data ; everything else is plain
 * bytes, which is why the link accessors default to empty instead of being
 * reimplemented identically by every producer.
 */
public interface ObjectDataInterface {

	byte[] getBytes() throws Exception;

	default List<byte[]> getExportAbs() throws Exception {
		return Collections.emptyList();
	}

	default List<byte[]> getExportRel() throws Exception {
		return Collections.emptyList();
	}

	default List<byte[]> getIntern() throws Exception {
		return Collections.emptyList();
	}

	default List<byte[]> getExtern8() throws Exception {
		return Collections.emptyList();
	}

	default List<byte[]> getExtern16() throws Exception {
		return Collections.emptyList();
	}

	default List<byte[]> getExternPage() throws Exception {
		return Collections.emptyList();
	}
}
