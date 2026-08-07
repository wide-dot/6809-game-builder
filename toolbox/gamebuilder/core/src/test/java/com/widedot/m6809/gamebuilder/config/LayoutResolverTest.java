package com.widedot.m6809.gamebuilder.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.junit.jupiter.api.Test;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

/**
 * A layout says where things live. Two ways of saying the same thing must
 * resolve to the same thing : the compact form (page, address and size on the
 * region) is a shorthand for a region holding one zone, and nothing downstream
 * should be able to tell them apart — the disk image is the real proof, this
 * pins the resolver itself.
 */
public class LayoutResolverTest {

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

	private static ImmutableNode layout(ImmutableNode... regions) {
		ImmutableNode.Builder b = new ImmutableNode.Builder().name("layout");
		for (ImmutableNode r : regions) {
			b.addChild(r);
		}
		return b.create();
	}

	@Test
	void theCompactFormIsARegionOfOneZone() throws Exception {
		Map<String, Regions.Region> out = LayoutResolver.resolve(layout(
				node("region", "name", "common", "page", "$01",
				     "address", "$6100", "size", "$1EC0").create()), ctx());

		Regions.Region common = out.get("common");
		assertEquals(1, common.zones.size(), "one zone, built from the attributes");
		assertEquals(0x01, common.zones.get(0).page);
		assertEquals(0x6100, common.zones.get(0).address);
		assertEquals(0x1EC0, common.zones.get(0).size);
		assertEquals(0x1EC0, common.capacity());
	}

	@Test
	void bothFormsResolveTheSameWay() throws Exception {
		Regions.Region compact = LayoutResolver.resolve(layout(
				node("region", "name", "r", "page", "$0F",
				     "address", "$0000", "size", "$1EFE").create()), ctx()).get("r");

		Regions.Region declared = LayoutResolver.resolve(layout(
				node("region", "name", "r")
					.addChild(node("zone", "page", "$0F", "address", "$0000",
					               "size", "$1EFE").create())
					.create()), ctx()).get("r");

		assertEquals(compact.page, declared.page);
		assertEquals(compact.address, declared.address);
		assertEquals(compact.size, declared.size);
		assertEquals(compact.capacity(), declared.capacity());
	}

	/**
	 * The point of zones : a space that is not continuous. Two pieces on two
	 * pages, and even two pieces of the SAME page — the tail a neighbour left
	 * and a slice further up.
	 */
	@Test
	void aRegionHoldsAsManyPiecesAsItNeeds() throws Exception {
		Regions.Region r = LayoutResolver.resolve(layout(
				node("region", "name", "scattered")
					.addChild(node("zone", "page", "$0E", "address", "$2E68", "size", "$1198").create())
					.addChild(node("zone", "page", "$0F", "address", "$1EFE", "size", "$2102").create())
					.addChild(node("zone", "page", "$0E", "address", "$0100", "size", "$0200").create())
					.create()), ctx()).get("scattered");

		assertEquals(3, r.zones.size());
		assertEquals(0x1198 + 0x2102 + 0x0200, r.capacity(),
				"capacity is the sum of the pieces, whatever pages they sit in");
		assertEquals(0x0E, r.page, "the first zone stands for the region");
		assertEquals(0x2E68, r.address);
	}

	@Test
	void anArenaIsARegionTheBuilderRanges() throws Exception {
		Regions.Region a = LayoutResolver.resolve(layout(
				node("arena", "name", "objects")
					.addChild(node("zone", "page", "$18", "address", "$07CA", "size", "$3836").create())
					.create()), ctx()).get("objects");

		assertTrue(a.packed, "an <arena> is ranged, a <region> is not");
		assertEquals(0x3836, a.capacity());
	}

	@Test
	void anArenaWithoutZonesIsRefused() {
		Exception e = assertThrows(Exception.class, () -> LayoutResolver.resolve(layout(
				node("arena", "name", "empty").create()), ctx()));
		assertTrue(e.getMessage().contains("zone"),
				"an arena IS its list of places, say so : " + e.getMessage());
	}

	@Test
	void onlyZonesMayLiveInsideARegion() throws Exception {
		Exception e = assertThrows(Exception.class, () -> LayoutResolver.resolve(layout(
				node("region", "name", "r")
					.addChild(node("reserved", "name", "nope", "page", "$01",
					               "address", "$0000", "size", "$10").create())
					.create()), ctx()));
		assertTrue(e.getMessage().contains("zone"),
				"the message must name what IS allowed, got: " + e.getMessage());
	}
}
