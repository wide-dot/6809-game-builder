package com.widedot.m6809.gamebuilder.config;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** loader.FILE_WRITE : the target's loader gets loader.file.save only when a file is writable. */
class FileWriteTest {

	private static ImmutableNode node(String name, ImmutableNode... children) {
		ImmutableNode.Builder b = new ImmutableNode.Builder().name(name);
		for (ImmutableNode c : children) {
			b.addChild(c);
		}
		return b.create();
	}

	@Test
	@DisplayName("a writable file anywhere in the target, and only then")
	void fileWrite() {
		ImmutableNode plain = new ImmutableNode.Builder().name("file").addAttribute("name", "a").create();
		ImmutableNode off = new ImmutableNode.Builder().name("file").addAttribute("name", "b")
				.addAttribute("writable", "false").create();
		ImmutableNode writable = new ImmutableNode.Builder().name("file").addAttribute("name", "s")
				.addAttribute("writable", "true").create();
		assertFalse(DirectoryLocations.hasWritable(node("target", node("floppydisk", node("directory", plain, off)))));
		assertTrue(DirectoryLocations.hasWritable(node("target",
				node("floppydisk", node("directory", plain), node("directory", plain, writable)))));
	}
}
