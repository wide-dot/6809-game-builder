package com.widedot.toolbox.audio.vgm2vgc.pack;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.zip.GZIPInputStream;

/**
 * Faithful Java port of vgmpacker/modules/vgmparser.py (VgmStream), limited to the
 * surface reachable from the constructor and as_binary(rawheader=True).
 *
 * Original: Simon Morris (https://github.com/simondotm/), MIT License.
 *
 * The Python source runs under Jython 2.7 (Python 2 semantics). All Python 2
 * quirks that affect the produced bytes are reproduced on purpose:
 *  - "/" between ints is floor division
 *  - bytes/bytearray elements are unsigned (0..255)
 *  - struct.pack('B', n) raises when n is out of the 0..255 range (kept as an exception)
 *  - odd/degenerate data paths are kept as-is, not fixed
 */
public class VgmStream {

	/** Raised where the Python code raises FatalError / ValueError / struct.error. */
	public static class FatalError extends RuntimeException {
		private static final long serialVersionUID = 1L;
		public FatalError(String message) {
			super(message);
		}
	}

	// --- script vars / configs -------------------------------------------------

	public static final int VGM_FREQUENCY = 44100;

	// script options
	public static final boolean RETUNE_PERIODIC = true;
	public static final boolean VERBOSE = false;
	public static final boolean STRIP_GD3 = false;
	public static final int LENGTH = 0;

	// VGM file identifier
	private static final byte[] VGM_MAGIC_NUMBER = new byte[] { 'V', 'g', 'm', ' ' };

	public static final boolean DISABLE_DUAL_CHIP = true;

	// Supported VGM versions
	private static final long[] SUPPORTED_VER_LIST = new long[] {
		0x00000101L,
		0x00000110L,
		0x00000150L,
		0x00000151L,
		0x00000160L,
		0x00000161L,
	};

	/** One entry of the metadata_offsets tables. type_format null == raw bytes. */
	private static final class MetaField {
		final int offset;
		final int size;
		final String typeFormat;
		MetaField(int offset, int size, String typeFormat) {
			this.offset = offset;
			this.size = size;
			this.typeFormat = typeFormat;
		}
	}

	// VGM metadata offsets. The Python dict holds one identical table per supported
	// version (1.01/1.10/1.50/1.51/1.60/1.61); a single shared table is equivalent.
	private static final Map<String, MetaField> METADATA_TABLE;
	private static final Map<Long, Map<String, MetaField>> METADATA_OFFSETS;
	static {
		Map<String, MetaField> t = new LinkedHashMap<String, MetaField>();
		t.put("vgm_ident", new MetaField(0x00, 4, null));
		t.put("eof_offset", new MetaField(0x04, 4, "<I"));
		t.put("version", new MetaField(0x08, 4, "<I"));
		t.put("sn76489_clock", new MetaField(0x0c, 4, "<I"));
		t.put("ym2413_clock", new MetaField(0x10, 4, "<I"));
		t.put("gd3_offset", new MetaField(0x14, 4, "<I"));
		t.put("total_samples", new MetaField(0x18, 4, "<I"));
		t.put("loop_offset", new MetaField(0x1c, 4, "<I"));
		t.put("loop_samples", new MetaField(0x20, 4, "<I"));
		t.put("rate", new MetaField(0x24, 4, "<I"));
		t.put("sn76489_feedback", new MetaField(0x28, 2, "<H"));
		t.put("sn76489_shift_register_width", new MetaField(0x2a, 1, "B"));
		t.put("ym2612_clock", new MetaField(0x2c, 4, "<I"));
		t.put("ym2151_clock", new MetaField(0x30, 4, "<I"));
		t.put("vgm_data_offset", new MetaField(0x34, 4, "<I"));
		METADATA_TABLE = t;

		Map<Long, Map<String, MetaField>> m = new LinkedHashMap<Long, Map<String, MetaField>>();
		for (long v : SUPPORTED_VER_LIST) {
			m.put(v, METADATA_TABLE);
		}
		METADATA_OFFSETS = m;
	}

	/** A parsed VGM command: command byte plus its (possibly empty/null) payload. */
	public static final class Command {
		public final int command;
		public final byte[] data;
		Command(int command, byte[] data) {
			this.command = command;
			this.data = data;
		}
	}

	// --- instance state --------------------------------------------------------

	private String vgmFilename = "";
	private byte[] data;
	private int pos;

	private final List<Command> commandList = new ArrayList<Command>();
	private byte[] dataBlock = null;
	private final Map<String, byte[]> gd3Data = new HashMap<String, byte[]>();
	private final Map<String, Long> metadata = new HashMap<String, Long>();
	private byte[] vgmIdent = null;

	private long vgmLoopOffset = 0;
	private long vgmLoopLength = 0;
	private long vgmSourceClock = 0;
	private long vgmTargetClock = 0;
	private boolean dualChipModeEnabled = false;

	// constructor - pass in the filename of the VGM
	public VgmStream(String filename) throws Exception {

		this.vgmFilename = filename;

		this.data = Files.readAllBytes(Paths.get(filename));
		this.pos = 0;

		// parse
		validateVgmData();

		// Parse the VGM metadata and validate the VGM version
		parseMetadata();

		this.vgmLoopOffset = metadata.get("loop_offset");
		this.vgmLoopLength = metadata.get("loop_samples");

		// Validation to check we can parse it
		validateVgmVersion();

		// Sanity check this VGM is suitable for this script - must be SN76489 only
		// (the Python repeats the ym2413 test three times; harmless)
		if (metadata.get("sn76489_clock") == 0 || metadata.get("ym2413_clock") != 0) {
			throw new FatalError("This script only supports VGM's for SN76489 PSG");
		}

		// see if this VGM uses Dual Chip mode
		this.dualChipModeEnabled = (metadata.get("sn76489_clock") & 0x40000000L) == 0x40000000L;

		// override/disable dual chip commands in the output stream if required
		if (DISABLE_DUAL_CHIP && this.dualChipModeEnabled) {
			metadata.put("sn76489_clock", metadata.get("sn76489_clock") & 0xbfffffffL);
			this.dualChipModeEnabled = false;
		}

		// take a copy of the clock speed for the VGM processor functions
		this.vgmSourceClock = metadata.get("sn76489_clock");
		this.vgmTargetClock = this.vgmSourceClock;

		// Parse GD3 data and the VGM commands
		parseGd3();
		parseCommands();
	}

	// --- low level stream helpers (mirror StringIO/GzipFile read/seek/tell) -----

	private int tell() {
		return pos;
	}

	private void seek(int offset) {
		pos = offset;
	}

	private void seekRelative(int delta) {
		pos += delta;
	}

	/** Reads up to n bytes; a short read at EOF yields a shorter array, as in Python. */
	private byte[] read(int n) {
		if (pos < 0) {
			pos = 0;
		}
		if (pos >= data.length) {
			pos = Math.max(pos, data.length);
			return new byte[0];
		}
		int avail = Math.min(n, data.length - pos);
		byte[] out = Arrays.copyOfRange(data, pos, pos + avail);
		pos += avail;
		return out;
	}

	private void validateVgmData() throws IOException {
		// Save the current position of the VGM data
		int originalPos = tell();

		seek(0);

		// Perform basic validation by checking for the VGM magic number ('Vgm ')
		if (!Arrays.equals(read(4), VGM_MAGIC_NUMBER)) {
			// Could not find the magic number. The file could be gzipped (e.g. a vgz
			// file). Try un-gzipping the data and trying again.
			seek(0);
			try {
				this.data = gunzip(this.data);
			} catch (IOException e) {
				// IOError is raised if the data is not a valid gzip stream
				throw new FatalError("Data does not appear to be a valid VGM file");
			}
			seek(0);
			if (!Arrays.equals(read(4), VGM_MAGIC_NUMBER)) {
				throw new FatalError("Data does not appear to be a valid VGM file");
			}
		}

		// Seek back to the original position in the VGM data
		seek(originalPos);
	}

	private static byte[] gunzip(byte[] input) throws IOException {
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		InputStream in = new GZIPInputStream(new java.io.ByteArrayInputStream(input));
		try {
			byte[] buf = new byte[8192];
			int r;
			while ((r = in.read(buf)) > 0) {
				out.write(buf, 0, r);
			}
		} finally {
			in.close();
		}
		return out.toByteArray();
	}

	private void parseMetadata() {
		int originalPos = tell();

		metadata.clear();

		// Iterate over the offsets and parse the metadata (all version tables are
		// identical, so the last iteration simply overwrites with the same values)
		for (Map.Entry<Long, Map<String, MetaField>> ver : METADATA_OFFSETS.entrySet()) {
			for (Map.Entry<String, MetaField> e : ver.getValue().entrySet()) {
				MetaField f = e.getValue();
				seek(f.offset);
				byte[] raw = read(f.size);

				if (f.typeFormat != null) {
					metadata.put(e.getKey(), unpackLittleEndian(raw, f.size));
				} else {
					vgmIdent = raw;
				}
			}
		}

		seek(originalPos);
	}

	/** struct.unpack of '<I' / '<H' / 'B' - unsigned little-endian. */
	private static long unpackLittleEndian(byte[] raw, int size) {
		if (raw.length < size) {
			throw new FatalError("unpack requires a string argument of length " + size);
		}
		long v = 0;
		for (int i = size - 1; i >= 0; i--) {
			v = (v << 8) | (raw[i] & 0xff);
		}
		return v;
	}

	private void validateVgmVersion() {
		long version = metadata.get("version");
		for (long v : SUPPORTED_VER_LIST) {
			if (v == version) {
				return;
			}
		}
		throw new FatalError("VGM version is not supported");
	}

	private void parseGd3() {
		int originalPos = tell();

		Map<String, MetaField> table = METADATA_OFFSETS.get(metadata.get("version"));

		// Seek to the start of the GD3 data (relative offset field)
		seek((int) (metadata.get("gd3_offset") + table.get("gd3_offset").offset));

		// Skip 8 bytes ('Gd3 ' string and 4 byte version identifier)
		seekRelative(8);

		// Get the length of the GD3 data, then read it
		long gd3Length = unpackLittleEndian(read(4), 4);
		byte[] gd3Raw = read((int) gd3Length);

		// Parse the GD3 data. All characters (English and Japanese) use two byte
		// encoding. Note: a trailing odd byte is appended to the current field,
		// exactly as the Python does.
		List<byte[]> gd3Fields = new ArrayList<byte[]>();
		ByteArrayOutputStream currentField = new ByteArrayOutputStream();
		int gp = 0;
		while (true) {
			int avail = Math.min(2, Math.max(0, gd3Raw.length - gp));
			if (avail == 0) {
				break;
			}
			byte[] ch = Arrays.copyOfRange(gd3Raw, gp, gp + avail);
			gp += avail;

			if (avail == 2 && ch[0] == 0 && ch[1] == 0) {
				gd3Fields.add(currentField.toByteArray());
				currentField = new ByteArrayOutputStream();
			} else {
				currentField.write(ch, 0, ch.length);
			}
		}

		// Once all the fields have been parsed, create a dict with the data
		// some Gd3 tags dont have notes section
		byte[] gd3Notes = new byte[0];
		byte[] gd3TitleEng = encodeUtf16WithBom(basename(vgmFilename));
		if (gd3Fields.size() > 10) {
			gd3Notes = gd3Fields.get(10);
		}

		gd3Data.clear();
		if (gd3Fields.size() > 8) {

			if (gd3Fields.get(0).length > 0) {
				gd3TitleEng = gd3Fields.get(0);
			}

			// index 9 is read unconditionally here: a 9-field tag raises, as in Python
			gd3Data.put("title_eng", gd3TitleEng);
			gd3Data.put("title_jap", gd3Fields.get(1));
			gd3Data.put("game_eng", gd3Fields.get(2));
			gd3Data.put("game_jap", gd3Fields.get(3));
			gd3Data.put("console_eng", gd3Fields.get(4));
			gd3Data.put("console_jap", gd3Fields.get(5));
			gd3Data.put("artist_eng", gd3Fields.get(6));
			gd3Data.put("artist_jap", gd3Fields.get(7));
			gd3Data.put("date", gd3Fields.get(8));
			gd3Data.put("vgm_creator", gd3Fields.get(9));
			gd3Data.put("notes", gd3Notes);
		} else {
			// WARNING: Malformed/missing GD3 tag
			gd3Data.put("title_eng", gd3TitleEng);
			gd3Data.put("title_jap", new byte[0]);
			gd3Data.put("game_eng", new byte[0]);
			gd3Data.put("game_jap", new byte[0]);
			gd3Data.put("console_eng", new byte[0]);
			gd3Data.put("console_jap", new byte[0]);
			gd3Data.put("artist_eng", encodeUtf16WithBom("Unknown"));
			gd3Data.put("artist_jap", new byte[0]);
			gd3Data.put("date", new byte[0]);
			gd3Data.put("vgm_creator", new byte[0]);
			gd3Data.put("notes", new byte[0]);
		}

		seek(originalPos);
	}

	// -------------------------------------------------------------------------

	private void parseCommands() {
		int originalPos = tell();

		Map<String, MetaField> table = METADATA_OFFSETS.get(metadata.get("version"));

		// Seek to the start of the VGM data (relative offset field)
		seek((int) (metadata.get("vgm_data_offset") + table.get("vgm_data_offset").offset));

		while (true) {
			// Read a byte, this will be a VGM command
			byte[] cmdBytes = read(1);

			// Break if we are at the end of the file
			if (cmdBytes.length == 0) {
				break;
			}
			int command = cmdBytes[0] & 0xff;

			// 0x4f dd - Game Gear PSG stereo, write dd to port 0x06
			// 0x50 dd - PSG (SN76489/SN76496) write value dd
			if (command == 0x4f || command == 0x50) {
				commandList.add(new Command(command, read(1)));

			// 0x51/0x52/0x53/0x54 aa dd - YM2413 / YM2612 p0 / YM2612 p1 / YM2151
			} else if (command == 0x51 || command == 0x52 || command == 0x53 || command == 0x54) {
				commandList.add(new Command(command, read(2)));

			// 0x61 nn nn - Wait n samples, n can range from 0 to 65535
			} else if (command == 0x61) {
				commandList.add(new Command(command, read(2)));

			// 0x62 - Wait 735 samples (60th of a second)
			// 0x63 - Wait 882 samples (50th of a second)
			} else if (command == 0x62 || command == 0x63) {
				commandList.add(new Command(command, null));

			// 0x66 - End of sound data
			} else if (command == 0x66) {
				break;

			// 0x67 0x66 tt ss ss ss ss - Data block
			} else if (command == 0x67) {
				// Skip the compatibility and type bytes (0x66 tt)
				seekRelative(2);

				// Read the size of the data block
				long dataBlockSize = unpackLittleEndian(read(4), 4);

				// Store the data block for later use
				dataBlock = read((int) dataBlockSize);

			// 0x7n - Wait n+1 samples, n can range from 0 to 15
			// 0x8n - YM2612 port 0 address 2A write from the data bank, then wait n samples
			} else if (command >= 0x70 && command <= 0x8f) {
				commandList.add(new Command(command, null));

			// 0xe0 dddddddd - Seek to offset dddddddd in PCM data bank
			} else if (command == 0xe0) {
				commandList.add(new Command(command, read(4)));

			// 0x30 dd - dual chip command
			} else if (command == 0x30) {
				if (dualChipModeEnabled) {
					commandList.add(new Command(command, read(1)));
				}
			}
			// NOTE: any other command byte is silently ignored *without* skipping its
			// operands, so parsing desynchronises. Kept as in the Python original.
		}

		seek(originalPos);
	}

	// -------------------------------------------------------------------------

	/** returns the raw data version of the vgm (equivalent of as_binary(rawheader=True)) */
	public byte[] asBinary() throws Exception {
		return asBinary(true);
	}

	public byte[] asBinary(boolean rawheader) throws Exception {

		long playRate = metadata.get("rate");
		// Python 2 integer division; a rate of 0 raises here (ArithmeticException)
		@SuppressWarnings("unused")
		long playInterval = VGM_FREQUENCY / playRate;

		ByteArrayOutputStream dataBlockOut = new ByteArrayOutputStream();
		ByteArrayOutputStream packetBlock = new ByteArrayOutputStream();

		long packetCount = 0;

		// emit the packet data
		for (Command q : commandList) {

			int command = q.command;
			if (command != 0x50) {

				// non-write command, so flush any pending packet data
				dataBlockOut.write(packB(packetBlock.size()));
				byte[] pb = packetBlock.toByteArray();
				dataBlockOut.write(pb, 0, pb.length);
				packetCount += 1;

				// start new packet
				packetBlock = new ByteArrayOutputStream();

				// see if command is a wait longer than one interval and emit empty
				// packets to compensate
				long wait = 0;
				if (command == 0x61) {
					// int(binascii.hexlify(data), 16): big-endian read of the stored
					// bytes, then byte-swapped below to recover the little-endian value
					long t = hexlifyToInt(q.data);
					wait = ((t & 255) * 256) + (t >> 8);
				} else {
					if (command == 0x62) {
						wait = 735;
					} else {
						if (command == 0x63) {
							wait = 882;
						}
					}
				}

				if (wait != 0) {
					// Python 2 floor division, twice (inner and outer)
					long intervals = wait / (VGM_FREQUENCY / playRate);
					if (intervals == 0) {
						// ERROR in data stream, wait value was not divisible by play_rate
						return null;
					}

					// emit empty packet headers to simulate wait commands
					intervals -= 1;
					while (intervals > 0) {
						dataBlockOut.write(0);
						intervals -= 1;
						packetCount += 1;
					}
				}

			} else {
				if (q.data != null) {
					packetBlock.write(q.data, 0, q.data.length);
				}
			}
		}

		// eof
		dataBlockOut.write(0xFF); // signal EOF

		ByteArrayOutputStream headerBlock = new ByteArrayOutputStream();
		// emit the play rate
		headerBlock.write(packB((int) (playRate & 0xff)));
		headerBlock.write(packB((int) (packetCount & 0xff)));
		headerBlock.write(packB((int) ((packetCount >> 8) & 0xff)));

		long duration = packetCount / playRate; // Python 2 integer division
		int durationMm = (int) (duration / 60.0d);
		int durationSs = (int) (duration % 60.0d);
		headerBlock.write(packB(durationMm)); // minutes
		headerBlock.write(packB(durationSs)); // seconds

		// output the final byte stream
		ByteArrayOutputStream outputBlock = new ByteArrayOutputStream();

		// send header
		byte[] hb = headerBlock.toByteArray();
		outputBlock.write(packB(hb.length));
		outputBlock.write(hb, 0, hb.length);

		// send title
		byte[] title = encodeAsciiIgnore(decodeUtf16(gd3Data.get("title_eng")));

		if (title.length > 254) {
			title = Arrays.copyOfRange(title, 0, 254);
		}
		outputBlock.write(packB(title.length + 1)); // title string length
		outputBlock.write(title, 0, title.length);
		outputBlock.write(packB(0)); // zero terminator

		// send author
		byte[] author = encodeAsciiIgnore(decodeUtf16(gd3Data.get("artist_eng")));

		// use filename if no author listed
		if (author.length == 0) {
			author = basename(vgmFilename).getBytes(StandardCharsets.ISO_8859_1);
		}

		if (author.length > 254) {
			author = Arrays.copyOfRange(author, 0, 254);
		}
		outputBlock.write(packB(author.length + 1)); // author string length
		outputBlock.write(author, 0, author.length);
		outputBlock.write(packB(0)); // zero terminator

		// send data with or without header
		byte[] db = dataBlockOut.toByteArray();
		if (rawheader) {
			outputBlock.write(db, 0, db.length);
			return outputBlock.toByteArray();
		} else {
			return db;
		}
	}

	// --- helpers ---------------------------------------------------------------

	/** struct.pack('B', n) - raises when out of range, as Python does. */
	private static int packB(int n) {
		if (n < 0 || n > 255) {
			throw new FatalError("ubyte format requires 0 <= number <= 255 (got " + n + ")");
		}
		return n;
	}

	/** int(binascii.hexlify(data), 16) - big-endian integer over the raw bytes. */
	private static long hexlifyToInt(byte[] data) {
		if (data == null || data.length == 0) {
			// int('', 16) raises ValueError
			throw new FatalError("invalid literal for int() with base 16: ''");
		}
		long v = 0;
		for (byte b : data) {
			v = (v << 8) | (b & 0xff);
		}
		return v;
	}

	/**
	 * Python's "utf_16" encode as implemented by Jython: it delegates to the Java
	 * "UTF-16" charset, i.e. a big-endian BOM (FE FF) followed by big-endian units.
	 * (CPython would emit a little-endian BOM here; Jython is the reference.)
	 */
	private static byte[] encodeUtf16WithBom(String s) {
		return s.getBytes(StandardCharsets.UTF_16);
	}

	/**
	 * Python's "utf_16" decode as implemented by Jython: Java "UTF-16", which honours
	 * a BOM when present but defaults to BIG-endian without one. GD3 tags store
	 * little-endian text without BOM, so real tag strings decode to CJK-range garbage
	 * and are then wiped by encode('ascii','ignore') - that is exactly what the
	 * current .vgc files contain, so the behaviour is preserved verbatim.
	 */
	private static String decodeUtf16(byte[] raw) {
		if (raw == null) {
			return "";
		}
		return new String(raw, StandardCharsets.UTF_16);
	}

	/** str.encode('ascii', 'ignore') - drops every character above U+007F. */
	private static byte[] encodeAsciiIgnore(String s) {
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		for (int i = 0; i < s.length(); i++) {
			char c = s.charAt(i);
			if (c < 128) {
				out.write(c);
			}
		}
		return out.toByteArray();
	}

	/** os.path.basename - platform dependent, like Python's posixpath/ntpath split. */
	private static String basename(String path) {
		int idx = path.lastIndexOf('/');
		if (File.separatorChar == '\\') {
			idx = Math.max(idx, path.lastIndexOf('\\'));
		}
		return idx < 0 ? path : path.substring(idx + 1);
	}

	// --- accessors -------------------------------------------------------------

	public Map<String, Long> getMetadata() {
		return metadata;
	}

	public byte[] getVgmIdent() {
		return vgmIdent;
	}

	public Map<String, byte[]> getGd3Data() {
		return gd3Data;
	}

	public List<Command> getCommandList() {
		return commandList;
	}

	public byte[] getDataBlock() {
		return dataBlock;
	}

	public String getVgmFilename() {
		return vgmFilename;
	}

	public long getVgmLoopOffset() {
		return vgmLoopOffset;
	}

	public long getVgmLoopLength() {
		return vgmLoopLength;
	}

	public long getVgmSourceClock() {
		return vgmSourceClock;
	}

	public long getVgmTargetClock() {
		return vgmTargetClock;
	}

	public boolean isDualChipModeEnabled() {
		return dualChipModeEnabled;
	}
}
