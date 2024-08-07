package com.widedot.m6809.gamebuilder.plugin.fd;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class FdPlugin {
	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing fd ...");
		
		String filename = Attribute.getString(node, defaults, "filename", "fd.filename");
		
		// create destination directory
		String dirname = path + File.separator + Settings.values.get("dist.dir");
	    File dir = new File(dirname);
	    dir.mkdirs();
	    String absFilename = dirname + File.separator + filename;

	    // output file
        Path outputFile = Paths.get(absFilename);
        try {
            Files.deleteIfExists(outputFile);
            Files.createFile(outputFile);
            Files.write(outputFile, media.getInterleavedData());
        } catch (IOException e) {
            e.printStackTrace();
        }
		
		log.debug("End of processing fd");
	}

}
