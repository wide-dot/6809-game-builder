package com.widedot.toolbox.graphics.png;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;
import picocli.CommandLine;
import picocli.CommandLine.ArgGroup;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/**
 * png to binary converter
 * - convert a indexed png image to binary in various graphical modes
 */

@Command(name = "png2bin", description = "png to binary converter")
@Slf4j
public class MainCommand implements Runnable {
	
    @ArgGroup(exclusive = true, multiplicity = "1")
    Exclusive exclusive;

    static class Exclusive {
            @Option(names = { "-d", "--dir" }, paramLabel = "Input directory", description = "Process all .png files located in the input directory")
            String inputDir;

            @Option(names = { "-f", "--file" }, paramLabel = "Input file", description = "Process .png input file")
            String inputFile;
    }

    @Option(names = { "-lb", "--linearBits" }, required = true, paramLabel = "Linear bits", description = "Number of bits that defines a pixel in a plane")
    private int linearBits = 0;

	@Option(names = { "-pb", "--planarBits" }, paramLabel = "Planar bits", description = "Number of bits to process before going next plane")
    private int planarBits = 0;

	@Option(names = { "-l", "--lineBytes" }, paramLabel = "Line bytes", description = "Number of bytes that defines a line in a plane")
    private int lineBytes = 0;

	@Option(names = { "-p", "--nbPlanes" }, paramLabel = "Number of planes", description = "Number of memory planes")
    private int nbPlanes = 1;

	@Option(names = { "-pd", "--pixelDepth" }, required = true, paramLabel = "Pixel Depth", description = "Number of bits per pixel")
    private int pixelDepth;
	
	@Option(names = { "-oms", "--out-max-size" }, paramLabel = "Output file max size", description = "Output file maximum size, file will be splitted beyond this value")
	private int fileMaxSize = Integer.MAX_VALUE;

	public static void main(String[] args) {
		CommandLine cmdLine = new CommandLine(new MainCommand());
		cmdLine.execute(args);
    }

	// Thomson - MO/TO
	// ---------------
	//	mode t0  : -lb 1 -pb 0 -l 40 -p 1 -pd 1
	//	mode t1  : -lb 1 -pb 1 -l 40 -p 2 -pd 2
	//	mode t1s : -lb 2 -pb 8 -l 40 -p 2 -pd 2
	//	mode t2  : -lb 1 -pb 8 -l 40 -p 2 -pd 1
	//	mode t3  : -lb 4 -pb 8 -l 40 -p 2 -pd 4
	//	mode t4  : -lb 1 -pb 0 -l 40 -p 1 -pd 1
	//	mode t5  : -lb 1 -pb 0 -l 40 -p 1 -pd 1
	//	mode t6  : -lb 1 -pb 0 -l 40 -p 1 -pd 1
	//
	// Tandy - CoCo3
	// -------------
	//	mode c2  : -lb 1 -pb 0 -l 256 -p 1 -pd 1
	//	mode c4  : -lb 2 -pb 0 -l 256 -p 1 -pd 2
	//	mode c16 : -lb 4 -pb 0 -l 256 -p 1 -pd 4
	
	@Override
	public void run()
	{
		log.info("png to binary converter");

                if (exclusive.inputDir != null) {
        		log.info("Process each png file of the directory {}", exclusive.inputDir);

                        // process each png file of the directory		
                        File dir = new File(exclusive.inputDir);
                        if (!dir.exists() || !dir.isDirectory()) {
                        	log.error("Input directory does not exists !");
                        } else {	
                        	File[] files = dir.listFiles((d, name) -> name.endsWith(".png"));
                        	for (File pngFile : files) {
                        		try {
                        			pngConverter(pngFile, fileMaxSize);
                        		} catch (Exception e) {
                        			log.error("Error converting .png file");
                        		}
                        	}
                        }
                } else {
                        log.info("Process {}", exclusive.inputFile);

                        // process a single png file
                        File pngFile = new File(exclusive.inputFile);
                        if(!pngFile.exists() || pngFile.isDirectory()) { 
                        	log.error("Input file does not exists !");
                        } else {
                        	try {
                        		pngConverter(pngFile, fileMaxSize);
                        	} catch (Exception e) {
                    			log.error("Error converting .png file");
                    		}
                        }
                }
	}

	private void pngConverter(File paramFile, int fileMaxSize) throws Exception {

		Png png = new Png(paramFile);

		byte image[] = resize(png); // resize image to a multiple of byte and planes of final image
		if (image == null) return;

		byte out[][] = convert(image, png.colorModel.getPixelSize(), png.height); // Convert source image to video memory data
		
		write(out, paramFile); // write output files by splitting if over memorypage size

	}
	
	private byte[] resize(Png png) {
		
		byte image[];
		int pixelSize = png.colorModel.getPixelSize();
		int width = png.width;
		int height = png.height;

		// Compute the new size
		// --------------------
		
		// if no memory line size is requested, fit the smallest size
		if (lineBytes == 0) {
			int pixelGroup = (nbPlanes*8)/pixelDepth;                     // compute number of pixels that match one byte on destination Memory Byte/Plan arrangement
			width += (width%pixelGroup!=0?pixelGroup-width%pixelGroup:0); // compute new width
			lineBytes = (width*pixelDepth)/8;                             // compute the width of destination data
			
		} else if ((lineBytes*nbPlanes)*(8/pixelDepth)>=width) {
			
			width = (lineBytes*nbPlanes)*(8/pixelDepth);                  // image is padded to specified memory size (typical use is a line of video memory for compilated sprite)

		} else {
			log.error("image width is too large for lineBytes setting of: "+lineBytes);
			return null;		
		}
		
		// Resize
		// ------
		
		int dwidth = png.width/(8/pixelSize);
		int nwidth = width/(8/pixelSize);
		image = new byte[nwidth*height];
		for (int y = 0; y < height; y++) {
			for (int x = 0; x < dwidth; x++) {
				image[x+y*nwidth] = (byte) png.dataBuffer.getElem(x+y*dwidth);
			}
		}
		
		return image;
	}
	
	private byte[][] convert(byte[] image, int pixelSize, int height) {
		
		byte out[][] = new byte[nbPlanes][];
		
		// allocate output planes
		for (int p = 0; p < nbPlanes; p++) {
			out[p] = new byte[(lineBytes*height)/nbPlanes];
		}
			
		// init
		int ibc = 0;                                // count bit in input byte
		int curPxRShift = pixelSize;                // current shift in Pixel
		int curSubPxRShift = pixelDepth-linearBits; // current shift in sub pixel (splitted by plane)
		int outIdx[] = new int[nbPlanes];           // out byte index for each plane
		int curBitsinByte[] = new int[nbPlanes];    // out bit index for each plane
		int curBitsinPlane = 0;
		int plane = 0;
		int lbmask = 0;
		
		// setup bitmask for reading a pixel in each plane 
		for (int i = 0; i < linearBits; i++) { // linear bits is the number of bits for a pixel in a plane
			lbmask = (lbmask << 1) | 1;        // build the mask bit after bit
		}
		
		// format data
		int i=0;
		while (i < image.length) {

			// agregate pixels in a byte
			out[plane][outIdx[plane]] = (byte) ( (out[plane][outIdx[plane]] << linearBits) | (( image[i] >> 8-curPxRShift+curSubPxRShift) & lbmask));
			
			// how curSubPxRShift works :
			// -----------------------
			// this var is used in conjunction with lbmask to read a part of a pixel that is (or not) splitted into planes
			// Example :
			// linearBits of 2, pixelDepth of 4 : start curSubPxRShift at pixelDepth-linearBits=2 (first shift)
			// number of steps : pixelDepth/linearBits=2, step value is linearBits = 2
			// so there will be 2 reads with those shifts : 2, 0

			// part of pixel splitted by planes
			curSubPxRShift -= linearBits;
			if (curSubPxRShift < 0) {
				curSubPxRShift = pixelDepth-linearBits;   // reset shift value (used to read a part of a pixel)
				curPxRShift += pixelSize;                 // move to next pixel in input image
			}
			
			// fetch byte when all bits are set	(taking planes in account)	
			curBitsinByte[plane] += linearBits;
			if (curBitsinByte[plane] == 8) {
				outIdx[plane]++;                          // move index in output table for this plane
				curBitsinByte[plane] = 0;
			}

			// move to next byte in input image
			ibc += linearBits;
			if (ibc == (8/pixelSize)*pixelDepth) {
				i++;
				ibc = 0;
				curPxRShift = pixelSize;
			}
			
			// plane change
			curBitsinPlane += linearBits;
			if (curBitsinPlane%planarBits == 0) {
				plane++;
				plane = plane%nbPlanes;
				curBitsinPlane = 0;
			}
		}
		return out;
	}
	
	private void write(byte[][] out, File paramFile) throws Exception {
		// split data into multiple files that are maximum fileMaxSize long
		for (int p = 0; p < nbPlanes; p++) {
			int readIdx = 0;
			int writeIdx = 0;
			int fileId = 0;
			while (readIdx < out[p].length) {
				FileOutputStream fis = new FileOutputStream(new File(FileUtil.removeExtension(paramFile.toString()) + "." + p + "." + fileId + ".bin"));
				byte[] finalArray = new byte[(out[p].length-readIdx<fileMaxSize?out[p].length-readIdx:fileMaxSize)];
				writeIdx = 0;
				while (readIdx < out[p].length && writeIdx < fileMaxSize) {
					finalArray[writeIdx++] = out[p][readIdx++];
				}
				fis.write(finalArray);
				fis.close();
				fileId++;
			}
		}
	}
}