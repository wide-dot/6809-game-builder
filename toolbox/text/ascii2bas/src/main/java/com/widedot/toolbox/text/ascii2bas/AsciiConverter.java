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

	// basic file format
	// -----------------
	// header : FF
	// XX XX (file length with header, but without trailer)
	// line : XX XX (line length, with line header and end of line)
	// XX XX (line number 0-63999)
	// ... (instruction tokens [>=0x80] or ascii chars [<0x80], ascii can be
	// multiple bytes for one char)
	// 00 (end of line)
	// line : ...
	// trailer: 00 00 (end of file)

	public static String BASIC_EXT = ".bas";

	public static int BASIC_FILE_HEADER_SIZE = 3;
	public static int BASIC_LINE_HEADER_SIZE = 4;
	public static int BASIC_MAX_FILE_SIZE = 0x10000;
	public static int BASIC_MAX_LINE_NB = 64000;

	public static byte ASCII_SPACE = 0x20;
	public static byte BASIC_END_LINE = 0x00;
	public static byte BASIC_END_FILE = 0x00;

	public static byte[] getBasic(File file, HashMap<byte[], byte[]> tokenmap) throws Exception {

		// control input parameters
		if (!file.exists() || file.isDirectory()) {
			log.error("Input file: {} does not exists !", file.toString());
			return null;
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
		byte[] outb = new byte[BASIC_MAX_FILE_SIZE];

		// parse input data and generate output data
		int outPos = BASIC_FILE_HEADER_SIZE;
		int inPos, tmpInPos, decimal, linePos, lineNumber, lineLength;
		for (byte[] curLine : lineByte) {

			// decode line number
			lineNumber = 0;
			inPos = 0;
			while (inPos >= 0 && inPos < curLine.length && (curLine[inPos] == 0x20 || curLine[inPos] == 0x09))
				inPos++; // skip spaces and tabs
			while (inPos >= 0 && inPos < curLine.length && (curLine[inPos] >= 0x30 && curLine[inPos] <= 0x39))
				inPos++; // skip numbers
			tmpInPos = inPos; // keep after number position
			inPos--;
			decimal = 1;
			while (inPos >= 0 && inPos < curLine.length && (curLine[inPos] >= 0x30 && curLine[inPos] <= 0x39)) { // go back an decode
																									// line number
				lineNumber += (curLine[inPos--] - 0x30) * decimal;
				decimal *= 10;
			}
			inPos = tmpInPos;
			while (inPos >= 0 && inPos < curLine.length && (curLine[inPos] == 0x20 || curLine[inPos] == 0x09))
				inPos++; // skip spaces and tabs

			// control line number
			if (lineNumber >= BASIC_MAX_LINE_NB)
				throw new Exception("Line number " + lineNumber + " is out of range, should be < " + BASIC_MAX_LINE_NB);

			// copy ascii and replace tokens
			linePos = outPos;
			outPos += BASIC_LINE_HEADER_SIZE;
			while (inPos >= 0 && inPos < curLine.length) {

				// search a key from this position 
				boolean replaced = false;
				for (byte[] key : tokenmap.keySet()) {
					if (match(curLine, inPos, key)) {
						
						// there is a match, replace key by token
						byte[] token = tokenmap.get(key);
						for (int l = 0; l < token.length; l++) {
							outb[outPos++] = token[l];
						}
						inPos += key.length;
						replaced = true;
						break;
					}
				}

				if (!replaced) {
					
					// no key found, copy a simple ascii char
					byte val = curLine[inPos++];
					if (val < 0)
						throw new Exception("Unable to convert ascii code: " + String.format("%02x", val));
					outb[outPos++] = val;
				}
				
			}
			outb[outPos++] = BASIC_END_LINE;

			// compute line length
			lineLength = outPos - linePos;

			// set line header
			outb[linePos++] = (byte) ((lineLength & 0xff00) >> 8);
			outb[linePos++] = (byte) (lineLength & 0xff);
			outb[linePos++] = (byte) ((lineNumber & 0xff00) >> 8);
			outb[linePos++] = (byte) (lineNumber & 0xff);
		}

		// basic header
		outb[0] = (byte) 0xff; // Basic file type
		outb[1] = (byte) ((outPos & 0xff00) >> 8); // file length MSB
		outb[2] = (byte) (outPos & 0xff); // file length LSB

		// basic trailer
		outb[outPos++] = BASIC_END_FILE;
		outb[outPos++] = BASIC_END_FILE;

		// set final data
		byte[] basic = Arrays.copyOf(outb, outPos);
		return basic;
	}

	private static boolean match(byte[] outerArray, int start, byte[] smallerArray) {
		for (int j = 0; j < smallerArray.length; j++) {
			if (outerArray[start + j] != smallerArray[j]) {
				return false;
			}
		}
		return true;
	}

}