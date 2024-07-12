package com.widedot.m6809.gamebuilder.plugin.hfe;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;
import com.widedot.m6809.util.OSValidator;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class HfePlugin {
	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing hfe ...");
		
		String filename = Attribute.getString(node, defaults, "filename", "hfe.filename");
		
		// create destination directory
		String dirname = path + File.separator + Settings.values.get("dist.dir");
	    File dir = new File(dirname);
	    dir.mkdirs();
	    String absFilename = dirname + File.separator + filename;
		
	    // produce hxcfe input file
	    String tmpfile = absFilename+".fd";
        Path tmpoutputFile = Paths.get(tmpfile);
        Files.deleteIfExists(tmpoutputFile);
        Files.createFile(tmpoutputFile);
        Files.write(tmpoutputFile, media.getInterleavedData());

	    // convert to hfe
        String hxcfe;
        if (OSValidator.IS_WINDOWS) {
        	hxcfe = "hxcfe.exe";
        } else {
        	hxcfe = "hxcfe";
        }
		List<String> command = new ArrayList<String>(List.of(
				hxcfe,
				"-finput:"+tmpoutputFile,
				"-conv:HXC_HFE",
				"-foutput:"+absFilename			   
				));
		
		log.debug("Command: {}", command);
		
		ProcessBuilder pb = new ProcessBuilder(command);
		if(log.isDebugEnabled()){
			pb.inheritIO();
		}
		Process p = pb.start();
		
		if (p.waitFor() != 0) {
			throw new Exception ("HXCFE error !");
		}	
		
        Files.deleteIfExists(tmpoutputFile);
        
		log.debug("End of processing hfe");
	}

}
