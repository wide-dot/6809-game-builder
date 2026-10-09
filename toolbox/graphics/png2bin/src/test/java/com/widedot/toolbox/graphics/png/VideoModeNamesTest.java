package com.widedot.toolbox.graphics.png;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

/**
 * gfxcomp names the $41 mode bm4s, next to bm16 ; png2bin knew it as t1s.
 * Both names are the same layout, so one mode carries one name across the
 * tools without breaking a configuration that says t1s.
 */
public class VideoModeNamesTest {

	@Test
	void bm4sIsTheT1sLayout() throws Exception {
		assertArrayEquals(Png2BinPlugin.mode("t1s"), Png2BinPlugin.mode("bm4s"));
		assertArrayEquals(new int[] {2, 8, 40, 2, 2}, Png2BinPlugin.mode("BM4S"));
	}

	@Test
	void anUnknownModeIsRefused() {
		assertThrows(Exception.class, () -> Png2BinPlugin.mode("bm8"));
	}
}
