package com.widedot.to8.tools;

import java.io.File;
import java.io.FileInputStream;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.widedot.m6809.gamebuilder.MainProg;
import com.widedot.m6809.gamebuilder.builder.BuildDisk;
import com.widedot.m6809.gamebuilder.builder.DynamicContent;
import com.widedot.m6809.gamebuilder.builder.Game;
import com.widedot.m6809.gamebuilder.builder.GameMode;
import com.widedot.m6809.gamebuilder.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class AssemblyCompiler
{
	

	/**
	 * Effectue la compilation du code assembleur
	 * 
	 * @param asmFile fichier contenant le code assembleur a compiler
	 * @return
	 */
	
	public static int compileRAW(String asmFile, int mode) throws Exception {
		return AssemblyCompiler.compile(asmFile, "--raw", mode, null, DynamicContent.NOPAGE);
	}

	public static int compileRAW(String asmFile, int mode, GameMode gm, int page) throws Exception {
		return AssemblyCompiler.compile(asmFile, "--raw", mode, gm, page);
	}

	public static int compileLIN(String asmFile, int mode, GameMode gm, int page) throws Exception {
		return AssemblyCompiler.compile(asmFile, "--decb", mode, gm, page);
	}

	public static int compile(String asmFile, String option, int mode, GameMode gm, int page) throws Exception {
		Path path = Paths.get(asmFile).toAbsolutePath().normalize();
		String asmFileName = FileUtil.removeExtension(asmFile);
		String binFile = asmFileName + ".bin";
		String lstFile = asmFileName + ".lst";
		String glbFile = asmFileName + ".glb";			
		String glbTmpFile = asmFileName + ".tmp";	
		
		if (mode==BuildDisk.MEGAROM_T2)
			BuildDisk.dynamicContentT2.patchSource(path);
		else if (mode==BuildDisk.FLOPPY_DISK)
			BuildDisk.dynamicContentFD.patchSource(path);
		
		File del = new File (binFile);
		del.delete();
		del = new File (lstFile);
		del.delete();
		del = new File (glbFile);
		del.delete();
		del = new File (glbTmpFile);
		del.delete();
	
		log.info("Compiling {} ",path.toString());
		
		List<String> command = new ArrayList<String>(List.of(MainProg.game.lwasm,
				   path.toString(),
				   "--output=" + binFile,
				   "--list=" + lstFile,
				   "--6809",	
				   "--includedir="+path.getParent().toString(),
				   "--includedir=./",
				   "--symbol-dump=" + glbTmpFile,
				   Game.pragma				   
				   ));
		
		for (int i=0; i<Game.includeDirs.length; i++)
			command.add(Game.includeDirs[i]);
		
		if (Game.define != null && Game.define.length()>0) command.add(Game.define);
		if (mode==BuildDisk.MEGAROM_T2) command.add("--define=T2");
		if (option != null && option.length() >0) command.add(option);
			
		log.debug("Command : {}", command);
		Process p = new ProcessBuilder(command).inheritIO().start();
	
		int result = p.waitFor();
	
	    Pattern pattern = Pattern.compile("^.*[^\\}]\\sEQU\\s.*$", Pattern.MULTILINE);
	    FileInputStream input = new FileInputStream(glbTmpFile);
	    FileChannel channel = input.getChannel();
	    Path out = Paths.get(glbFile);
	    String data = "";
	
	    ByteBuffer bbuf = channel.map(FileChannel.MapMode.READ_ONLY, 0, (int) channel.size());
	    CharBuffer cbuf = Charset.forName("8859_1").newDecoder().decode(bbuf);
	
	    Matcher matcher = pattern.matcher(cbuf);
	    while (matcher.find()) {
	    	String match = matcher.group();
		    data += match + System.lineSeparator();
	    }
	    
	    Files.write(out, data.getBytes());
	    input.close();
	    
		if (mode==BuildDisk.MEGAROM_T2)
			BuildDisk.dynamicContentT2.savePatchLocations(path, out, gm, page);
		else if (mode==BuildDisk.FLOPPY_DISK)
			BuildDisk.dynamicContentFD.savePatchLocations(path, out, gm, page);
	    
		return result;
	}

}
