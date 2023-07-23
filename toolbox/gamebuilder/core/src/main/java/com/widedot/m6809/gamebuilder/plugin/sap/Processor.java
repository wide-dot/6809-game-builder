package com.widedot.m6809.gamebuilder.plugin.sap;

import java.io.File;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Settings;
import com.widedot.m6809.gamebuilder.plugin.sap.util.Sap;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Processor {
	
	public static void run(ImmutableNode node, String path, Defaults defaults, Defines defines, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing sap ...");
		
		String filename = Attribute.getString(node, defaults, "filename", "sap.filename");
		Integer format = Attribute.getInteger(node, defaults, "format", "sap.format", Sap.SAP_FORMAT1);
   		
		// create destination directory
		String dirname = path + File.separator + Settings.values.get("dist.dir");
	    File dir = new File(dirname);
	    dir.mkdirs();
	    String absFilename = dirname + File.separator + filename;
		
        Sap sap = new Sap(media.getInterleavedData(), format);
        sap.write(absFilename);
        
		log.debug("End of processing sap");
	}

}
