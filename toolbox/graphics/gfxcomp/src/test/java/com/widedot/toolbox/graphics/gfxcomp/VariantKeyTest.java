package com.widedot.toolbox.graphics.gfxcomp;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;
import com.widedot.toolbox.graphics.gfxcomp.transformer.shift.Shift;

/**
 * The imageset used to come out empty: images were filed under "BN0" while the
 * index looked them up as "bdraw_none_shift0", so no variant was ever found and
 * every offset stayed at zero. Both sides now derive the key from variantKey,
 * and these tests pin the form (v1's, so the generated code keeps its names)
 * and the agreement between the two overloads.
 */
public class VariantKeyTest {

	@Test
	void keyIsMirrorThenEncoderThenShift() {
		assertEquals("NB0", Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_0));
		assertEquals("ND0", Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_0));
		assertEquals("XB1", Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_1));
		assertEquals("XYD7", Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_7));
		// rle and zx0 answer to the draw letter, as they do in v1 : the index
		// only ever looks up B and D, so a letter of their own hid them from it
		assertEquals("YD0", Image.variantKey(Image.TYPE_RLE, Mirror.Y, Shift.SHIFT_0));
		assertEquals("ND0", Image.variantKey(Image.TYPE_ZX0, Mirror.NONE, Shift.SHIFT_0));
	}

	@Test
	void bothOverloadsAgreeOnEveryCombination() {
		String[] types   = { Image.TYPE_DRAW, Image.TYPE_BDRAW, Image.TYPE_RLE, Image.TYPE_ZX0 };
		String[] mirrors = { Mirror.NONE, Mirror.X, Mirror.Y, Mirror.XY };
		String[] shifts  = { Shift.SHIFT_0, Shift.SHIFT_1, Shift.SHIFT_2, Shift.SHIFT_3,
		                     Shift.SHIFT_4, Shift.SHIFT_5, Shift.SHIFT_6, Shift.SHIFT_7 };

		for (String type : types) {
			for (String mirror : mirrors) {
				for (int shift = 0; shift < shifts.length; shift++) {
					assertEquals(Image.variantKey(type, mirror, shifts[shift]),
					             Image.variantKey(Image.typeId.get(type), Mirror.getId(mirror), shift),
					             type + " " + mirror + " " + shifts[shift]);
				}
			}
		}
	}
}
