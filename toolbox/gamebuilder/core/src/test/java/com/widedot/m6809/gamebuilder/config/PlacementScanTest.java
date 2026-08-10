package com.widedot.m6809.gamebuilder.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.junit.jupiter.api.Test;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;

/**
 * The attributed place : a file declares its destination once, on its own
 * declaration, and a bare {@code <load>} resolves against it. What these
 * tests pin is the scan half of that contract — the placements StaticLink
 * bakes against must be the same whether the destination sits on the load
 * or on the file, and a contradiction must be refused, not averaged.
 */
public class PlacementScanTest {

	private static BuildContext ctx() {
		java.util.Map<String, String> values = new java.util.HashMap<String, String>();
		return new BuildContext(".", new Settings(values));
	}

	private static ImmutableNode.Builder node(String name, String... attributes) {
		ImmutableNode.Builder b = new ImmutableNode.Builder().name(name);
		for (int i = 0; i < attributes.length; i += 2) {
			b.addAttribute(attributes[i], attributes[i + 1]);
		}
		return b;
	}

	private static ImmutableNode target(ImmutableNode... children) {
		ImmutableNode.Builder b = node("target", "name", "fd");
		for (ImmutableNode c : children) {
			b.addChild(c);
		}
		return b.create();
	}

	private static ImmutableNode pinnedRegion(String name, String page, String address) {
		return node("region", "name", name, "page", page,
				"address", address, "size", "$1000").create();
	}

	@Test
	void aBareLoadResolvesAgainstTheFilesAttributedRegion() throws Exception {
		BuildContext ctx = ctx();
		ImmutableNode tree = target(
				node("layout").addChild(pinnedRegion("common", "$01", "$6100")).create(),
				node("file", "name", "x", "region", "common").create(),
				node("scene", "name", "s").addChild(node("load", "name", "x").create()).create());

		PlacementScan.run(tree, ctx);

		assertEquals(0x6100, ctx.staticLink.addressOf("x"));
		assertEquals(0x01, ctx.staticLink.resolvePage("x"));
	}

	@Test
	void aRawAttributedPlaceIsPlacedLikeALiteralLoad() throws Exception {
		BuildContext ctx = ctx();
		ImmutableNode tree = target(
				node("file", "name", "x", "page", "$04", "address", "$2400").create(),
				node("scene", "name", "s").addChild(node("load", "name", "x").create()).create());

		PlacementScan.run(tree, ctx);

		assertEquals(0x2400, ctx.staticLink.addressOf("x"));
		assertEquals(0x04, ctx.staticLink.resolvePage("x"));
	}

	@Test
	void aFileWithoutAnAttributedPlaceStaysLinkDataOnly() throws Exception {
		BuildContext ctx = ctx();
		ImmutableNode tree = target(
				node("file", "name", "x").create(),
				node("scene", "name", "s").addChild(node("load", "name", "x").create()).create());

		PlacementScan.run(tree, ctx);

		// nothing placed : the historical export-only load, untouched
		assertThrows(Exception.class, () -> ctx.staticLink.addressOf("x"));
	}

	@Test
	void twoDifferentAttributedPlacesForOneNameAreRefused() {
		BuildContext ctx = ctx();
		ImmutableNode tree = target(
				node("layout")
					.addChild(pinnedRegion("a", "$01", "$6100"))
					.addChild(pinnedRegion("b", "$02", "$0000")).create(),
				node("file", "name", "x", "region", "a").create(),
				node("file", "name", "x", "region", "b").create());

		Exception e = assertThrows(Exception.class, () -> PlacementScan.run(tree, ctx));
		assertTrue(e.getMessage().contains("one attributed place"), e.getMessage());
	}

	@Test
	void aFileDeclaringTwoFormsIsRefused() {
		BuildContext ctx = ctx();
		ImmutableNode tree = target(
				node("file", "name", "x", "region", "a", "page", "$04",
						"address", "$2400").create());

		Exception e = assertThrows(Exception.class, () -> PlacementScan.run(tree, ctx));
		assertTrue(e.getMessage().contains("more than one"), e.getMessage());
	}

	@Test
	void aPagesetsDeclaredRegionIsItsAttributedPlace() throws Exception {
		BuildContext ctx = ctx();
		ImmutableNode tree = target(
				node("layout").addChild(pinnedRegion("tiles", "$06", "$0000")).create(),
				node("pageset", "name", "set", "region", "tiles").create(),
				node("scene", "name", "s").addChild(node("load", "name", "set").create()).create());

		PlacementScan.run(tree, ctx);

		// the set is placed at its region's base, exactly as an explicit
		// region= on the load recorded it before
		assertEquals(0x0000, ctx.staticLink.addressOf("set"));
		assertEquals(0x06, ctx.staticLink.resolvePage("set"));
	}
}
