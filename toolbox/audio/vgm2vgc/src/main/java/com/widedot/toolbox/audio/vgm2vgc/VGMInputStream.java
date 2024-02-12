package com.widedot.toolbox.audio.vgm2vgc;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.zip.GZIPInputStream;

public class VGMInputStream extends InputStream {
	private final InputStream input;
	private int offsetEOF;
	private int version;
	private int psgClock;
	private int fmClock;
	private int offsetGD3;
	private int totalSamples;
	private int offsetLoop;
	private int loopSamples;
	private int psgConf;
	private int rate;
	private int vgmDataOffset;
	private int headerSize;
	
	private int pos;

	public VGMInputStream(File paramFile) throws IOException {
		InputStream bufferedInputStream;
		this.pos = 0;
		try {
			bufferedInputStream = new GZIPInputStream(new FileInputStream(paramFile));
		} catch (IOException iOException) {
			bufferedInputStream = new BufferedInputStream(new FileInputStream(paramFile));
		} 
		this.input = bufferedInputStream;
		byte[] arrayOfByte = new byte[4];
		read(arrayOfByte);
		if (!"Vgm ".equals(new String(arrayOfByte))) {
			close();
			throw new IOException("Invalid vgm file. File identification missing.");
		} 
		this.offsetEOF = this.pos + readInt();
		this.version = readInt();
		this.psgClock = readInt();
		this.fmClock = readInt();
		this.offsetGD3 = this.pos + readInt();
		this.totalSamples = readInt();
		this.offsetLoop = this.pos + readInt();
		this.loopSamples = readInt();
		this.rate = readInt();
		this.psgConf = readInt();
		if (this.version >= 336) {
			seekTo(52);
			int i = readInt();
			vgmDataOffset = i;
			if (i > 0) {
				skip((i - 4));
			} else {
				seekTo(64);
			} 
		} else {
			vgmDataOffset = 0;
			seekTo(64);
		} 
		
		headerSize = this.pos;
	}
	
	public int getOffsetEOF() {
		return offsetEOF;
	}

	public int getVersion() {
		return version;
	}

	public int getPsgClock() {
		return psgClock;
	}

	public int getFmClock() {
		return fmClock;
	}

	public int getOffsetGD3() {
		return offsetGD3;
	}

	public int getTotalSamples() {
		return totalSamples;
	}

	public int getOffsetLoop() {
		return offsetLoop;
	}

	public int getLoopSamples() {
		return loopSamples;
	}

	public int getPsgConf() {
		return psgConf;
	}

	public int getRate() {
		return rate;
	}

	public int getVgmDataOffset() {
		return vgmDataOffset;
	}

	public int getHeaderSize() {
		return headerSize;
	}

	public void seekTo(int paramInt) throws IOException {
		if (paramInt < this.pos)
			throw new IOException("Current position is beyond position to seek to."); 
		if (paramInt > this.pos)
			skip((paramInt - this.pos)); 
	}

	public boolean isLoopPoint() {
		return (this.pos == this.offsetLoop);
	}
	
	public int getPosition() {
		return this.pos;
	}

	public int read() throws IOException {
		this.pos++;
		return this.input.read();
	}
	
	public byte readByte() throws IOException {
		this.pos++;
		return (byte) (this.input.read() & 0xff);
	}

	public int readShort() throws IOException {
		return read() | read() << 8;
	}

	public int readInt() throws IOException {
		return read() | read() << 8 | read() << 16 | read() << 24;
	}

	public void close() throws IOException {
		this.input.close();
	}

	public int available() throws IOException {
		return this.input.available();
	}

	public synchronized void mark(int paramInt) {
		this.input.mark(paramInt);
	}

	public boolean markSupported() {
		return this.input.markSupported();
	}

	public synchronized void reset() throws IOException {
		this.input.reset();
	}
	
}
