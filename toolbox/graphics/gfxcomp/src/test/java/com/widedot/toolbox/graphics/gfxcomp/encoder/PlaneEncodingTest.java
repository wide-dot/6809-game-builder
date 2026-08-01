package com.widedot.toolbox.graphics.gfxcomp.encoder;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.image.BufferedImage;
import java.awt.image.IndexColorModel;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.widedot.toolbox.graphics.gfxcomp.Image;
import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;

/**
 * A line is split across two planes in pairs of pixels — a byte holds two of
 * them, and consecutive bytes alternate between RAM A and RAM B. So columns
 * 0 and 1 land in plane 0, columns 2 and 3 in plane 1, and so on: an image
 * drawn only where {@code x % 4} is 2 or 3 leaves plane 0 empty.
 *
 * The compressed encoders used to gate *both* encodes on plane 0 being non
 * empty while emitting on each plane's own flag. In that one combination they
 * wrote the plane 1 entry point with nothing behind it, and the drawing code
 * jumped into whatever followed. No asset in the corpus has that shape, which
 * is why nothing else covers it.
 */
public class PlaneEncodingTest {

	/** an 8 bit indexed image whose pixels all land in plane 1 */
	private static File planeOneOnly(Path dir) throws Exception {
		byte[] r = new byte[17], g = new byte[17], b = new byte[17];
		for (int i = 1; i < 17; i++) { r[i] = (byte) (i * 8); g[i] = (byte) (i * 4); b[i] = (byte) (i * 2); }
		IndexColorModel cm = new IndexColorModel(8, 17, r, g, b, 0);
		BufferedImage img = new BufferedImage(8, 8, BufferedImage.TYPE_BYTE_INDEXED, cm);
		for (int y = 2; y < 6; y++) {
			for (int x = 0; x < 8; x++) {
				if (x % 4 == 2 || x % 4 == 3) {
					img.getRaster().setSample(x, y, 0, 1);
				}
			}
		}
		File file = dir.resolve("comb.png").toFile();
		ImageIO.write(img, "png", file);
		return file;
	}

	@Test
	void planeOneIsEncodedWhenPlaneZeroIsEmpty(@TempDir Path dir) throws Exception {
		File png = planeOneOnly(dir);
		Image image = new Image("comb", 0, png.getAbsolutePath(),
		                        Image.TYPE_ZX0, Mirror.NONE, 0, Image.POSITION_CENTER);
		assertTrue(image.isPlane0Empty(), "the fixture must leave plane 0 empty");
		assertFalse(image.isPlane1Empty(), "the fixture must fill plane 1");

		image.encode(dir.toString());

		// The generated routine points X at @b and returns into it, so the label
		// has to be followed by the decompression data. With the wrong flag the
		// file ended on a bare @b and the drawing code ran off into whatever
		// came next. Match the label on its own line : @b also appears earlier
		// in the leax that loads its address.
		String[] lines = Files.readString(dir.resolve("comb_ND0.asm")).split("\\R");
		int label = -1;
		for (int i = 0; i < lines.length; i++) {
			if ("@b".equals(lines[i].trim())) {
				label = i;
				break;
			}
		}
		assertTrue(label >= 0, "plane 1 entry point is missing\n" + String.join("\n", lines));

		boolean hasBody = false;
		for (int i = label + 1; i < lines.length; i++) {
			if (!lines[i].trim().isEmpty()) {
				hasBody = true;
				break;
			}
		}
		assertTrue(hasBody, "plane 1 entry point has nothing behind it\n" + String.join("\n", lines));
	}
}
