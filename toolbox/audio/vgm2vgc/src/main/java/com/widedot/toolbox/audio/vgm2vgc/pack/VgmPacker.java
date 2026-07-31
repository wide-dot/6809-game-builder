package com.widedot.toolbox.audio.vgm2vgc.pack;

import java.io.ByteArrayOutputStream;
import java.nio.file.Files;
import java.nio.file.Paths;

import lombok.extern.slf4j.Slf4j;

/**
 * Packs SN76489 PSG VGM data into the VGC format read by the 6809 player.
 *
 * Java port of vgmpacker.py by Simon Morris (https://github.com/simondotm/vgm-packer),
 * MIT licensed, which used to run under an embedded Jython interpreter. The port is
 * deliberately literal: the produced files must stay byte for byte identical.
 *
 * The format, quoting the original:
 *  1. register data split into 8 streams, 3x 16-bit tones, 1x 8-bit channel3 tone,
 *     4x 8-bit volumes
 *  2. register command bits are stripped
 *  3. the channel3 tone stream replaces runs with 0x0F to signal no change, and
 *     0x08 is appended as an EOF marker
 *  4. all 8 streams are RLE compressed, using the top 4 bits as run length
 *  5. the output stream is an LZ4 frame
 *  6. all 8 streams are LZ4 compressed with 255 match distance and 8-bit offsets
 *  7. the LZ4 magic number becomes [56 47 43 00] so the file is no longer mistaken
 *     for LZ4 ; bit 6 of byte 3 means 16-bit offsets, bit 7 means huffman
 */
@Slf4j
public class VgmPacker {

	/** RLE is always enabled, the flag is kept to mirror the original */
	private static final boolean RLE = true;

	/**
	 * Packs a VGM (or already serialised binary) file into VGC.
	 *
	 * @param srcFilename  source file, parsed as VGM when it ends with .vgm
	 * @param bufferSize   decoder buffer size ; below 256 emits 8-bit LZ4 offsets
	 * @param useHuffman   unsupported, see below
	 * @return the VGC file content
	 */
	public static byte[] pack(String srcFilename, int bufferSize, boolean useHuffman) throws Exception {

		if (useHuffman) {
			// the huffman stage of the original packer was never enabled by this
			// toolchain, and the 6809 player does not implement the matching
			// decoder either, so it was left out of the port rather than shipped
			// untested
			throw new Exception("huffman packing is not implemented");
		}

		byte[] dataBlock;
		if (srcFilename.toLowerCase().endsWith(".vgm")) {
			// asBinary returns null when a wait is not a multiple of the play
			// interval ; the original then died on a TypeError, say it plainly
			dataBlock = new VgmStream(srcFilename).asBinary();
			if (dataBlock == null) {
				throw new Exception(srcFilename + ": VGM timing is not a multiple of the play rate");
			}
		} else {
			dataBlock = Files.readAllBytes(Paths.get(srcFilename));
		}

		int dataOffset = 0;

		// parse the header emitted by asBinary()
		int headerSize = dataBlock[0] & 0xff;
		int playRate = dataBlock[1] & 0xff;

		if (headerSize == 5 && playRate == 50) {
			int packetCount = (dataBlock[2] & 0xff) + (dataBlock[3] & 0xff) * 256;
			int durationMm = dataBlock[4] & 0xff;
			int durationSs = dataBlock[5] & 0xff;

			dataOffset = headerSize + 1;
			dataOffset += (dataBlock[dataOffset] & 0xff) + 1;
			dataOffset += (dataBlock[dataOffset] & 0xff) + 1;

			log.debug("header_size={} play_rate={} packet_count={} duration={}m{}s data_offset={}",
					headerSize, playRate, packetCount, durationMm, durationSs, dataOffset);
		} else {
			log.debug("No header.");
		}

		// trim the header, the rest is raw data
		byte[] raw = new byte[dataBlock.length - dataOffset];
		System.arraycopy(dataBlock, dataOffset, raw, 0, raw.length);

		Lz4Enc lz4 = new Lz4Enc();
		int level = 9;
		lz4.setCompression(level);
		if (bufferSize < 256) {
			lz4.optimizedCompression(true);
		} else {
			// 16-bit offsets, crunches harder but needs bufferSize*8 of workspace
			lz4.setCompression(level, bufferSize);
			lz4.optimizedCompression(false);
		}

		byte[][] registers = splitRaw(raw);

		// step 1 - reformat the register data streams
		byte[][] streams = new byte[8][];
		streams[0] = rle2(combineRegisters(registers, new int[] { 0, 1 })); // tone0 HI/LO
		streams[1] = rle2(combineRegisters(registers, new int[] { 2, 3 })); // tone1 HI/LO
		streams[2] = rle2(combineRegisters(registers, new int[] { 4, 5 })); // tone2 HI/LO
		streams[3] = rle(diff(registers[6], 0x0f));                         // tone3, diffed into skip commands
		streams[4] = rle(registers[7]);                                     // v0
		streams[5] = rle(registers[8]);                                     // v1
		streams[6] = rle(registers[9]);                                     // v2
		streams[7] = rle(registers[10]);                                    // v3

		// step 2 - LZ4 compress the streams
		ByteArrayOutputStream output = new ByteArrayOutputStream();
		lz4.beginFrame(output);

		byte[] header = output.toByteArray();
		output.reset();
		// rewrite the LZ4 magic number, the format is not LZ4 compatible
		header[0] = 0x56;
		header[1] = 0x47;
		header[2] = 0x43;
		header[3] = 0x00;
		output.write(header, 0, header.length);

		for (int i = 0; i < streams.length; i++) {
			byte[] compressed = lz4.compressBlock(streams[i]);
			testUnpackLz4(compressed, streams[i]);
			streams[i] = compressed;
		}

		// step 4 - serialise the blocks
		for (byte[] s : streams) {
			output.write(s, 0, s.length);
		}

		// step 5 - close the frame
		lz4.endFrame(output);

		byte[] result = output.toByteArray();
		log.debug("VGC pack in={} out={} ratio={}%", dataBlock.length, result.length,
				dataBlock.length == 0 ? 0 : (result.length * 100) / dataBlock.length);
		return result;
	}

	/**
	 * Splits the packed raw data into 11 register streams, one byte per frame each.
	 * Command bits are stripped, so tone values keep only their low nibble.
	 */
	private static byte[][] splitRaw(byte[] rawData) {

		int[] registers = { 0x0, 0xF, 0x0, 0xF, 0x0, 0xF, 0x0, 0xF, 0xF, 0xF, 0xF };
		int latchedChannel = 0;
		int latchedType = 0;
		int registerMask = 15; // stripCommands is always true here

		ByteArrayOutputStream[] blocks = new ByteArrayOutputStream[11];
		for (int i = 0; i < 11; i++) {
			blocks[i] = new ByteArrayOutputStream();
		}

		int n = 0;
		boolean packet = true;
		while (packet) {
			int packetSize = rawData[n] & 0xff;
			n += 1;
			if (packetSize == 255) {
				packet = false;
			} else {
				for (int x = 0; x < packetSize; x++) {
					int d = rawData[n + x] & 0xff;
					if ((d & 128) != 0) {
						// latch
						int c = (d >> 5) & 3;
						latchedChannel = c;
						if ((d & 16) != 0) {
							registers[c + 7] = d & registerMask; // volume
							latchedType = 1;
						} else {
							registers[c * 2] = d & registerMask; // tone
							latchedType = 0;
						}
					} else {
						if (latchedType == 0) {
							if (latchedChannel < 3) {
								registers[latchedChannel * 2 + 1] = d; // tone upper bits
							} else {
								registers[latchedChannel * 2] = d & 7; // noise
							}
						} else {
							registers[latchedChannel + 7] = d & 15; // volume
						}
					}
				}

				// emit the current state of the 11 registers
				for (int x = 0; x < 11; x++) {
					blocks[x].write(registers[x]);
				}

				n += packetSize;
			}
		}

		// EOF marker on the tone3 stream, 0x08 is an invalid noise tone
		blocks[6].write(0x08);

		byte[][] out = new byte[11][];
		for (int i = 0; i < 11; i++) {
			out[i] = blocks[i].toByteArray();
		}
		return out;
	}

	/** Interleaves the given registers, one byte of each per frame. */
	private static byte[] combineRegisters(byte[][] registers, int[] combination) {
		ByteArrayOutputStream buffer = new ByteArrayOutputStream();
		for (int x = 0; x < registers[0].length; x++) {
			for (int y = 0; y < combination.length; y++) {
				buffer.write(registers[combination[y]][x]);
			}
		}
		return buffer.toByteArray();
	}

	/**
	 * Replaces unchanged bytes with marker, so the decoder can skip them. Used on
	 * tone3 to avoid resetting the LFSR.
	 */
	private static byte[] diff(byte[] block, int marker) throws Exception {
		byte[] diffBlock = new byte[block.length];
		for (int n = 0; n < block.length; n++) {
			if (n == 0) {
				diffBlock[0] = block[0];
			} else if (block[n] == block[n - 1]) {
				diffBlock[n] = (byte) marker;
			} else {
				diffBlock[n] = block[n];
			}
		}

		// the original verifies its own transform, keep the check
		byte[] rebuilt = new byte[diffBlock.length];
		for (int n = 0; n < diffBlock.length; n++) {
			if ((diffBlock[n] & 0xff) == marker) {
				if (n == 0) throw new Exception("diff: marker at offset 0");
				rebuilt[n] = rebuilt[n - 1];
			} else {
				rebuilt[n] = diffBlock[n];
			}
		}
		if (!java.util.Arrays.equals(rebuilt, block)) {
			throw new Exception("diff: transform is not reversible");
		}
		return diffBlock;
	}

	/**
	 * RLE for 4-bit tone or volume data: run length in the top 4 bits, 0 means the
	 * value appears once, 15 means 16 occurrences.
	 */
	private static byte[] rle(byte[] block) throws Exception {
		if (!RLE) return block;

		ByteArrayOutputStream rleBlock = new ByteArrayOutputStream();
		int n = 0;
		while (n < block.length) {
			int offset = n;
			int count = 0;
			while (offset < block.length - 1 && count < 15) {
				if (block[offset + 1] == block[n]) {
					count += 1;
					offset += 1;
				} else {
					break;
				}
			}
			rleBlock.write(((count & 15) << 4) | (block[n] & 15));
			n += count + 1;
		}

		byte[] out = rleBlock.toByteArray();
		checkRle(out, block);
		return out;
	}

	private static void checkRle(byte[] rleBlock, byte[] block) throws Exception {
		ByteArrayOutputStream test = new ByteArrayOutputStream();
		for (byte b : rleBlock) {
			int count = (b & 0xff) >> 4;
			int token = b & 15;
			for (int l = 0; l < count + 1; l++) {
				test.write(token);
			}
		}
		if (!java.util.Arrays.equals(test.toByteArray(), block)) {
			throw new Exception("rle: transform is not reversible");
		}
	}

	/**
	 * RLE for 12-bit tone data stored as 16-bit words: run length in the top 4 bits
	 * of the first byte of the pair.
	 */
	private static byte[] rle2(byte[] block) throws Exception {
		if (!RLE) return block;

		ByteArrayOutputStream rleBlock = new ByteArrayOutputStream();
		int n = 0;
		while (n < block.length) {
			int offset = n;
			int count = 0;
			while (offset < block.length - 2 && count < 15) {
				if (block[offset + 2] == block[n] && block[offset + 3] == block[n + 1]) {
					count += 1;
					offset += 2;
				} else {
					break;
				}
			}

			int out = ((block[n] & 0xff) << 8) + (block[n + 1] & 0xff);

			if ((block[n + 1] & 0xff) > 63 || (block[n] & 0xff) > 15) {
				log.warn("at offset {}, tone value is greater than 10 bits in size", offset);
			}
			if (out > 4095) {
				log.warn("at offset {}, tone {} greater than 12 bits in size", offset, out);
			}

			out |= (count & 15) << 12;
			rleBlock.write((out >> 8) & 255);
			rleBlock.write(out & 255);

			n += count * 2 + 2;
		}

		byte[] out = rleBlock.toByteArray();

		// verify, as the original does
		ByteArrayOutputStream test = new ByteArrayOutputStream();
		for (int i = 0; i < out.length; i += 2) {
			int count = (out[i] & 0xff) >> 4;
			int token = out[i] & 15;
			for (int l = 0; l < count + 1; l++) {
				test.write(token);
				test.write(out[i + 1]);
			}
		}
		if (!java.util.Arrays.equals(test.toByteArray(), block)) {
			throw new Exception("rle2: transform is not reversible");
		}
		return out;
	}

	/**
	 * Decompresses an LZ4 block and checks it against the source, the same
	 * self-check the original packer runs on every stream. Assumes the LZ48
	 * variant: a single byte of match offset.
	 */
	private static void testUnpackLz4(byte[] compressed, byte[] uncompressed) throws Exception {
		ByteArrayOutputStream unpacked = new ByteArrayOutputStream();
		int index = 4; // skip the block header
		boolean eof = false;

		while (!eof) {
			int token = compressed[index++] & 0xff;

			int literalCount = token >> 4;
			int literalLength = literalCount;
			if (literalCount == 15) {
				do {
					literalCount = compressed[index++] & 0xff;
					literalLength += literalCount;
				} while (literalCount == 255);
			}

			for (int n = 0; n < literalLength; n++) {
				unpacked.write(compressed[index++] & 0xff);
			}

			// compressed data always ends with literals, so eof is decided here
			eof = (index == compressed.length);
			if (!eof) {
				int matchCount = token & 15;
				int matchLength = matchCount + 4;

				int offsetToken = compressed[index++] & 0xff; // LZ48: one byte only
				int offset = unpacked.size() - offsetToken;

				if (matchCount == 15) {
					do {
						matchCount = compressed[index++] & 0xff;
						matchLength += matchCount;
					} while (matchCount == 255);
				}

				// the match may overlap what it produces, so read back byte by byte
				for (int n = 0; n < matchLength; n++) {
					byte[] sofar = unpacked.toByteArray();
					unpacked.write(sofar[offset] & 0xff);
					offset += 1;
				}
			}
		}

		if (!java.util.Arrays.equals(unpacked.toByteArray(), uncompressed)) {
			throw new Exception("lz4: block does not decompress back to its input");
		}
	}
}
