package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Imageset geometry a &lt;gfxcomp&gt; hands to a later &lt;imageset&gt; of the
 * same build.
 *
 * The two halves of an imageset do not always live in the same file. The
 * compiled drawing code of a big set does not fit in one page — R-Type's
 * explosion is 17 KB of sprites — so it is declared as a pageset and spread,
 * while the index that describes it must stay in one page, the one
 * {@code Img_Page_Index} mounts to read it. Compiling and indexing therefore
 * become two elements, and this is what passes between them : the geometry
 * measured while compiling, so nobody declares the same images twice.
 *
 * The index is written by the second element, not the first, because it can
 * only be written once the pages are known — exactly like a tilemap, which is
 * declared after the tileset it indexes.
 */
public class ImageSets {

	/** the page an {@code adr_} symbol landed on, once its direntry is placed */
	public interface PageOf {
		int of(String symbol) throws Exception;
	}

	/** an imageset that knows its images and can write their index */
	public interface Index {
		/**
		 * @param path    where to write the generated source
		 * @param section the section to emit it in ; a {@code .static} one has
		 *                the addresses baked at build time
		 * @param pages   asked for the page of each image, one by one
		 */
		void generate(String path, String section, PageOf pages) throws Exception;
	}

	private final Map<String, Index> sets = new LinkedHashMap<String, Index>();

	public void declare(String name, Index index) throws Exception {
		if (sets.containsKey(name)) {
			throw new Exception("two <gfxcomp> declare the imageset '" + name
					+ "' : an imageset is indexed once, by the element that names it");
		}
		sets.put(name, index);
	}

	/** null when nothing declared that name */
	public Index get(String name) {
		return sets.get(name);
	}

	/** the names declared so far, for an error message */
	public String names() {
		return sets.isEmpty() ? "none" : String.join(", ", sets.keySet());
	}

	public void clear() {
		sets.clear();
	}
}
