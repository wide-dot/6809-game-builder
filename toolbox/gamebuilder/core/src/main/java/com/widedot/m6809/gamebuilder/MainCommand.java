package com.widedot.m6809.gamebuilder;

import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.concurrent.Callable;

import org.apache.commons.io.FilenameUtils;
import org.apache.commons.lang3.exception.ExceptionUtils;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.ArgGroup;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

import com.widedot.m6809.gamebuilder.config.XmlLoader;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;
import com.widedot.m6809.util.FileResourcesUtils;
import com.widedot.m6809.util.FileUtil;

/**
 * 6809 game builder
 */

@Command(name = "gamebuilder", description = "6809 game builder")
@Slf4j
public class MainCommand implements Callable<Integer> {
	
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
		// the exit code must reflect the build outcome : a broken build has to
		// fail the shell command, the Makefile or the CI job that invoked it
		System.exit(new CommandLine(new MainCommand()).execute(args));
	}

	@Override
	public Integer call() {
		try {
			long startTime = System.currentTimeMillis();
			Startup.showSplash();

			// check verbose mode
			ch.qos.logback.classic.Logger root = (ch.qos.logback.classic.Logger) org.slf4j.LoggerFactory
					.getLogger(ch.qos.logback.classic.Logger.ROOT_LOGGER_NAME);
			if (verbose) {
				root.setLevel(ch.qos.logback.classic.Level.DEBUG);
			} else {
				root.setLevel(ch.qos.logback.classic.Level.INFO);
			}

			if (exclusive.extractDir != null) {		// MODE 1 : extract assembly engine
				extract(exclusive.extractDir);
			} else {								// MODE 2 : run the builder
			    
				// load properties
				Settings settings = new Settings(FileResourcesUtils.getHashMap("settings.properties"));

				if (settings.isValid()) {
					// process targets of a conf file or all conf files in a dir
					String[] targets = (target!=null?target.split(","):null);				
					if (exclusive.confFile != null) {
						processFile(new File(exclusive.confFile), targets, settings);
					} else if (exclusive.confDir != null) {
						processDir(new File(exclusive.confDir), targets, settings);
					}
				}
			}
			
			long endTime = System.currentTimeMillis();
			double duration = (endTime - startTime) / 1000.0;
			log.info("Build done in {}s", duration);
			return 0;
		} catch (Exception e) {
			log.error(ExceptionUtils.getStackTrace(e));
			return 1;
		}
	}
	
	private void extract(String dir) throws IOException {
		if (Startup.createProjectDirectory(dir)) {
			Startup.extractResource("/engine.zip", false);
		}
	}
	
	private void processDir(File dir, String[] targets, Settings settings) throws Exception {
		if (!dir.isDirectory()) {
			throw new Exception("Directory: " + dir.getPath() + " does not exists !");
		}
		log.info("Processing directory: {}", dir.getName());
		File[] files = dir.listFiles();
		if (files == null) {
			throw new Exception("Directory: " + dir.getPath() + " cannot be read !");
		}
		// sort : the file system order is not stable across machines, and the
		// build result depends on the processing order (link symbol ids)
		Arrays.sort(files);
		for (File file : files) {
			if (FilenameUtils.getExtension(file.getName()).equals("xml")) {
				processFile(file, targets, settings);
			}
		}
	}
	
	private void processFile(File file, String[] targets, Settings settings) throws Exception{
		
		log.info("Processing file: {}", file.getName());

		if (!file.exists() || file.isDirectory()) {
			throw new Exception("File: " + file.getPath() + " does not exists !");
		}
		
		// Get absolute directory of configuration file. Will be used as the base directory
		// for all relative paths of files given in this configuration file.
	    String path = FileUtil.getDir(file);
	    
	    // clean build files
		if (clean) {
			throw new Exception("The --clean option is not implemented yet.");
		}
		
	    // parse the xml, keeping source positions for error messages
		XmlLoader.Result config = XmlLoader.load(file);

		// one context per configuration file : nothing leaks between builds
		Target target = new Target(new BuildContext(path, settings, config.sources));

		if (targets!=null && targets.length>0) {
			target.processTargetSelection(config.root, targets);
		} else {
			target.processAllTargets(config.root);
		}
	}	
}