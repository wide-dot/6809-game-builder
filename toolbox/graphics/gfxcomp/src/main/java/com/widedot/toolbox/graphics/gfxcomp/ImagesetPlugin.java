package com.widedot.toolbox.graphics.gfxcomp;

import java.io.File;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.globals.ImageSets;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the &lt;imageset&gt; element : writes the index of a set whose
 * drawing code was compiled elsewhere, as a generated source of the
 * surrounding &lt;lwasm&gt; unit.
 *
 * A &lt;gfxcomp genindex&gt; writes its own index because its images are in the
 * same file, so one {@code <file>$PAGE} says where they all are. That stops
 * being true as soon as the code outgrows a page and is declared as a pageset :
 * the frames then sit on different pages, while the index must stay on one —
 * the page {@code Img_Page_Index} mounts to read it. Compiling and indexing
 * become two elements, this being the second.
 *
 * It asks the placement registry for the page of each drawing routine, one by
 * one, and bakes it as a literal. This is the same road a &lt;tilemap&gt; takes
 * to index a tileset spread over pages, and the same shape v1's imageset had —
 * a page byte per frame, its builder having placed the pages itself.
 *
 * The addresses are baked by the direntry's {@code bake} mode ; the index joins
 * a set of any size then costs no load-time link data at all. The provider has
 * to be declared before this element, which is the rule for every static
 * reference.
 */
@Slf4j
public class ImagesetPlugin {

	public static File getFile(ImmutableNode node, BuildContext ctx) throws Exception {

		String name = Attribute.getString(node, ctx, "name");
		String gensource = ctx.path + File.separator + Attribute.getString(node, ctx, "gensource");
		String section = Attribute.getString(node, ctx, "section", "code");

		ImageSets.Index index = ctx.imageSets.get(name);
		if (index == null) {
			throw new Exception(ctx.sources.locate(node) + ": no <gfxcomp> declared the imageset '"
					+ name + "' (declared so far: " + ctx.imageSets.names() + ") — the element"
					+ " that compiles the images has to come first, and to name the set with"
					+ " imageset=\"" + name + "\"");
		}

		index.generate(gensource, section, ctx.staticLink::pageOf);
		log.info("imageset {} : index generated in section {}", name, section);
		return new File(gensource);
	}
}
