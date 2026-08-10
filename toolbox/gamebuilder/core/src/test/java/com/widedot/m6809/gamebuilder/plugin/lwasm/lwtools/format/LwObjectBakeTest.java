package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.m6809.gamebuilder.spi.globals.BakeMode;
import com.widedot.m6809.gamebuilder.spi.globals.LinkSymbols;
import com.widedot.m6809.gamebuilder.spi.globals.StaticLink;
import com.widedot.m6809.util.ThirdPartyTools;

/**
 * Round trip through the real assembler : a snippet is assembled with lwasm
 * --format=obj, loaded as an LwObject, baked against a StaticLink, and the
 * patched bytes are read back.
 *
 * The contract under test is the one the whole optimisation rests on : a baked
 * reference must be byte-for-byte what the run-time linker would have written.
 * The 8 bit case mirrors loader.file.extern8.link — symbol value plus operand
 * computed on 16 bits, LOW byte stored.
 */
public class LwObjectBakeTest {

	/** assembles source with the shipped lwasm, returns the object path */
	private static Path assemble(Path tmp, String source) throws Exception {
		// Maven sets `basedir` to the MODULE directory, so ThirdPartyTools
		// would look for toolbox/third-party under core/. Walk up to the
		// repository root and point the explicit override at the shipped
		// binary — the override always wins, nothing global is mutated.
		if (System.getProperty("lwasm.path") == null) {
			Path root = Paths.get("").toAbsolutePath();
			while (root != null && !Files.isDirectory(root.resolve("toolbox/third-party"))) {
				root = root.getParent();
			}
			assumeTrue(root != null, "repository root not found, lwasm unavailable");
			String previous = System.getProperty("basedir");
			System.setProperty("basedir", root.toString());
			String resolved = ThirdPartyTools.resolve("lwasm");
			if (previous == null) System.clearProperty("basedir");
			else System.setProperty("basedir", previous);
			assumeTrue(Files.isRegularFile(Paths.get(resolved)),
					"lwasm not shipped for this platform");
			System.setProperty("lwasm.path", resolved);
		}
		String lwasm = ThirdPartyTools.resolve("lwasm");
		Path asm = tmp.resolve("unit.asm");
		Path obj = tmp.resolve("unit.obj");
		Files.writeString(asm, source);
		Process p = new ProcessBuilder(lwasm, asm.toString(), "--6809",
				"--format=obj", "--output=" + obj.toString())
				.inheritIO().start();
		assertEquals(0, p.waitFor(), "lwasm failed");
		return obj;
	}

	@Test
	void anEightBitReferenceToAnAbsoluteExportBakes(@TempDir Path tmp) throws Exception {
		Path obj = assemble(tmp,
				"ymm.NO_LOOP EXTERNAL\n"
				+ " SECTION code\n"
				+ "entry\n"
				+ "        lda   #ymm.NO_LOOP\n"
				+ " ENDSECTION\n");

		LwObject unit = new LwObject(obj.toString(), new LinkSymbols());
		StaticLink link = new StaticLink();
		// an absolute export : a constant, no placement involved
		link.registerExport("ymm.NO_LOOP", "engine.sound.ym.const", 0x80, true);
		link.place("unit", 1, 0x6100, "scenes.test");

		unit.bakeStatic(link, "unit", 0, BakeMode.ALL);

		byte[] bin = unit.getBytes();
		// lda #imm : opcode $86, operand = the baked constant
		assertEquals((byte) 0x86, bin[0]);
		assertEquals((byte) 0x80, bin[1]);
		assertEquals(0, unit.getExtern8().size(), "the reference must leave the link data");
		assertTrue(unit.getBakedCount() >= 1);
	}

	/**
	 * The run-time linker stores the low byte of address + operand for an 8 bit
	 * reference to a placed symbol. Baking must be indistinguishable from it.
	 */
	@Test
	void anEightBitReferenceToAPlacedExportBakesItsLowByte(@TempDir Path tmp) throws Exception {
		Path obj = assemble(tmp,
				"provider.entry EXTERNAL\n"
				+ " SECTION code\n"
				+ "entry\n"
				+ "        lda   #provider.entry\n"
				+ " ENDSECTION\n");

		LwObject unit = new LwObject(obj.toString(), new LinkSymbols());
		StaticLink link = new StaticLink();
		link.place("provider", 4, 0x2400, "scenes.test");
		link.registerExport("provider.entry", "provider", 0x006D, false);
		link.place("unit", 1, 0x6100, "scenes.test");

		unit.bakeStatic(link, "unit", 0, BakeMode.ALL);

		// $2400 + $6D = $246D, low byte $6D — what loader.file.extern8.link stores
		assertEquals((byte) 0x6D, unit.getBytes()[1]);
		assertEquals(0, unit.getExtern8().size());
	}

	@Test
	void aSixteenBitReferenceToAnAbsoluteExportBakes(@TempDir Path tmp) throws Exception {
		Path obj = assemble(tmp,
				"Irq_period EXTERNAL\n"
				+ " SECTION code\n"
				+ "entry\n"
				+ "        ldx   #Irq_period\n"
				+ " ENDSECTION\n");

		LwObject unit = new LwObject(obj.toString(), new LinkSymbols());
		StaticLink link = new StaticLink();
		link.registerExport("Irq_period", "engine.const", 0x4DFF, true);
		link.place("unit", 1, 0x6100, "scenes.test");

		unit.bakeStatic(link, "unit", 0, BakeMode.ALL);

		byte[] bin = unit.getBytes();
		// ldx #imm16 : opcode $8E, then the constant, big endian
		assertEquals((byte) 0x8E, bin[0]);
		assertEquals((byte) 0x4D, bin[1]);
		assertEquals((byte) 0xFF, bin[2]);
		assertEquals(0, unit.getExtern16().size());
	}

	/**
	 * The routing derived from provider multiplicity : a name two run-time
	 * alternatives export is not a failure under {@code auto}, it is a
	 * reference that stays load-time linked — and the decision is recorded
	 * with its cause, because a silent link is where a duplicated export
	 * would otherwise hide.
	 */
	@Test
	void anAmbiguousReferenceStaysLinkedAndRecordsItsCause(@TempDir Path tmp) throws Exception {
		Path obj = assemble(tmp,
				"stage.wave EXTERNAL\n"
				+ " SECTION code\n"
				+ "entry\n"
				+ "        ldx   #stage.wave\n"
				+ " ENDSECTION\n");

		LwObject unit = new LwObject(obj.toString(), new LinkSymbols());
		StaticLink link = new StaticLink();
		// two alternatives export the name at different placements, and both
		// stay reachable from the consumer : no single build-time value exists
		link.place("stage1", 4, 0x2400, "scenes.s1");
		link.place("stage2", 5, 0x2400, "scenes.s2");
		link.registerExport("stage.wave", "stage1", 0x0010, false);
		link.registerExport("stage.wave", "stage2", 0x0020, false);
		link.place("unit", 1, 0x6100, "scenes.s1");

		unit.bakeStatic(link, "unit", 0, BakeMode.AUTO);

		assertEquals(0, unit.getBakedCount(), "an ambiguous reference must not bake");
		assertEquals(1, unit.getExtern16().size(), "it stays in the link data");
		java.util.List<StaticLink.LinkedRef> refs = link.linkedRefs();
		assertEquals(1, refs.size());
		assertEquals("stage.wave", refs.get(0).symbol);
		assertEquals("unit", refs.get(0).consumer);
		assertTrue(refs.get(0).classified, "auto classified it, nobody declared it");
		assertTrue(refs.get(0).cause.contains("stage1") && refs.get(0).cause.contains("stage2"),
				"the cause must name the alternatives : " + refs.get(0).cause);
	}

	/** a declared bake="none" is a decision too : the caused list carries it */
	@Test
	void aNoneModeFileRecordsItsReferencesAsDeclared(@TempDir Path tmp) throws Exception {
		Path obj = assemble(tmp,
				"provider.entry EXTERNAL\n"
				+ " SECTION code\n"
				+ "entry\n"
				+ "        ldx   #provider.entry\n"
				+ "        ldy   #provider.entry\n"
				+ " ENDSECTION\n");

		LwObject unit = new LwObject(obj.toString(), new LinkSymbols());
		StaticLink link = new StaticLink();

		unit.bakeStatic(link, "unit", 0, BakeMode.NONE);

		assertEquals(0, unit.getBakedCount());
		java.util.List<StaticLink.LinkedRef> refs = link.linkedRefs();
		assertEquals(1, refs.size(), "two sites, one name : one line");
		assertEquals(2, refs.get(0).count);
		assertEquals("provider.entry", refs.get(0).symbol);
		assertTrue(!refs.get(0).classified, "declared, not classified");
	}

	/** a reference that bakes leaves no trace in the caused list */
	@Test
	void aBakedReferenceIsNotRecorded(@TempDir Path tmp) throws Exception {
		Path obj = assemble(tmp,
				"provider.entry EXTERNAL\n"
				+ " SECTION code\n"
				+ "entry\n"
				+ "        ldx   #provider.entry\n"
				+ " ENDSECTION\n");

		LwObject unit = new LwObject(obj.toString(), new LinkSymbols());
		StaticLink link = new StaticLink();
		link.place("provider", 4, 0x2400, "scenes.test");
		link.registerExport("provider.entry", "provider", 0x006D, false);
		link.place("unit", 1, 0x6100, "scenes.test");

		unit.bakeStatic(link, "unit", 0, BakeMode.AUTO);

		assertEquals(1, unit.getBakedCount());
		assertTrue(link.linkedRefs().isEmpty(), "nothing went to the loader, nothing to review");
	}

	/** the pre-existing contract, kept : $PAGE still resolves to the provider's page */
	@Test
	void aPageReferenceStillBakes(@TempDir Path tmp) throws Exception {
		Path obj = assemble(tmp,
				"assets.tiles$PAGE EXTERNAL\n"
				+ " SECTION code\n"
				+ "entry\n"
				+ "        lda   #assets.tiles$PAGE\n"
				+ " ENDSECTION\n");

		LwObject unit = new LwObject(obj.toString(), new LinkSymbols());
		StaticLink link = new StaticLink();
		link.place("assets.tiles", 6, 0x0000, "scenes.test");
		link.place("unit", 1, 0x6100, "scenes.test");

		unit.bakeStatic(link, "unit", 0, BakeMode.ALL);

		assertEquals((byte) 6, unit.getBytes()[1]);
	}
}
