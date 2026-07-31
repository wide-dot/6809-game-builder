package com.widedot.toolbox.audio.vgm2vgc.pack;

import java.io.ByteArrayOutputStream;

/**
 * LZ4 compressor with optimal parsing, ported from lz4enc.py (@simondotm), itself
 * based on smallz4 by Stephan Brumme.
 *
 * <p>This is a strict, byte-for-byte faithful port of the Jython (Python 2) module
 * previously used by the VGC packer. Behaviour must not be "improved": the produced
 * streams have to stay identical.
 */
public class Lz4Enc {

	/** version string */
	public static final String VERSION = "1.3";

	/** greedy mode for short chains (compression level &lt;= 3) instead of optimal parsing */
	public static final int SHORT_CHAINS_GREEDY = 3;
	/** lazy evaluation for medium-sized chains (compression level &gt; 3 and &lt;= 6) */
	public static final int SHORT_CHAINS_LAZY = 6;

	/** each match's length must be &gt;= 4 */
	public static final int MIN_MATCH = 4;
	/** last match must not be closer than 12 bytes to the end */
	public static final int BLOCK_END_NO_MATCH = 12;
	/** last 5 bytes must be literals, no matching allowed */
	public static final int BLOCK_END_LITERALS = 5;
	/** match finder's hash table size (2^HashBits entries, must be less than 32) */
	public static final int HASH_BITS = 20;
	/** input buffer size */
	public static final int BUFFER_SIZE = 64 * 1024;
	/** marker for "no match" */
	public static final int NO_PREVIOUS = 0;
	/** significantly speed up parsing if the same byte is repeated a lot */
	public static final int MAX_SAME_LETTER = 19 + 255 * 256;
	/** refer to location of the previous match (implicit hash chain) */
	public static final int PREVIOUS_SIZE = 1 << 16;
	/** maximum block size id as defined in the LZ4 spec */
	public static final int MAX_BLOCK_SIZE_ID = 7;
	public static final int MAX_BLOCK_SIZE = 4 * 1024 * 1024;

	/** default maximum match distance */
	public static final int DEFAULT_MAX_DISTANCE = 65535;

	private static final int HASH_MULTIPLIER = 22695477;
	private static final int NO_LAST_HASH = 0x7FFFFFFF;

	// ----- instance state (these shadow class attributes in the Python original) -----

	/** how many matches are checked in findLongestMatch */
	private int maxChainLength;
	/** sliding window size */
	private int maxDistance = DEFAULT_MAX_DISTANCE;
	/** number of bytes used to store match distances (2 = LZ4 default) */
	private int distanceByteSize = 2;

	// ----- statistics (reset by beginFrame, accumulated across compressBlock calls) -----

	/** number of tokens emitted */
	public int tokenCount;
	/** largest stored match distance */
	public int largestOffset;
	/** largest stored match length */
	public int largestLength;
	/** number of match distances that were 255 or less */
	public int byteOffsetCount;
	/** number of match distances identical to the previous one */
	public int sameOffsetCount;
	/** temporary var for tracking the last match distance */
	public int lastOffset = -1;

	/** tokens emitted */
	public final IntList tokens = new IntList();
	/** offsets (match distances) emitted */
	public final IntList offsets = new IntList();
	/** match lengths emitted */
	public final IntList lengths = new IntList();
	/** literal byte stream data */
	public final IntList literalBytes = new IntList();
	/** length byte stream data (literal lengths first, then match lengths) */
	public final IntList lengthsBytes = new IntList();

	public Lz4Enc() {
		this(9);
	}

	public Lz4Enc(int level) {
		setCompression(level);
		resetStats();
	}

	// -----------------------------------------------------------------------------
	// public API
	// -----------------------------------------------------------------------------

	public void setCompression(int compressionLevel) {
		setCompression(compressionLevel, DEFAULT_MAX_DISTANCE);
	}

	public void setCompression(int compressionLevel, int windowSize) {
		if (windowSize >= 65536) {
			throw new IllegalArgumentException("windowSize must be < 65536");
		}
		// "unlimited" because the search window contains only 2^16 bytes
		this.maxChainLength = (compressionLevel >= 9) ? 65536 : compressionLevel;
		this.maxDistance = windowSize;
	}

	/**
	 * Emit 8-bit offsets instead of 16-bit ones (non LZ4 compliant, requires a
	 * modified decoder) and clamp the window to 255 bytes.
	 */
	public void optimizedCompression(boolean enable) {
		if (enable) {
			this.distanceByteSize = 1;
			if (this.maxDistance > 255) {
				this.maxDistance = 255;
			}
		} else {
			this.distanceByteSize = 2;
		}
	}

	public void optimizedCompression() {
		optimizedCompression(true);
	}

	public int getCompressionLevel() {
		return maxChainLength;
	}

	public int getWindowSize() {
		return maxDistance;
	}

	public int getDistanceByteSize() {
		return distanceByteSize;
	}

	/** Emit an LZ4 compatible frame header, and reset the statistics. */
	public void beginFrame(ByteArrayOutputStream out) {
		// magic bytes
		out.write(0x04);
		out.write(0x22);
		out.write(0x4D);
		out.write(0x18);
		// flags: version, dependent blocks, no block checksum, no size, no content
		// checksum, no dict id
		out.write(1 << 6);
		// max block size id
		out.write(MAX_BLOCK_SIZE_ID << 4);
		// header checksum (precomputed)
		out.write(0xDF);

		resetStats();
	}

	/** Emit an LZ4 compatible frame end signal (a block with size 0). */
	public void endFrame(ByteArrayOutputStream out) {
		out.write(0);
		out.write(0);
		out.write(0);
		out.write(0);
	}

	public byte[] compressBlock(byte[] inputData) {
		return compressBlock(inputData, EMPTY);
	}

	public void resetStats() {
		tokenCount = 0;
		largestOffset = 0;
		largestLength = 0;
		byteOffsetCount = 0;
		sameOffsetCount = 0;
		lastOffset = -1;
		tokens.clear();
		offsets.clear();
		lengths.clear();
		literalBytes.clear();
		lengthsBytes.clear();
	}

	public int getTokenCount() {
		return tokenCount;
	}

	public int getLargestOffset() {
		return largestOffset;
	}

	public int getLargestLength() {
		return largestLength;
	}

	public int getByteOffsetCount() {
		return byteOffsetCount;
	}

	public int getSameOffsetCount() {
		return sameOffsetCount;
	}

	public IntList getTokens() {
		return tokens;
	}

	public IntList getOffsets() {
		return offsets;
	}

	public IntList getLengths() {
		return lengths;
	}

	public IntList getLiteralBytes() {
		return literalBytes;
	}

	public IntList getLengthsBytes() {
		return lengthsBytes;
	}

	// -----------------------------------------------------------------------------
	// core
	// -----------------------------------------------------------------------------

	private static final byte[] EMPTY = new byte[0];

	// scratch results of findLongestMatch, avoids allocating a Match per position
	private int foundLength;
	private int foundDistance;

	// the sliding data window; `data` may hold the last 64k of the previous block too
	private byte[] data = EMPTY;
	private int dataLen;

	/**
	 * Create an LZ4 compressed block from the input buffer.
	 *
	 * @param inputData  data to compress
	 * @param dictionary optional predefined dictionary (unused by the VGC packer)
	 */
	public byte[] compressBlock(byte[] inputData, byte[] dictionary) {

		ByteArrayOutputStream outputData = new ByteArrayOutputStream();

		int inputPointer = 0;

		data = new byte[BUFFER_SIZE];
		dataLen = 0;

		// file position corresponding to data[0]
		int dataZero = 0;
		// last already read position
		int numRead = 0;
		// passthru data (but still wrap in LZ4 format)
		boolean uncompressed = (maxChainLength == 0);

		final int hashSize = 1 << HASH_BITS;
		final int hashShift = 32 - HASH_BITS;

		int[] lastHash = new int[hashSize];
		java.util.Arrays.fill(lastHash, NO_LAST_HASH);

		// previous position which starts with the same bytes
		int[] previousHash = new int[PREVIOUS_SIZE];
		int[] previousExact = new int[PREVIOUS_SIZE];

		// first and last offset of a block (next is end-of-block plus 1)
		int lastBlock = 0;
		int nextBlock = 0;
		boolean parseDictionary = dictionary.length > 0;

		while (true) {

			// ==================== start new block ====================
			if (parseDictionary) {
				final int maxDictionary = 65536;
				if (dictionary.length < maxDictionary) {
					// add garbage data (zeroes) so that exactly 64k is prepended
					dataExtendZero(65536 - dictionary.length);
					dataExtend(dictionary, 0, dictionary.length);
				} else {
					// copy only the most recent 64k of the dictionary
					int doffset = dictionary.length - maxDictionary;
					dataExtend(dictionary, doffset, dictionary.length - doffset);
				}
				nextBlock = dataLen;
				numRead = dataLen;
			}

			// read more bytes from input
			final int maxBlockSize = MAX_BLOCK_SIZE;

			while (numRead - nextBlock < maxBlockSize) {
				int count = BUFFER_SIZE;
				if (inputPointer >= inputData.length) {
					break;
				}
				if (inputPointer + count >= inputData.length) {
					count = inputData.length - inputPointer;
				}
				if (count == 0) {
					break;
				}
				dataExtend(inputData, inputPointer, count);
				inputPointer += count;
				numRead += count;
			}

			// no more data ? => we're done
			if (nextBlock == numRead) {
				break;
			}

			// determine block borders
			lastBlock = nextBlock;
			nextBlock += maxBlockSize;
			if (nextBlock > numRead) {
				nextBlock = numRead;
			}

			// dataBlock is an offset into data[]
			final int dataBlock = lastBlock - dataZero;
			final int blockSize = nextBlock - lastBlock;

			// ==================== full match finder ====================
			// greedy mode is much faster but produces larger output
			boolean isGreedy = (maxChainLength <= SHORT_CHAINS_GREEDY);
			// lazy evaluation: if there is a match, then try the next position too
			boolean isLazy = !isGreedy && (maxChainLength <= SHORT_CHAINS_LAZY);

			int skipMatches = 0;
			boolean lazyEvaluation = false;

			// the last literals of the previous block skipped matching, so they are
			// missing from the hash chains: go back a few bytes
			int lookback = dataZero;
			if (lookback > BLOCK_END_NO_MATCH && !parseDictionary) {
				lookback = BLOCK_END_NO_MATCH;
			}
			if (parseDictionary) {
				lookback = dictionary.length;
			}
			lookback = -lookback;

			int[] matchLen = new int[blockSize];
			int[] matchDist = new int[blockSize];

			for (int i = lookback; i < blockSize; i++) {

				// no matches at the end of the block (or matching disabled)
				if (i + BLOCK_END_NO_MATCH > blockSize || uncompressed) {
					continue;
				}

				// detect self-matching
				if (i > 0 && data[dataBlock + i] == data[dataBlock + i - 1]) {
					// predecessor had the same match ?
					if (matchDist[i - 1] == 1 && matchLen[i - 1] > MAX_SAME_LETTER) {
						// just copy predecessor without further (expensive) optimizations
						matchLen[i] = matchLen[i - 1] - 1;
						matchDist[i] = matchDist[i - 1];
						continue;
					}
				}

				// read next four bytes (big endian, unsigned 32 bits)
				long four = getLong(data, dataBlock + i);

				// convert to a shorter hash; the product exceeds 32 bits, Python uses
				// arbitrary precision here so the multiply must be done in a long
				int hash = (int) (((four * HASH_MULTIPLIER) >> hashShift) & (hashSize - 1));

				// get last occurrence of these bits
				int last = lastHash[hash];
				// and store current position
				lastHash[hash] = i + lastBlock;

				// remember: i could be negative, too
				int prevIndex = Math.floorMod(i, PREVIOUS_SIZE);

				// no predecessor or too far away ?
				int distance = i + lastBlock - last;
				if (last == NO_LAST_HASH || distance > maxDistance) {
					previousHash[prevIndex] = NO_PREVIOUS;
					previousExact[prevIndex] = NO_PREVIOUS;
					continue;
				}

				// build hash chain, i.e. store distance to last match
				previousHash[prevIndex] = distance;

				// skip pseudo-matches (hash collisions) and build a second chain where
				// the first four bytes must match exactly
				while (distance != NO_PREVIOUS) {
					long curFour = getLong(data, last - dataZero); // may be in the previous block

					// actual match found, first 4 bytes are identical
					if (curFour == four) {
						break;
					}

					// prevent from accidently hopping on an old, wrong hash chain
					int curHash = (int) (((curFour * HASH_MULTIPLIER) >> hashShift) & (hashSize - 1));
					if (curHash != hash) {
						distance = NO_PREVIOUS;
						break;
					}

					// try next pseudo-match
					int next = previousHash[Math.floorMod(last, PREVIOUS_SIZE)];

					// pointing to outdated hash chain entry ?
					distance += next;

					if (distance > maxDistance) {
						previousHash[Math.floorMod(last, PREVIOUS_SIZE)] = NO_PREVIOUS;
						distance = NO_PREVIOUS;
						break;
					}

					// closest match is out of range ?
					last -= next;
					if (next == NO_PREVIOUS || last < dataZero) {
						distance = NO_PREVIOUS;
						break;
					}
				}

				// no match at all ?
				if (distance == NO_PREVIOUS) {
					previousExact[prevIndex] = NO_PREVIOUS;
					continue;
				}

				// store distance to previous match
				previousExact[prevIndex] = distance;

				// no matching if crossing block boundary, just update hash tables
				if (i < 0) {
					continue;
				}

				// skip match finding if in greedy mode
				if (skipMatches > 0) {
					skipMatches -= 1;
					if (!lazyEvaluation) {
						continue;
					}
					lazyEvaluation = false;
				}

				// and look for longest match
				findLongestMatch(i + lastBlock, dataZero, nextBlock - BLOCK_END_LITERALS + 1, previousExact);
				matchLen[i] = foundLength;
				matchDist[i] = foundDistance;

				// no match finding needed for the next few bytes in greedy/lazy mode
				if (foundLength >= MIN_MATCH && (isLazy || isGreedy)) {
					lazyEvaluation = (skipMatches == 0);
					skipMatches = foundLength;
				}
			}

			// dictionary applies only to the first block
			parseDictionary = false;

			// ==================== estimate costs ====================
			// not needed in greedy mode and/or very short blocks
			if (blockSize > BLOCK_END_NO_MATCH && maxChainLength > SHORT_CHAINS_GREEDY) {
				estimateCosts(matchLen, matchDist, blockSize);
			}

			// ==================== select best matches ====================
			byte[] block = EMPTY;
			if (!uncompressed) {
				block = selectBestMatches(matchLen, matchDist, blockSize, lastBlock - dataZero);
			}

			// ==================== output ====================
			int uncompressedSize = nextBlock - lastBlock;
			// the original computes useCompression then unconditionally forces it to
			// true, because the 6809 decoder cannot handle uncompressed streams
			boolean useCompression = true;

			int numBytes = useCompression ? block.length : uncompressedSize;
			int numBytesTagged = numBytes;
			if (!useCompression) {
				numBytesTagged |= 0x80000000;
			}

			outputData.write(numBytesTagged & 0xFF);
			outputData.write((numBytesTagged >>> 8) & 0xFF);
			outputData.write((numBytesTagged >>> 16) & 0xFF);
			outputData.write((numBytesTagged >>> 24) & 0xFF);

			if (useCompression) {
				outputData.write(block, 0, block.length);
			} else {
				int index = lastBlock - dataZero;
				outputData.write(data, index, numBytes);
			}

			// remove already processed data except for the last 64kb which could be
			// used for intra-block matches
			if (dataLen > maxDistance) {
				int remove = dataLen - maxDistance;
				dataZero += remove;
				System.arraycopy(data, remove, data, 0, dataLen - remove);
				dataLen -= remove;
			}
		}

		return outputData.toByteArray();
	}

	/**
	 * Find the longest match of data[pos] between data[begin] and data[end], using the
	 * match chain stored in previous. Result goes to foundLength / foundDistance.
	 */
	private void findLongestMatch(int pos, int begin, int end, int[] previous) {

		foundLength = 1;
		foundDistance = 0;

		// compression level: look only at the first n entries of the match chain
		int stepsLeft = maxChainLength;

		// pointer to position that is matched against everything in data
		final int current = pos - begin;

		// don't match beyond this point
		final int stop = current + end - pos;

		// get distance to previous match, abort if 0 => not existing
		int distance = previous[Math.floorMod(pos, PREVIOUS_SIZE)];
		int totalDistance = 0;
		while (distance != NO_PREVIOUS) {
			// too far back ?
			totalDistance += distance;
			if (totalDistance > maxDistance) {
				break;
			}

			// prepare next position
			distance = previous[Math.floorMod(pos - totalDistance, PREVIOUS_SIZE)];

			// stop searching on lower compression levels
			if (stepsLeft <= 0) {
				break;
			}
			stepsLeft -= 1;

			// atLeast points to the first "new" byte of a potential longer match
			int atLeast = current + foundLength + 1;

			// impossible to find a longer match because not enough bytes left ?
			if (atLeast > stop) {
				break;
			}

			// phase 1: all bytes between current and atLeast shall be identical,
			// scanning backwards, comparing 4 bytes at once
			int compare = atLeast - 4;
			boolean ok = true;
			while (compare > current) {
				if (!match4(compare, compare - totalDistance)) {
					ok = false;
					break;
				}
				compare -= 4;
				// note: the first four bytes always match, and the last iteration may
				// compare a few bytes twice - checking for that is more expensive
			}

			if (!ok) {
				continue;
			}

			// phase 2: we have a new best match, now scan forward from the end
			compare = atLeast;
			int compare2 = compare - totalDistance;
			while (compare + 4 <= stop && match4(compare, compare2)) {
				compare += 4;
				compare2 += 4;
			}

			// slow loop: check the last 1/2/3 bytes
			while (compare < stop && data[compare] == data[compare - totalDistance]) {
				compare += 1;
			}

			// store new best match
			foundDistance = totalDistance;
			foundLength = compare - current;
		}
	}

	/** true if the four bytes at data[a] and data[b] are equal */
	private boolean match4(int a, int b) {
		return data[a] == data[b] && data[a + 1] == data[b + 1] && data[a + 2] == data[b + 2]
				&& data[a + 3] == data[b + 3];
	}

	/**
	 * Walk backwards through all matches and compute the number of compressed bytes
	 * from the current position to the end of the block. Matches are modified
	 * (shortened length) if necessary.
	 */
	private void estimateCosts(int[] matchLen, int[] matchDist, int n) {
		final int blockEnd = n;

		// minimum cost from this position to the end of the current block
		int[] cost = new int[n];

		int posLastMatch = blockEnd;

		// ignore the last 5 bytes, they are always literals
		final int blockRange = blockEnd - (1 + BLOCK_END_LITERALS);
		for (int i = blockRange; i >= 0; i--) {

			// watch out for long literal strings that need extra bytes
			int numLiterals = posLastMatch - i;
			// assume no match
			int minCost = cost[i + 1] + 1;
			// an extra byte for every 255 literals required to store the length
			if (numLiterals >= 15 && (numLiterals - 15) % 255 == 0) {
				minCost += 1;
			}

			// if encoded as a literal
			int bestLength = 1;

			int mLength = matchLen[i];
			int mDistance = matchDist[i];

			// match must not cross block borders
			if (mLength >= MIN_MATCH && i + mLength + BLOCK_END_LITERALS > blockEnd) {
				mLength = blockEnd - (i + BLOCK_END_LITERALS);
			}

			// try all match lengths (first short ones)
			for (int length = MIN_MATCH; length <= mLength; length++) {

				// token (1 byte) + offset (1 or 2 bytes)
				int currentCost = cost[i + length] + 1 + distanceByteSize;

				// very long matches need extra bytes for encoding match length
				if (length >= 19) {
					currentCost += 1 + (length - 19) / 255;
				}

				// better choice ? "<=" prefers longer matches; the original explains at
				// length why "<=" and not "<" (it breaks long literal chains)
				if (currentCost <= minCost) {
					minCost = currentCost;
					bestLength = length;
				}

				// workaround: very long self-referencing matches can slow down the
				// program A LOT - assume the longest match is always the best one
				if (mDistance == 1 && mLength >= MAX_SAME_LETTER) {
					bestLength = mLength;
					minCost = cost[i + mLength] + 1 + distanceByteSize + 1 + (mLength - 19) / 255;
					break;
				}
			}

			// remember position of last match to detect consecutive literals
			if (bestLength >= MIN_MATCH) {
				posLastMatch = i;
			}

			cost[i] = minCost;
			matchLen[i] = bestLength;
			if (bestLength == 1) {
				matchDist[i] = NO_PREVIOUS;
			}
		}
	}

	/**
	 * Create the shortest output. index points to the block's begin within data[], it
	 * is needed to extract literals.
	 */
	private byte[] selectBestMatches(int[] matchLen, int[] matchDist, int n, int index) {

		ByteArrayOutputStream result = new ByteArrayOutputStream();

		// indices of current literal run
		int literalsFrom = 0;
		int literalsTo = 0; // point beyond last literal of the current run

		int offset = 0;
		while (offset < n) {

			int mLength = matchLen[offset];
			int mDistance = matchDist[offset];

			// if no match, then count literals instead
			if (mLength < MIN_MATCH) {
				// first literal
				if (literalsFrom == literalsTo) {
					literalsFrom = literalsTo = offset;
				}
				// one more literal
				literalsTo += 1;
				// ... and definitely no match
				mLength = 1;
			}

			offset += mLength;

			boolean lastToken = (offset == n);
			// continue if simple literal
			if (mLength < MIN_MATCH && !lastToken) {
				continue;
			}

			// emit token
			int numLiterals = literalsTo - literalsFrom;
			int token = (numLiterals < 15) ? numLiterals : 15;
			token <<= 4;

			// store match length (4 is implied because it's the minimum match length)
			int matchLength = mLength - 4;
			if (!lastToken) {
				token |= (matchLength < 15) ? matchLength : 15;
			}

			result.write(token);
			tokens.add(token);

			tokenCount += 1;
			offsets.add(mDistance);
			lengths.add(matchLength);

			// >= 15 literals ? (extra bytes to store the length)
			if (numLiterals >= 15) {
				numLiterals -= 15;
				while (numLiterals >= 255) {
					result.write(255);
					lengthsBytes.add(255);
					numLiterals -= 255;
				}
				result.write(numLiterals);
				lengthsBytes.add(numLiterals);
			}

			// copy literals
			if (literalsFrom != literalsTo) {
				for (int z = literalsFrom; z < literalsTo; z++) {
					int b = data[index + z] & 0xFF;
					result.write(b);
					literalBytes.add(b);
				}
				literalsFrom = 0;
				literalsTo = 0;
			}

			// last token doesn't have a match
			if (lastToken) {
				break;
			}

			// stats
			if (mDistance > largestOffset) {
				largestOffset = mDistance;
			}
			if (matchLength > largestLength) {
				largestLength = matchLength;
			}
			if (mDistance < 256) {
				byteOffsetCount += 1;
			}
			if (mDistance == lastOffset) {
				sameOffsetCount += 1;
			}
			lastOffset = mDistance;

			// distance stored as 1 or 2 bytes in the data stream
			if (distanceByteSize == 1) {
				if (mDistance >= 256) {
					throw new IllegalStateException("match distance " + mDistance + " does not fit in 8 bits");
				}
				result.write(mDistance & 0xFF);
			} else {
				// little endian
				result.write(mDistance & 0xFF);
				result.write((mDistance >> 8) & 0xFF);
			}

			// >= 15+4 bytes matched
			if (matchLength >= 15) {
				matchLength -= 15;
				while (matchLength >= 255) {
					result.write(255);
					lengthsBytes.add(255);
					matchLength -= 255;
				}
				result.write(matchLength);
				lengthsBytes.add(matchLength);
			}
		}

		return result.toByteArray();
	}

	// -----------------------------------------------------------------------------
	// helpers
	// -----------------------------------------------------------------------------

	/** struct.unpack('&gt;L', data[offset:offset+4]) - unsigned big endian 32 bits */
	private static long getLong(byte[] buf, int offset) {
		return ((long) (buf[offset] & 0xFF) << 24) | ((buf[offset + 1] & 0xFF) << 16)
				| ((buf[offset + 2] & 0xFF) << 8) | (buf[offset + 3] & 0xFF);
	}

	private void dataEnsure(int extra) {
		if (dataLen + extra > data.length) {
			int cap = Math.max(data.length * 2, dataLen + extra);
			byte[] grown = new byte[cap];
			System.arraycopy(data, 0, grown, 0, dataLen);
			data = grown;
		}
	}

	private void dataExtend(byte[] src, int from, int count) {
		dataEnsure(count);
		System.arraycopy(src, from, data, dataLen, count);
		dataLen += count;
	}

	private void dataExtendZero(int count) {
		dataEnsure(count);
		java.util.Arrays.fill(data, dataLen, dataLen + count, (byte) 0);
		dataLen += count;
	}

	/** Minimal growable int list, stands in for the Python stats lists. */
	public static final class IntList {
		private int[] a = new int[64];
		private int n;

		public void add(int v) {
			if (n == a.length) {
				int[] grown = new int[a.length * 2];
				System.arraycopy(a, 0, grown, 0, n);
				a = grown;
			}
			a[n++] = v;
		}

		public int get(int i) {
			if (i < 0 || i >= n) {
				throw new IndexOutOfBoundsException(Integer.toString(i));
			}
			return a[i];
		}

		public int size() {
			return n;
		}

		public void clear() {
			n = 0;
		}

		public int[] toArray() {
			int[] out = new int[n];
			System.arraycopy(a, 0, out, 0, n);
			return out;
		}
	}
}
