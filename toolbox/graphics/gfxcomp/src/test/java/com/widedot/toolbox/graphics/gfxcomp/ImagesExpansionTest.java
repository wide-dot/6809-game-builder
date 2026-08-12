package com.widedot.toolbox.graphics.gfxcomp;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;

/**
 * The compact image declaration (7b) : a series directory expands into the
 * very {@code <image>} nodes the hand-written form declares — same names,
 * same indexes, same encoders — or the rewrite of the 52 real blocks could
 * not be proven by identity. Each rule pinned here was measured on the v1
 * reference first (analyse-images-7b).
 */
class ImagesExpansionTest {

	private static BuildContext ctx(Path root) {
		java.util.Map<String, String> values = new java.util.HashMap<String, String>();
		return new BuildContext(root.toString(), new Settings(values));
	}

	private static ImmutableNode.Builder node(String name, String... attributes) {
		ImmutableNode.Builder b = new ImmutableNode.Builder().name(name);
		for (int i = 0; i < attributes.length; i += 2) {
			b.addAttribute(attributes[i], attributes[i + 1]);
		}
		return b;
	}

	private static void series(Path root, String dir, String... files) throws Exception {
		Path d = root.resolve(dir);
		Files.createDirectories(d);
		for (String f : files) {
			Files.writeString(d.resolve(f), "");
		}
	}

	private static String attr(ImmutableNode n, String name) {
		Object v = n.getAttributes().get(name);
		return v == null ? null : v.toString();
	}

	@Test
	void aMirrorRowContinuesNamesAndIndexes(@TempDir Path root) throws Exception {
		// the scant shape : three files, one plain row then the same directory
		// mirrored — six images, indexes 0-5, names scant_0..scant_5
		series(root, "enemies/scant/images", "00.png", "01.png", "02.png");
		ImmutableNode gfxcomp = node("gfxcomp", "genindex", "gen/x.asm", "gendir", "gen")
				.addChild(node("images", "dir", "enemies/scant/images").create())
				.addChild(node("images", "dir", "enemies/scant/images", "mirror", "x").create())
				.create();

		List<ImmutableNode> images = GfxcompPlugin.imageNodes(gfxcomp, ctx(root));

		assertEquals(6, images.size());
		assertEquals("scant_0", attr(images.get(0), "name"));
		assertEquals("scant_3", attr(images.get(3), "name"));
		assertEquals("enemies/scant/images/00.png", attr(images.get(3), "filename"));
		assertEquals("5", attr(images.get(5), "index"));
		ImmutableNode encoder = images.get(3).getChildren().get(0);
		assertEquals("bdraw", attr(encoder, "name"));
		assertEquals("x", attr(encoder, "mirror"));
		assertEquals("0", attr(encoder, "shift"));
	}

	@Test
	void theBaseComesFromTheSeriesDirectoryNotFromImages(@TempDir Path root) throws Exception {
		// a family subdirectory names the base ; a plain images/ dir names it
		// after its parent, never "images"
		series(root, "player/images/ship", "00-up.png", "01-down.png");
		ImmutableNode gfxcomp = node("gfxcomp", "gendir", "gen")
				.addChild(node("images", "dir", "player/images/ship").create())
				.create();

		List<ImmutableNode> images = GfxcompPlugin.imageNodes(gfxcomp, ctx(root));

		assertEquals("ship_0", attr(images.get(0), "name"));
		// no genindex/imageset on this gfxcomp : no index is invented
		assertEquals(null, attr(images.get(0), "index"));
	}

	@Test
	void shiftsMakeOneEncoderEach(@TempDir Path root) throws Exception {
		// the player shape : pre-shifted even on floppy, pinned on the row
		series(root, "player/images", "00.png");
		ImmutableNode gfxcomp = node("gfxcomp", "gendir", "gen")
				.addChild(node("images", "dir", "player/images", "shifts", "0,1").create())
				.create();

		List<ImmutableNode> images = GfxcompPlugin.imageNodes(gfxcomp, ctx(root));

		assertEquals(2, images.get(0).getChildren().size());
		assertEquals("0", attr(images.get(0).getChildren().get(0), "shift"));
		assertEquals("1", attr(images.get(0).getChildren().get(1), "shift"));
	}

	@Test
	void aLiteralImageAdvancesIndexAndBaseCounters(@TempDir Path root) throws Exception {
		// mixed form : a hand-written exception in the middle, the compact row
		// resumes after it — indexes and the base numbering both continue
		series(root, "foe/images", "00.png", "01.png");
		ImmutableNode gfxcomp = node("gfxcomp", "genindex", "gen/x.asm", "gendir", "gen")
				.addChild(node("image", "name", "foe_0", "filename", "foe/special.png",
						"index", "0").create())
				.addChild(node("images", "dir", "foe/images").create())
				.create();

		List<ImmutableNode> images = GfxcompPlugin.imageNodes(gfxcomp, ctx(root));

		assertEquals(3, images.size());
		assertEquals("foe_1", attr(images.get(1), "name"));
		assertEquals("1", attr(images.get(1), "index"));
		assertEquals("2", attr(images.get(2), "index"));
	}

	@Test
	void indexNoneKeepsAnIndexedSetsSeriesUnindexed(@TempDir Path root) throws Exception {
		// the jaw shape : images reached by name inside a genindex set — an
		// invented index would grow every descriptor by its idx byte
		series(root, "jaw/images", "00.png");
		ImmutableNode gfxcomp = node("gfxcomp", "genindex", "gen/x.asm", "gendir", "gen")
				.addChild(node("images", "dir", "jaw/images", "index", "none").create())
				.create();

		List<ImmutableNode> images = GfxcompPlugin.imageNodes(gfxcomp, ctx(root));
		assertEquals(null, attr(images.get(0), "index"));
	}

	@Test
	void filesSortByNumericPrefixNotLexically(@TempDir Path root) throws Exception {
		// 2 before 10 : the prefix is a number, not a string
		series(root, "foe/images", "10.png", "2.png");
		ImmutableNode gfxcomp = node("gfxcomp", "gendir", "gen")
				.addChild(node("images", "dir", "foe/images").create())
				.create();

		List<ImmutableNode> images = GfxcompPlugin.imageNodes(gfxcomp, ctx(root));

		assertEquals("foe/images/2.png", attr(images.get(0), "filename"));
		assertEquals("foe/images/10.png", attr(images.get(1), "filename"));
	}

	@Test
	void aFileWithoutOrderPrefixIsANamedError(@TempDir Path root) throws Exception {
		// the default match [0-9]*.png would skip it silently — an explicit
		// match that catches a prefixless file is refused with its name
		series(root, "foe/images", "sprite.png");
		ImmutableNode gfxcomp = node("gfxcomp", "gendir", "gen")
				.addChild(node("images", "dir", "foe/images", "match", "*.png").create())
				.create();

		Exception e = assertThrows(Exception.class,
				() -> GfxcompPlugin.imageNodes(gfxcomp, ctx(root)));
		assertTrue(e.getMessage().contains("sprite.png"), e.getMessage());
		assertTrue(e.getMessage().contains("order prefix"), e.getMessage());
	}

	@Test
	void unreferencedLeftoversAreSkippedByTheDefaultMatch(@TempDir Path root) throws Exception {
		// a series directory may host a font glyph or a work file : the
		// default match reads only the NN-prefixed series
		series(root, "foe/images", "00.png", "letter_a.png");
		ImmutableNode gfxcomp = node("gfxcomp", "gendir", "gen")
				.addChild(node("images", "dir", "foe/images").create())
				.create();

		List<ImmutableNode> images = GfxcompPlugin.imageNodes(gfxcomp, ctx(root));
		assertEquals(1, images.size());
		assertEquals("foe/images/00.png", attr(images.get(0), "filename"));
	}

	@Test
	void twoFilesSharingAPrefixIsANamedError(@TempDir Path root) throws Exception {
		series(root, "foe/images", "01-a.png", "01-b.png");
		ImmutableNode gfxcomp = node("gfxcomp", "gendir", "gen")
				.addChild(node("images", "dir", "foe/images").create())
				.create();

		Exception e = assertThrows(Exception.class,
				() -> GfxcompPlugin.imageNodes(gfxcomp, ctx(root)));
		assertTrue(e.getMessage().contains("share order prefix"), e.getMessage());
	}
}
