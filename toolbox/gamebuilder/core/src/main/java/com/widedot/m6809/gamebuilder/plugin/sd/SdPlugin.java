package com.widedot.m6809.gamebuilder.plugin.sd;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;

import lombok.extern.slf4j.Slf4j;

/**
 * Writes a floppy disk for SDDRIVE. A .sd file is a row of UNITS, the faces
 * the monitor numbers in DK.DRV : 0 and 1 for the first drive, 2 and 3 for
 * the second. Each 256-byte sector takes 512 bytes, its second half 0xFF.
 *
 * <p>{@code drive="1"} (09/10/2026) puts this disk in the second drive,
 * units 2 and 3 ; two {@code <floppydisk>} of a target naming the same file,
 * one per drive, write ONE .sd. SDDRIVE then serves both disks at once, and
 * the loader finds each where it is : a two-disk game never asks for a
 * swap.</p>
 */
@Slf4j
public class SdPlugin {

	/** One unit : 80 tracks of 16 sectors, 512 bytes each in the file. */
	static final int UNIT_BYTES = 80 * 16 * 512;

	public static void run(ImmutableNode node, BuildContext ctx, MediaDataInterface media) throws Exception {

		log.debug("Processing sd ...");

		String filename = Attribute.getString(node, ctx, "filename");
		int drive = Attribute.getInteger(node, ctx, "drive", 0);
		if (drive != 0 && drive != 1) {
			throw new Exception(ctx.sources.locate(node) + ": <sd drive=\"" + drive
					+ "\"> : a drive is 0 or 1");
		}

		String dirname = ctx.path + File.separator + ctx.settings.get("dist.dir");
		new File(dirname).mkdirs();
		String absFilename = dirname + File.separator + filename;
		Path outputFile = Paths.get(absFilename);

		// the file another <floppydisk> of THIS target wrote holds the other
		// drive : merged, in whichever order the disks are declared. A file
		// left by an earlier build is not ours : started afresh.
		byte[] image = new byte[0];
		Path absolute = outputFile.toAbsolutePath().normalize();
		for (Path written : ctx.outputs.paths()) {
			if (written.toAbsolutePath().normalize().equals(absolute)) {
				image = Files.readAllBytes(outputFile);
			}
		}
		image = place(image, sectors(media.getInterleavedData()), drive);

		try {
			Files.deleteIfExists(outputFile);
			Files.write(outputFile, image);
			ctx.outputs.record(outputFile);
		} catch (IOException e) {
			throw new Exception("Cannot write " + absFilename, e);
		}

		log.debug("End of processing sd");
	}

	/** @return the disk's data as SDDRIVE sectors : 256 bytes, then 256 of 0xFF */
	static byte[] sectors(byte[] data) {
		final byte[] sd = new byte[data.length * 2];
		for (int ifd = 0, isd = 0; ifd < data.length; ifd++) {
			sd[isd++] = data[ifd];
			if ((ifd + 1) % 256 == 0) {
				for (int i = 0; i < 256; i++) {
					sd[isd++] = (byte) 0xFF;
				}
			}
		}
		return sd;
	}

	/**
	 * @return {@code image} with {@code disk} at the units of {@code drive}
	 *         (0 : units 0-1, 1 : units 2-3), what it held elsewhere kept ;
	 *         a hole before the disk — a one-face first disk, or the second
	 *         drive written first — is 0xFF, an unformatted face to SDDRIVE
	 */
	static byte[] place(byte[] image, byte[] disk, int drive) {
		int at = drive * 2 * UNIT_BYTES;
		byte[] out = Arrays.copyOf(image, Math.max(image.length, at + disk.length));
		if (image.length < at) {
			Arrays.fill(out, image.length, at, (byte) 0xFF);
		}
		System.arraycopy(disk, 0, out, at, disk.length);
		return out;
	}
}
