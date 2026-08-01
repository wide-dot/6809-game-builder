package com.widedot.m6809.gamebuilder.spi;

import java.util.Collections;
import java.util.List;
import java.util.Map;

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

	/**
	 * Byte ranges that have to sit inside a single 256 byte page once the file
	 * is loaded, by tag, as offsets from the start of this object.
	 *
	 * Code that reaches its own data through the direct page carries only the
	 * low byte of each address, so those bytes must share the page the DP
	 * register points at. The assembler can only check that where the address
	 * is fixed ; a file loaded into a region only gets its address here.
	 *
	 * A unit declares one by naming two symbols {@code <tag>.pagespan.first}
	 * and {@code <tag>.pagespan.last}.
	 */
	default Map<String, int[]> getPageSpans() throws Exception {
		return Collections.emptyMap();
	}

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
