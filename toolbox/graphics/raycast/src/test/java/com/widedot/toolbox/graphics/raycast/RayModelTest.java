package com.widedot.toolbox.graphics.raycast;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** the raycaster's model, in a room with two pillars, all around from two places */
class RayModelTest {

	static final int TEXTURES = 0x7800;

	/** 8 x 8 cells : walls of texture 1 around, two pillars of texture 2 */
	static GridMap room() {
		int[] cells = new int[64];
		for (int i = 0; i < 8; i++) {
			cells[i] = cells[56 + i] = cells[8 * i] = cells[8 * i + 7] = 1;
		}
		cells[3 * 8 + 4] = 2;
		cells[5 * 8 + 2] = 2;
		return new GridMap(8, 8, cells);
	}

	static boolean between(int v, int a, int b) {
		return v >= Math.min(a, b) && v <= Math.max(a, b);
	}

	@Test
	void everyColumnSeesAWall() {
		for (Geometry g : new Geometry[] { Views.whole(), Views.small(), Views.fine() }) {
			RayTables t = new RayTables(g);
			RayModel model = new RayModel(t, room(), false);
			for (int a = 0; a < RayTables.ANGLES; a += 7) {
				RayModel.Frame f = model.frame(0x0180, 0x0180, a, TEXTURES);
				assertEquals(g.cols, f.rays);
				for (int k = 0; k < g.cols; k++) {
					assertTrue(f.samples[k] >= 1 && f.samples[k] <= g.indexMax(), "a height : " + f.samples[k]);
					assertTrue(g.heights().contains(f.samples[k] * g.unit()), "a height no scaler draws");
					int column = f.texture[k] - TEXTURES;
					assertTrue(column >= 0 && column < 2 * 4096 && column % 64 == 0, "a texture column : " + column);
				}
			}
		}
	}

	/** with pairing, an even column is its own ray, an odd one its own ray or between its neighbours */
	@Test
	void pairing() {
		Geometry g = Views.whole();
		RayTables t = new RayTables(g);
		RayModel paired = new RayModel(t, room(), true);
		RayModel each = new RayModel(t, room(), false);
		int interpolated = 0;
		for (int[] at : new int[][] { { 0x0180, 0x0180 }, { 0x0540, 0x0460 } }) {
			for (int a = 0; a < RayTables.ANGLES; a += 13) {
				RayModel.Frame f = each.frame(at[0], at[1], a, TEXTURES);
				RayModel.Frame p = paired.frame(at[0], at[1], a, TEXTURES);
				interpolated += g.cols - p.rays;
				for (int k = 0; k < g.cols; k += 2) {
					assertEquals(f.samples[k], p.samples[k], "column " + k);
					assertEquals(f.texture[k], p.texture[k], "column " + k);
				}
				for (int k = 1; k < g.cols - 1; k += 2) {
					boolean own = f.samples[k] == p.samples[k] && f.texture[k] == p.texture[k];
					boolean mean = between(p.samples[k], p.samples[k - 1], p.samples[k + 1])
							&& between(p.texture[k], p.texture[k - 1], p.texture[k + 1]);
					assertTrue(own || mean, "column " + k + " at angle " + a);
				}
			}
		}
		assertTrue(interpolated > 0, "no column was interpolated");
	}
}
