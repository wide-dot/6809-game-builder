package com.widedot.m6809.gamebuilder.plugin.sap;

import java.io.File;
import com.widedot.m6809.gamebuilder.spi.BuildContext;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.sap.util.Sap;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class SapPlugin {
	
	public static void run(ImmutableNode node, BuildContext ctx, MediaDataInterface media) throws Exception {
    	
		log.debug("Processing sap ...");
		
		String filename = Attribute.getString(node, ctx, "filename");
		Integer format = Attribute.getInteger(node, ctx, "format", Sap.SAP_FORMAT1);
   		
		// create destination directory
		String dirname = ctx.path + File.separator + ctx.settings.get("dist.dir");
	    File dir = new File(dirname);
	    dir.mkdirs();
	    String absFilename = dirname + File.separator + filename;
		
        Sap sap = new Sap(media.getInterleavedData(), format);
        for (java.nio.file.Path written : sap.write(absFilename)) {
            ctx.outputs.record(written);
        }
        
		log.debug("End of processing sap");
	}

}
