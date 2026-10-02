package com.widedot.toolbox.audio.vgm2ymm;

import org.apache.commons.configuration2.tree.ImmutableNode;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.Binary;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.cache.BuildCache;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

import com.widedot.m6809.util.FileUtil;
import com.widedot.m6809.util.zx0.Compressor;
import com.widedot.m6809.util.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Vgm2YmmPlugin {
	
	public static String CODEC_NONE = "none";
	public static String CODEC_ZX0 = "zx0";
	public static String INPUT_EXT1 = ".vgm";
	public static String INPUT_EXT2 = ".vgz";
	public static String BIN_EXT = ".ymm";
	public static int MAX_OFFSET_YMM = 512;
	public static int MAX_OUTPUT_SIZE = 16384; // Maximum output size in bytes

	/** bump when the converter's output changes : the cache would replay the old one */
	private static final String CACHE_VERSION = "1";
	
	public static String filename;
	public static String genbinary;
	public static String codec;
	public static String drumStr;
	public static int[] drum;

	public static byte[] run() throws Exception {
		
		log.debug("Convert {} or {} to {}", INPUT_EXT1, INPUT_EXT2, BIN_EXT);
		
		// check input file
		File file = new File(filename);
		if (!file.exists()) {
		  String m = "filename: "+filename+" does not exists !";
		  log.error(m);
		  throw new Exception(m);
		}
		
		// default values
		if (codec == null) {
			codec = CODEC_NONE;
		}

		ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );
		
		drum = null;
		if (drumStr != null) {
			String[] drumValues = drumStr.split(",");
			drum = new int[3];
			drum[0] = Integer.decode(drumValues[0]);
			drum[1] = Integer.decode(drumValues[1]);
			drum[2] = Integer.decode(drumValues[2]);
		}
		
		if (!file.isDirectory()) {
			
			// Single file processing
			outputStream.write(convertFile(file));
			
		} else {
			
			// Directory processing
			processDirectory(outputStream, file, INPUT_EXT1);
			processDirectory(outputStream, file, INPUT_EXT2);
			
		}
		log.debug("Conversion ended sucessfully.");

		return outputStream.toByteArray();
	}
	
	
	private static void processDirectory(ByteArrayOutputStream outputStream, File file, String fileExt) throws Exception {
		
		log.debug("Process each {} file of the directory: {}", fileExt, file.getAbsolutePath());

		File[] files = file.listFiles((d, name) -> name.endsWith(fileExt));
		for (File curFile : files) {
			outputStream.write(convertFile(curFile));
		}
	}
	
	private static byte[] convertFile(File file) throws Exception {
	
		String outFileName;
		if (genbinary == null || genbinary.equals(""))
		{
			// output is not specified, produce file in same directory as input file
			outFileName = FileUtil.removeExtension(file.getAbsolutePath()) + BIN_EXT;
		} else {
			if (Files.isDirectory(Paths.get(genbinary))) {
				// output directory is specified
				outFileName = genbinary + File.separator + FileUtil.removeExtension(file.getName()) + BIN_EXT;
			} else {
				// output file is specified
				outFileName = genbinary;
			}
		}
		
		Files.createDirectories(Paths.get(FileUtil.getDir(outFileName)));
		
		// the output is a pure function of the input bytes and the options, replayed
		// from the build cache : never guessed from file dates, which a fresh clone
		// sets to the checkout time in no defined order
		BuildCache.Entry entry = BuildCache.entry("vgm2ymm", CACHE_VERSION)
				.keyString(codec + "|" + drumStr)
				.keyBytes(Files.readAllBytes(file.toPath()));
		byte[] result = entry.findBlob();
		if (result == null) {
			log.debug("Generating: {}", outFileName);
			result = convert(file);
			entry.storeBlob(result);
		}
		FileUtil.writeIfChanged(Paths.get(outFileName), result);
		return result;
	}

	private static byte[] convert(File file) throws Exception {
		VGMInterpreter vGMInterpreter = new VGMInterpreter(file, drum);
		int[] stream = vGMInterpreter.getArrayOfInt();
		int loopAt = vGMInterpreter.loopMarkerHit;
		int end = vGMInterpreter.getLastIndex();

		byte[] intro = loopAt > 0 ? slice(stream, 0, loopAt, true) : null;
		byte[] loop = end - loopAt > 0 ? slice(stream, loopAt, end, false) : null;
		if (codec.equals(CODEC_ZX0)) {
			intro = zx0("intro", intro);
			loop = zx0("loop", loop);
		}
		byte[] output = assemble(intro, loop);

		// Check if the final output size exceeds the maximum allowed size
		if (output.length > MAX_OUTPUT_SIZE) {
			String errorMsg = String.format("Compressed output size (%d bytes) exceeds maximum allowed size (%d bytes) for file: %s", 
				output.length, MAX_OUTPUT_SIZE, file.getName());
			log.error(errorMsg);
			throw new IOException(errorMsg);
		}
		return output;
	}

	/** stream[from, to[ as bytes ; an intro also carries the 0x39 end marker */
	private static byte[] slice(int[] stream, int from, int to, boolean endMarker) {
		byte[] part = new byte[to - from + (endMarker ? 1 : 0)];
		for (int b = from; b < to; b++)
			part[b - from] = (byte) stream[b];
		if (endMarker)
			part[to - from] = 0x39;
		return part;
	}

	private static byte[] zx0(String name, byte[] data) {
		if (data == null)
			return null;
		log.debug("Compress {} data with zx0.", name);
		int[] delta = { 0 };
		byte[] packed = new Compressor().compress(new Optimizer().optimize(data, 0, MAX_OFFSET_YMM, 8, false), data, 0, false, false, delta);
		log.debug("Original size: {}, Packed size: {}, Delta: {}", data.length, packed.length, delta[0]);
		return packed;
	}

	/** the intro offset (+2 places the cursor on the entry point), the intro, then the loop */
	private static byte[] assemble(byte[] intro, byte[] loop) throws IOException {
		ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
		if (intro != null) {
			outputStream.write(((intro.length+2) >> 8) & 0xff);
			outputStream.write((intro.length+2) & 0xff);
			outputStream.write(intro);
		} else {
			outputStream.write(0);
			outputStream.write(2);
		}
		if (loop != null) {
			outputStream.write(loop);
		}
		return outputStream.toByteArray();
	}
	

	/**
	 * Handler for the <vgm2ymm> element, registered by the builder.
	 */
	public static ObjectDataInterface getObject(ImmutableNode node, BuildContext ctx) throws Exception {
	  
	  //read input xml
	  String filename = Attribute.getStringOpt(node, ctx, "filename");
	  String genbinary = Attribute.getStringOpt(node, ctx, "genbinary");
	  String codec = Attribute.getStringOpt(node, ctx, "codec");
	  String drum = Attribute.getStringOpt(node, ctx, "dac2drum");


	  if ((filename == null || filename.equals(""))) {
		  String m = "An input filename should be provided for vgm2ymm!";
		  log.error(m);
		  throw new Exception(m);
	  }
	  
	  if (filename != null) filename = ctx.path + File.separator + filename;
	  if (genbinary != null) genbinary = ctx.path + File.separator + genbinary;
	  
	  
		Vgm2YmmPlugin.filename = filename;
		Vgm2YmmPlugin.genbinary = genbinary; 
		Vgm2YmmPlugin.codec = codec;
		Vgm2YmmPlugin.drumStr = drum;
			byte[] data = Vgm2YmmPlugin.run();
	return new Binary(data);
	}
}