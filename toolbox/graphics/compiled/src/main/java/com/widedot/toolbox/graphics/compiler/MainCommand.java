package com.widedot.toolbox.graphics.compiler;

import java.io.File;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.ex.ConfigurationException;
import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.lang3.exception.ExceptionUtils;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

import com.widedot.m6809.gamebuilder.util.FileUtil;
import com.widedot.toolbox.graphics.compiler.imageset.ImageSet;
import com.widedot.toolbox.graphics.compiler.transformer.mirror.Mirror;

/**
 * 6809 compiled graphics generator
 */

@Command(name = "gfxcomp", description = "6809 compile / compress graphics")
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
				log.error("Input file "+configurationFile+" does not exists !");
			} else {
				try {
					gfxcomp(paramFile);
					log.info("Done.");
				} catch (Exception e) {
					log.error(ExceptionUtils.getStackTrace(e));
				}
			}
		}
	}

    private String path;	
    private ImageSet imagesetGenerator;
    
    // process attributes
    private String outputDir;
    
    // imageset attributes
    private Integer imagesetType;
    private String imagesetFile;

    // image attributes
    private String imageName;
    private String imageFile;
    private Integer imageIndex;
    
    // memory attributes
    private Integer memoryLinearBits;
    private Integer memoryPlanarBits;
    private Integer memoryLineBytes;
    private Integer memoryNbPlanes;
    
    // encoder attributes
    private String encoderType;
    private String encoderMirror;
    private Integer encoderShift;
    private String encoderPosition;
	
	private void gfxcomp(File paramFile) throws Exception {
	    
	    path = FileUtil.getParentDir(paramFile);
		
		Configurations configs = new Configurations();
		try
		{
		    XMLConfiguration config = configs.xml(paramFile);

		    // set up compiled image parameters and parse all child imageset and images
		    List<HierarchicalConfiguration<ImmutableNode>> processFields = config.configurationsAt("process");
	    	for(HierarchicalConfiguration<ImmutableNode> process : processFields)
	    	{
			    outputDir = path+process.getString("[@dir-out]");
		    	getMemoryInfo(process.configurationAt("memory"));
			    
			    // process images in imageset, will generate an imageset index and produce compiled images
    			imagesetGenerator = new ImageSet(imagesetType);
			    List<HierarchicalConfiguration<ImmutableNode>> imagesetFields = process.configurationsAt("imageset");
		    	for(HierarchicalConfiguration<ImmutableNode> imageset : imagesetFields)
		    	{			    
		    		imagesetType = imageset.getInteger("[@type]", null);
		    		imagesetFile = path+imageset.getString("[@file-out]");
		    		parseImages(imageset);
		    	}
		    	if (imagesetFields.size() != 0 && imagesetFile != null) {
		    		imagesetGenerator.generate(imagesetFile);
		    	}
		    	
			    // process images outside an imageset, will produce compiled images only	
		    	imagesetGenerator = null;
		    	imagesetFile = null;
		    	parseImages(process);
	    	}
		}
		catch (ConfigurationException cex)
		{
			log.error("Error reading xml configuration file.");
			log.error(ExceptionUtils.getStackTrace(cex));
		}
	}

	private void parseImages(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		
		// parse all images
	    List<HierarchicalConfiguration<ImmutableNode>> imagesFields = node.configurationsAt("images");
    	for(HierarchicalConfiguration<ImmutableNode> images : imagesFields)
    	{
    		// parse each image inside images
		    List<HierarchicalConfiguration<ImmutableNode>> imageFields = images.configurationsAt("image");
	    	for(HierarchicalConfiguration<ImmutableNode> image : imageFields)
	    	{
	    		parseImage(image);
	    		
	    		// process global encoder at images level
			    List<HierarchicalConfiguration<ImmutableNode>> encoderFields = images.configurationsAt("encoder");
		    	for(HierarchicalConfiguration<ImmutableNode> encoder : encoderFields)
		    	{		
		    		getEncoderInfo(encoder);
		    		process();
		    	}
	    	} 	
    	}	
    	
		// parse each lone image (outside images)
	    List<HierarchicalConfiguration<ImmutableNode>> loneImageFields = node.configurationsAt("image");
    	for(HierarchicalConfiguration<ImmutableNode> image : loneImageFields)
    	{
    		parseImage(image);
    	}	       	
	}
	
	private void parseImage(HierarchicalConfiguration<ImmutableNode> image) throws Exception {
		
		// parse image info
		imageName = image.getString("[@name]");
		imageFile = path+image.getString("[@file]");
		imageIndex = image.getInteger("[@index]", null);
		
		// process image specific encoder		    	
	    List<HierarchicalConfiguration<ImmutableNode>> imageEncoderFields = image.configurationsAt("encoder");
    	for(HierarchicalConfiguration<ImmutableNode> imageEncoder : imageEncoderFields)
    	{		
    		getEncoderInfo(imageEncoder);    		
    		process();
    	}
	}

	private void getMemoryInfo(HierarchicalConfiguration<ImmutableNode> node) {
		memoryLinearBits = node.getInteger("[@linearBits]", 4);
		memoryPlanarBits = node.getInteger("[@planarBits]", 8);
		memoryLineBytes = node.getInteger("[@lineBytes]", 8);
		memoryNbPlanes = node.getInteger("[@nbPlanes]", 8);
	}	
	
	private void getEncoderInfo(HierarchicalConfiguration<ImmutableNode> node) {
		encoderType = node.getString("[@name]", Image.TYPE_DRAW);
		encoderMirror = node.getString("[@mirror]", Mirror.NONE);
		encoderShift = node.getInteger("[@shift]", 0);   
		encoderPosition = node.getString("[@position]", Image.POSITION_CENTER);
	}

	private void process() throws Exception {
		log.debug("process - image name:"+imageName+" file:"+imageFile);
		
		// TODO créer un objet memory et le passer en paramètre
		// TODO créer un objet générique pour les encoder et passer une liste en parametre
		Image img = new Image(imageName, imageIndex, imageFile, encoderType, memoryLinearBits, memoryPlanarBits, encoderMirror, encoderShift, encoderPosition);
		img.encode(outputDir);
		
		if (imagesetGenerator != null) {
			imagesetGenerator.addImage(img);
		}
	}
}