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

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
	}

	@Override
	public void run() {
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
    private String outputFile;
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

		    List<HierarchicalConfiguration<ImmutableNode>> processingFields = config.configurationsAt("processing");
	    	for(HierarchicalConfiguration<ImmutableNode> processing : processingFields)
	    	{
			    outputDir = path+processing.getString("[@dir-out]");
			    linear = processing.getInteger("encoding[@linear]", null);
			    planar = processing.getInteger("encoding[@planar]", null);
			    
			    List<HierarchicalConfiguration<ImmutableNode>> imagesetFields = processing.configurationsAt("imageset");
		    	for(HierarchicalConfiguration<ImmutableNode> imageset : imagesetFields)
		    	{			    
		    		outputFile = path+imageset.getString("[@file-out]");
		    		System.out.println("outputDir:"+outputDir+" linear:"+linear+" planar:"+planar+" outputFile:"+outputFile);
				    
				    List<HierarchicalConfiguration<ImmutableNode>> imagesFields = imageset.configurationsAt("images");
			    	for(HierarchicalConfiguration<ImmutableNode> images : imagesFields)
			    	{
					    List<HierarchicalConfiguration<ImmutableNode>> imageFields = images.configurationsAt("image");
				    	for(HierarchicalConfiguration<ImmutableNode> image : imageFields)
				    	{
				    		imageName = image.getString("[@name]");
				    		imageFile = image.getString("[@file]");
				    		
						    List<HierarchicalConfiguration<ImmutableNode>> subsetFields = images.configurationsAt("subset");
					    	for(HierarchicalConfiguration<ImmutableNode> subset : subsetFields)
					    	{		
					    		subsetType = subset.getString("[@type]");
					    		subsetMirror = subset.getString("[@mirror]");
					    		
					    		process();
					    	}
					    	
						    List<HierarchicalConfiguration<ImmutableNode>> imageSubsetFields = image.configurationsAt("subset");
					    	for(HierarchicalConfiguration<ImmutableNode> imageSubset : imageSubsetFields)
					    	{		
					    		subsetType = imageSubset.getString("[@type]");
					    		subsetMirror = imageSubset.getString("[@mirror]");
					    		
					    		process();
					    	}
				    	}
			    	}
		    	}
	    	}
		}
		catch (ConfigurationException cex)
		{
		    // Something went wrong
		}
	}
	
	private void process() {
		System.out.println("subset type:"+subsetType+" mirror:"+subsetMirror+" image name:"+imageName+" file:"+imageFile);		
	}
}