package com.widedot.toolbox.audio.vgm2vgc;

import org.apache.commons.configuration2.tree.ImmutableNode;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.Binary;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;



import com.widedot.m6809.util.FileUtil;

import com.widedot.toolbox.audio.vgm2vgc.pack.VgmPacker;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Vgm2VgcPlugin {

	/** decoder buffer size ; below 256 the packer emits 8-bit LZ4 offsets */
	private static final int PACK_BUFFER_SIZE = 255;


	public static String INPUT_EXT1 = ".vgm";
	public static String INPUT_EXT2 = ".vgz";
	public static String BIN_EXT = ".vgc";

	public static String filename;
	public static String genbinary;

	public static byte[] run() throws Exception {

		log.debug("Convert {} or {} to {}", INPUT_EXT1, INPUT_EXT2, BIN_EXT);
		
		// check input file
		File file = new File(filename);
		if (!file.exists()) {
			String m = "filename: "+filename+" does not exists !";
			log.error(m);
			throw new Exception(m);
		}

		ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );

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
		
		// skip processing if input file is older than output file
		long inputLastModified = file.lastModified();
		long outputLastModified = (new File(outFileName)).lastModified();
		
		if (inputLastModified > outputLastModified) {
		
			log.debug("Generating: {}", outFileName);
			
			// Keep SN76489 data only
			VGMInterpreter vgm = new VGMInterpreter(file);
			byte[] intro = vgm.getIntroData();
			byte[] loop = vgm.getLoopData();
	
			if (intro != null) {
				ByteArrayOutputStream tmpOS = new ByteArrayOutputStream();
				tmpOS.write(vgm.getIntroHeader());
				tmpOS.write(intro);

				String tmpFileName = file.getAbsolutePath() + ".sn76489.intro.vgm";
				try (OutputStream fileStream = new FileOutputStream(tmpFileName)) {
					tmpOS.writeTo(fileStream);
				}
				tmpOS.close();

				// Convert vgm to vgc
				intro = VgmPacker.pack(tmpFileName, PACK_BUFFER_SIZE, false);

				// the temporary file carries a .vgm extension : left behind it would
				// be picked up as an input by the next directory scan
				Files.deleteIfExists(Paths.get(tmpFileName));
			}
			
			if (loop != null) {
				ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
				outputStream.write(vgm.getLoopHeader());
				outputStream.write(vgm.getCache());
				outputStream.write(loop);

				String tmpFileName = file.getAbsolutePath() + ".sn76489.loop.vgm";
				try (OutputStream fileStream = new FileOutputStream(tmpFileName)) {
					outputStream.writeTo(fileStream);
				}
				outputStream.close();

				// Convert vgm to vgc
				loop = VgmPacker.pack(tmpFileName, PACK_BUFFER_SIZE, false);

				Files.deleteIfExists(Paths.get(tmpFileName));
			}
	
			ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
			if (intro != null) {
				outputStream.write(((intro.length+2) >> 8) & 0xff); // +2 will place the cursor to entry point
				outputStream.write((intro.length+2) & 0xff);
				outputStream.write(intro);
			} else {
				outputStream.write(0);
				outputStream.write(2);
			}
			
			if (loop != null) {
				outputStream.write(loop);
			}
			
			try (OutputStream fileStream = new FileOutputStream(outFileName)) {
				outputStream.writeTo(fileStream);
			}
			outputStream.close();

			return outputStream.toByteArray();
			
		} else {
			log.debug("Build cache for {}", outFileName);
			return Files.readAllBytes(Paths.get(outFileName));
		}
	}


	/**
	 * Handler for the <vgm2vgc> element, registered by the builder.
	 */
	public static ObjectDataInterface getObject(ImmutableNode node, BuildContext ctx) throws Exception {
	  
	//read input xml
	String filename = Attribute.getStringOpt(node, ctx.defaults, "filename", "vgm2vgc.filename");
	String genbinary = Attribute.getStringOpt(node, ctx.defaults, "genbinary", "vgm2vgc.genbinary");


	if ((filename == null || filename.equals(""))) {
		String m = "An input filename should be provided for vgm2vgc!";
		log.error(m);
		throw new Exception(m);
	}
	  
	if (filename != null) filename = ctx.path + File.separator + filename;
	if (genbinary != null) genbinary = ctx.path + File.separator + genbinary;
	  
	
	  
	Vgm2VgcPlugin.filename = filename;
	Vgm2VgcPlugin.genbinary = genbinary; 
			byte[] data = Vgm2VgcPlugin.run();
	return new Binary(data);
	}
}