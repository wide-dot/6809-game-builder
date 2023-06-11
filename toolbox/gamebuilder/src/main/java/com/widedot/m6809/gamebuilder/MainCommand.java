package com.widedot.m6809.gamebuilder;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.ex.ConfigurationException;
import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.io.FilenameUtils;
import org.apache.commons.lang3.exception.ExceptionUtils;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.ArgGroup;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

import com.widedot.m6809.gamebuilder.builder.GameBuilder;
import com.widedot.m6809.gamebuilder.configuration.Media;
import com.widedot.m6809.util.FileUtil;

/**
 * 6809 game builder
 */

@Command(name = "gamebuilder", description = "6809 game builder")
@Slf4j
public class MainCommand implements Runnable {
	
    @ArgGroup(exclusive = true, multiplicity = "1")
    Exclusive exclusive;

    static class Exclusive {
            @Option(names = { "-d", "--dir" }, paramLabel = "Input directory", description = "Process all configuration files located in the input directory.")
            String confDir;

            @Option(names = { "-f", "--file" }, paramLabel = "Configuration file", description = "Process configuration file.")
            String confFile;
            
            @Option(names = { "-e", "--extract" }, paramLabel = "Extract directory", description = "Directory to extract assembly engine.")
            String extractDir;
    }
	
    @Option(names = { "-t", "--target"}, paramLabel = "Targets", description = "Comma separated targets in configuration file.")
    private String target;
    
    @Option(names = { "-v", "--verbose"}, description = "Verbose mode. Helpful for troubleshooting.")
    private boolean verbose = false;
    
    @Option(names = { "-c", "--clean"}, description = "Clean assembled object files.")
    private boolean clean = false;

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
	}

	@Override
	public void run() {
		try {
			Startup.showSplash();

			// verbose mode
			ch.qos.logback.classic.Logger root = (ch.qos.logback.classic.Logger) org.slf4j.LoggerFactory
					.getLogger(ch.qos.logback.classic.Logger.ROOT_LOGGER_NAME);
			if (verbose) {
				root.setLevel(ch.qos.logback.classic.Level.DEBUG);
			} else {
				root.setLevel(ch.qos.logback.classic.Level.INFO);
			}

			if (exclusive.extractDir != null) {
				// exctract assembly engine
				extract(exclusive.extractDir);
			} else {

				if (clean) {
					// clean assembled .o files
					Startup.clean();
				}

				// process a conf file or all conf files in a dir
				String[] targets = (target!=null?target.split(","):null);				
				if (exclusive.confFile != null) {
					processFile(new File(exclusive.confFile), targets);
				} else if (exclusive.confDir != null) {
					processDir(new File(exclusive.confDir), targets);
				}
			}

			log.info("Done.");
		} catch (Exception e) {
			log.error(ExceptionUtils.getStackTrace(e));
		}
	}
	
	private void extract(String dir) {
		try {
			if (Startup.createProjectDirectory(dir)) {
				Startup.extractResource("/engine.zip", false);
			}
		} catch (IOException e) {
			log.error(ExceptionUtils.getStackTrace(e));
		}
	}
	
	private void processDir(File dir, String[] targets) throws Exception {
		if (dir.isDirectory()) {
			log.info("Processing directory {}", dir.getName());
			for (File file : dir.listFiles())
			{
			   if (FilenameUtils.getExtension(file.getName()).equals("xml"))
			   {
				   processFile(file, targets);
			   }
			}
		} else {
			log.error("Directory "+dir.getName()+" does not exists !");
		}
	}
	
	private void processFile(File file, String[] targets) throws Exception{
		
		log.info("Processing file {}", file.getName());

		if (!file.exists() || file.isDirectory()) {
			log.error("File "+file.getName()+" does not exists !");
			return;
		}
  
		// Get absolute directory of configuration file. Will be used as the base directory
		// for all relative paths of files given in this configuration file.
	    String path = FileUtil.getDir(file);
		
	    // parse the xml
		Configurations configs = new Configurations();
		try
		{
		    XMLConfiguration config = configs.xml(file);
		    
		    if (targets!=null && targets.length>0) {
			    // process specific targets by order
				for (int i = 0; i < targets.length; i++) {
				    List<HierarchicalConfiguration<ImmutableNode>> targetFields = config.configurationsAt("target");
			    	for(HierarchicalConfiguration<ImmutableNode> target : targetFields)
			    	{
		    			if (!target.getString("[@name]").equals(targets[i])) {
		    				continue;
		    			}
		    			
			    		processTarget(target, path);
		    		}
		    	}
		    } else {
		    	// process all targets
			    List<HierarchicalConfiguration<ImmutableNode>> targetFields = config.configurationsAt("target");
		    	for(HierarchicalConfiguration<ImmutableNode> target : targetFields)
		    	{
		    		processTarget(target, path);
		    	}
		    }
		}
		catch (ConfigurationException cex)
		{
			log.error("Error reading xml configuration file.");
			log.error(ExceptionUtils.getStackTrace(cex));
		}
	}
    
	private void processTarget(HierarchicalConfiguration<ImmutableNode> target, String path) throws Exception {
		String targetName = target.getString("[@name]");
		log.info("Processing target {}", target.getString("[@name]"));
		log.debug("name: "+targetName);
		GameBuilder gameBuilder = new GameBuilder(getDefines(target), getMedia(target, path), path);
		log.info("End of processing target {}", target.getString("[@name]"));
	}

	private HashMap<String, String> getDefines(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		
	    HashMap<String, String> newDefines = new HashMap<String, String>();
		
		// parse each defines
	    List<HierarchicalConfiguration<ImmutableNode>> definesFields = node.configurationsAt("defines");
    	for(HierarchicalConfiguration<ImmutableNode> defines : definesFields)
    	{
    		// parse each define inside defines
		    List<HierarchicalConfiguration<ImmutableNode>> defineFields = defines.configurationsAt("define");
	    	for(HierarchicalConfiguration<ImmutableNode> define : defineFields)
	    	{
	    		String symbol = define.getString("[@symbol]", null);
	    		String value = define.getString("[@value]", null);
	    		newDefines.put(symbol, value);
	    		log.debug(">> define");
	    		log.debug("   symbol: "+symbol);
	    		log.debug("   value: "+value);
	    	} 	
    	}	       	
    	return newDefines;
	}
	
	private List<Media> getMedia(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		
		List<Media> newMedia = new ArrayList<Media>();
		
		// parse each media
	    List<HierarchicalConfiguration<ImmutableNode>> mediaFields = node.configurationsAt("media");
    	for(HierarchicalConfiguration<ImmutableNode> media : mediaFields)
    	{
    		newMedia.add(new Media(media, path));
    	}	     
    	return newMedia;
	}
	
}