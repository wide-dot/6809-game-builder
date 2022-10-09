package com.widedot.toolbox.graphics.compiled;

import java.io.File;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.ex.ConfigurationException;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.util.FileUtil;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/**
 * 6809 compiled graphics generator
 */

@Command(name = "gfxcomp", description = "6809 compiled graphics generator")
@Slf4j
public class MainCommand implements Runnable {

	@Option(names = { "-f", "--file" }, paramLabel = "configuration file", description = "list of images to process")
	String configurationFile;
	
    @Option(names = { "-v", "--verbose"}, description = "Verbose mode. Helpful for troubleshooting.")
    private boolean verbose = false;

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
	}

	@Override
	public void run() {
		
		// verbose mode
	    ch.qos.logback.classic.Logger root = (ch.qos.logback.classic.Logger) org.slf4j.LoggerFactory.getLogger(ch.qos.logback.classic.Logger.ROOT_LOGGER_NAME);
		if (verbose) {
		    root.setLevel(ch.qos.logback.classic.Level.DEBUG);
		} else {
			root.setLevel(ch.qos.logback.classic.Level.INFO);
		}
		
		log.info("6809 compiled graphics generator");

		if (configurationFile != null) {
			log.info("Process {}", configurationFile);

			File paramFile = new File(configurationFile);
			if (!paramFile.exists() || paramFile.isDirectory()) {
				log.error("Input file does not exists !");
			} else {
				try {
					gfxcomp(paramFile);
				} catch (Exception e) {
					log.error("Error");
				}
			}
		}
	}

    private String outputDir;
    private Integer linear;
    private Integer planar;
    private String imagesetFile;
    private String subsetType;
    private String subsetMirror;	    
    private String imageName;
    private String imageFile;
	
	private void gfxcomp(File paramFile) throws Exception {
	    
	    String path = FileUtil.getParentDir(paramFile);
		
		Configurations configs = new Configurations();
		try
		{
		    XMLConfiguration config = configs.xml(paramFile);

		    // set up compiled image parameters and parse all child imageset and images
		    List<HierarchicalConfiguration<ImmutableNode>> processingFields = config.configurationsAt("processing");
	    	for(HierarchicalConfiguration<ImmutableNode> processing : processingFields)
	    	{
			    outputDir = path+processing.getString("[@dir-out]");
			    linear = processing.getInteger("encoding[@linear]", null);
			    planar = processing.getInteger("encoding[@planar]", null);
			    
			    // process images in imageset, will generate an imageset index and produce compiled images
			    List<HierarchicalConfiguration<ImmutableNode>> imagesetFields = processing.configurationsAt("imageset");
		    	for(HierarchicalConfiguration<ImmutableNode> imageset : imagesetFields)
		    	{			    
		    		imagesetFile = path+imageset.getString("[@file-out]");
		    		log.debug("outputDir:"+outputDir+" linear:"+linear+" planar:"+planar);
				    
		    		parseImages(imageset);

		    	}
		    	
			    // process images outside an imageset, will produce compiled images only		    	
		    	imagesetFile = null;
		    	parseImages(processing);
	    	}
		}
		catch (ConfigurationException cex)
		{
			log.error("Error reading xml configuration file.");
		}
	}

	private void parseImages(HierarchicalConfiguration<ImmutableNode> base) {
		
		// parse all images
	    List<HierarchicalConfiguration<ImmutableNode>> imagesFields = base.configurationsAt("images");
    	for(HierarchicalConfiguration<ImmutableNode> images : imagesFields)
    	{
    		// parse each image inside images
		    List<HierarchicalConfiguration<ImmutableNode>> imageFields = images.configurationsAt("image");
	    	for(HierarchicalConfiguration<ImmutableNode> image : imageFields)
	    	{
	    		parseImage(image);
	    		
	    		// process global subset at images level
			    List<HierarchicalConfiguration<ImmutableNode>> subsetFields = images.configurationsAt("subset");
		    	for(HierarchicalConfiguration<ImmutableNode> subset : subsetFields)
		    	{		
		    		subsetType = subset.getString("[@type]");
		    		subsetMirror = subset.getString("[@mirror]");
		    		
		    		process();
		    	}
	    	} 	
    	}	
    	
		// parse each lone image (outside images)
	    List<HierarchicalConfiguration<ImmutableNode>> loneImageFields = base.configurationsAt("image");
    	for(HierarchicalConfiguration<ImmutableNode> image : loneImageFields)
    	{
    		parseImage(image);
    	}	       	
	}
	
	private void parseImage(HierarchicalConfiguration<ImmutableNode> image) {
		
		// parse image info
		imageName = image.getString("[@name]");
		imageFile = image.getString("[@file]");
		
		// process image specific subset		    	
	    List<HierarchicalConfiguration<ImmutableNode>> imageSubsetFields = image.configurationsAt("subset");
    	for(HierarchicalConfiguration<ImmutableNode> imageSubset : imageSubsetFields)
    	{		
    		subsetType = imageSubset.getString("[@type]");
    		subsetMirror = imageSubset.getString("[@mirror]");
    		
    		process();
    	}			
	}
	
	private void process() {
		log.debug("imageset:"+imagesetFile+" subset type:"+subsetType+" mirror:"+subsetMirror+" image name:"+imageName+" file:"+imageFile);		
	}
}