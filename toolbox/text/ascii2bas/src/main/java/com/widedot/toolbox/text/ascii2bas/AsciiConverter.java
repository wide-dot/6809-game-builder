package com.widedot.toolbox.text.ascii2bas;

import java.io.File;
import java.nio.CharBuffer;
import java.nio.charset.CharsetEncoder;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import javax.xml.bind.DatatypeConverter;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class AsciiConverter {

	byte[] basBytes;
	int fileSize;
	
	public static int HEADER_SIZE = 3;
	public static String BASIC_EXT = ".bas";
	public static int BASIC_MAX_FILE_SIZE = 0x10000;
	public static byte ASCII_SPACE = 0x20;
	
	public AsciiConverter(File file, HashMap<byte[], byte[]> tokenmap) throws Exception {
		
		// checks
		if (!file.exists() || file.isDirectory()) {
			log.error("Input file: {} does not exists !", file.toString());
			return;
		}
	    
	    // read input file line by line and build a byte array list
	    Stream<String> lineStream = Files.lines(file.toPath());
	    List<String> lineString = lineStream.collect(Collectors.toList());
	    lineStream.close();
	    List<byte[]> lineByte = new ArrayList<byte[]>();
	    for (int i = 0; i < lineString.size(); i++) {
	    	lineByte.add(lineString.get(i).getBytes());	    	
	    }
		
	    // init output data
		String outFileName = FileUtil.removeExtension(file.getAbsolutePath())+BASIC_EXT;
		byte[] outb = new byte[BASIC_MAX_FILE_SIZE];
		
		// parse input data and generate output data
		int pos = HEADER_SIZE;	    
		int i, j, k, startpos, lineNumber, lineLength;
		for (byte[] curLine : lineByte) {
			
			// decode line number
			lineNumber = 0;
			i = 0;
			while (i >= 0 && i < curLine.length && (curLine[i] == 0x20 || curLine[i] == 0x09)) i++; // skip spaces and tabs
			while (i >= 0 && i < curLine.length && (curLine[i] >= 0x30 && curLine[i] <= 0x39)) i++; // skip numbers
			k = i;                                                                                  // keep after number position 
			i--;
			j = 1;
			while (i >= 0 && i < curLine.length && (curLine[i] >= 0x30 && curLine[i] <= 0x39)) {    // go back an decode line number
				lineNumber += (curLine[i--] - 0x30)*j;
				j *= 10;
			}
			i = k;
			while (i >= 0 && i < curLine.length && (curLine[i] == 0x20 || curLine[i] == 0x09)) i++; // skip spaces and tabs
					
			// replace tokens
			startpos = pos;
			pos += 4;
			while (i >= 0 && i < curLine.length) {
				outb[pos++] = curLine[i++];
		    }
			lineLength = pos-startpos-4;
		    
			outb[startpos++] = (byte) ((lineLength & 0xff00) >> 8);
			outb[startpos++] = (byte) (lineLength  & 0xff);
			outb[startpos++] = (byte) ((lineNumber & 0xff00) >> 8);
			outb[startpos++] = (byte) (lineNumber  & 0xff);
		}
			
		// basic header
		outb[0] = (byte) 0xff;                  // Basic file type
		outb[1] = (byte) ((pos & 0xff00) >> 8); // file length MSB
		outb[2] = (byte) (pos & 0xff);          // file length LSB
			
		byte[] data = Arrays.copyOf(outb, pos);
		Files.write(Path.of(outFileName), data);
	}	
	
	public int indexOf(byte[] outerArray, byte[] smallerArray) {
	    for(int i = 0; i < outerArray.length - smallerArray.length+1; ++i) {
	        boolean found = true;
	        for(int j = 0; j < smallerArray.length; ++j) {
	           if (outerArray[i+j] != smallerArray[j]) {
	               found = false;
	               break;
	           }
	        }
	        if (found) return i;
	     }
	   return -1;  
	} 
	
}