package com.widedot.m6809.gamebuilder.spi.globals;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Imageset geometry a &lt;gfxcomp&gt; hands to a later &lt;imageset&gt; of the
 * same build.
 *
 * The two halves of an imageset do not always live in the same file. The
 * compiled drawing code of a big set does not fit in one page — R-Type's
 * explosion is 17 KB of sprites — so it is cut by the packer and spread,
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

	/**
	 * What a generated index writes in front of a page : the machine's
	 * expression and the asm header defining it. The index asks the page BY
	 * NAME ({@code <symbol>$PAGE}) and the builder resolves it, so nothing
	 * here knows a page number — nor the cartridge bits, which belong to the
	 * machine declaration (see Machines).
	 */
	public static class PageByte {
		public final String expr;
		public final String include;

		public PageByte(String expr, String include) {
			this.expr = expr;
			this.include = include;
		}
	}

	/** an imageset that knows its images and can write their index */
	public interface Index {
		/**
		 * @param path    where to write the generated source
		 * @param section the section to emit it in ; a {@code .static} one has
		 *                the addresses baked at build time
		 * @param pageByte the machine's page byte prefix and its header
		 */
		void generate(String path, String section, PageByte pageByte) throws Exception;

		/**
		 * Absorb another gfxcomp's contribution to the same set. Refusing a
		 * duplicate image name is the implementation's job — two contributors
		 * declaring the same pose is the one real mistake here.
		 */
		default void merge(Index other) throws Exception {
			throw new Exception("this imageset cannot merge contributions");
		}
	}

	private final Map<String, Index> sets = new LinkedHashMap<String, Index>();

	/**
	 * Several {@code <gfxcomp>} MAY contribute to one set : that is what lets
	 * a big set be cut into slices the arena ranges independently — the v1
	 * granularity, chosen by hand. Each descriptor already carries the page of
	 * ITS image, so the index never cared where the slices land. The one
	 * {@code <imageset>} element still writes the whole index, once.
	 */
	public void declare(String name, Index index) throws Exception {
		Index existing = sets.get(name);
		if (existing != null) {
			existing.merge(index);
			return;
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
