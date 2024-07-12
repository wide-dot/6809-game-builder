package com.widedot.m6809.gamebuilder.plugin.sd;

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
public class SdPlugin {
	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing sd ...");
		
		String filename = Attribute.getString(node, defaults, "filename", "sd.filename");
   		
   		// interleave data
		byte[] data = media.getInterleavedData();
		
		// create destination directory
		String dirname = path + File.separator + Settings.values.get("dist.dir");
	    File dir = new File(dirname);
	    dir.mkdirs();
	    String absFilename = dirname + File.separator + filename;

	    // output file
        final byte[] sdBytes = new byte[data.length*2];

        for (int ifd = 0, isd = 0; ifd < data.length; ifd++) {
            sdBytes[isd] = data[ifd];
            isd++;
            
            // fill with 256x(0xFF) each 256 bytes
            if ((ifd + 1) % 256 == 0)
                for (int i = 0; i < 256; i++)
                    sdBytes[isd++] = (byte) 0xFF;
        }

        Path outputFile = Paths.get(absFilename);
        try {
            Files.deleteIfExists(outputFile);
            Files.createFile(outputFile);
            Files.write(outputFile, sdBytes);
        } catch (IOException e) {
            e.printStackTrace();
        }
		
		log.debug("End of processing sd");
	}

}
