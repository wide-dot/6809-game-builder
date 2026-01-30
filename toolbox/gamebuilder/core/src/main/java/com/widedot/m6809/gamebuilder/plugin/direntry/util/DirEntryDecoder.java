package com.widedot.m6809.gamebuilder.plugin.direntry.util;

import lombok.extern.slf4j.Slf4j;

import com.widedot.m6809.gamebuilder.spi.media.DirEntry;

/**
 * Utility class for decoding and analyzing directory entries in the direntry plugin.
 * 
 * This decoder is specifically designed for direntry plugin operations and provides
 * additional validation and analysis capabilities beyond basic decoding.
 * 
 * Directory entry format:
 * - Main structure (8 bytes): compression, linker flags, file size, disk location
 * - Optional compression block (8 bytes): offset and delta bytes
 * - Optional load time linker block (8 bytes): linker location data
 */
@Slf4j
public class DirEntryDecoder {
    
    /**
     * Comprehensive decoded directory entry information with validation
     */
    public static class DecodedDirEntry {
        public String name;
        public int dataLength;
        public boolean isValid;
        public String validationError;
        
        // Main structure
        public boolean compressed;
        public boolean loadTimeLinker;
        public int uncompressedSize;
        public boolean isEmpty;
        
        // Disk location
        public int track;
        public int face;
        public int sector;
        public int bytesFirstSector;
        public int startOffset;
        public int nbSectors;
        public int bytesLastSector;
        
        // Compression block (optional)
        public Integer compressedOffset;
        public byte[] deltaBytes;
        
        // Load time linker block (optional)
        public Integer linkerDataSize;
        public Integer linkerTrack;
        public Integer linkerFace;
        public Integer linkerSector;
        public Integer linkerBytesFirstSector;
        public Integer linkerStartOffset;
        public Integer linkerNbSectors;
        public Integer linkerBytesLastSector;
        
        // Analysis
        public int expectedSize;
        public boolean hasCompressionBlock;
        public boolean hasLinkerBlock;
    }
    
    /**
     * Decode a directory entry with validation
     * 
     * @param entry The directory entry to decode
     * @return DecodedDirEntry with all information and validation status
     */
    public static DecodedDirEntry decode(DirEntry entry) {
        DecodedDirEntry decoded = new DecodedDirEntry();
        decoded.name = entry.name;
        decoded.dataLength = entry.data.length;
        decoded.isValid = true;
        
        if (entry.data.length < 8) {
            decoded.isValid = false;
            decoded.validationError = "Entry data too short (minimum 8 bytes required)";
            return decoded;
        }
        
        byte[] data = entry.data;
        int idx = 0;
        
        // Decode main structure (8 bytes)
        decoded.compressed = (data[idx] & 0x80) != 0;
        decoded.loadTimeLinker = (data[idx] & 0x40) != 0;
        decoded.uncompressedSize = ((((data[idx] & 0xFF) << 8) | (data[idx + 1] & 0xFF)) + 1) & 0x3fff;
        idx += 2;
        
        decoded.track = (data[idx] >> 1) & 0x7F;
        decoded.face = data[idx] & 0x01;
        idx++;
        
        decoded.sector = data[idx] & 0xFF;
        idx++;
        
        decoded.bytesFirstSector = data[idx] & 0xFF;
        idx++;
        
        decoded.startOffset = data[idx] & 0xFF;
        idx++;
        
        decoded.nbSectors = data[idx] & 0xFF;
        idx++;
        
        decoded.bytesLastSector = data[idx] & 0xFF;
        idx++;
        
        decoded.isEmpty = (decoded.bytesFirstSector == 0xff && decoded.startOffset == 0);
        
        // Calculate expected size
        decoded.expectedSize = 8;
        if (decoded.compressed) decoded.expectedSize += 8;
        if (decoded.loadTimeLinker) decoded.expectedSize += 8;
        
        // Validate expected vs actual size
        if (decoded.dataLength != decoded.expectedSize) {
            decoded.isValid = false;
            decoded.validationError = String.format(
                "Entry size mismatch: expected %d bytes, got %d bytes", 
                decoded.expectedSize, decoded.dataLength
            );
        }
        
        // Decode compression block if present
        decoded.hasCompressionBlock = decoded.compressed && data.length >= idx + 8;
        if (decoded.compressed) {
            if (data.length >= idx + 8) {
                decoded.compressedOffset = ((data[idx] & 0xFF) << 8) | (data[idx + 1] & 0xFF);
                idx += 2;
                decoded.deltaBytes = new byte[6];
                System.arraycopy(data, idx, decoded.deltaBytes, 0, 6);
                idx += 6;
            } else {
                decoded.isValid = false;
                decoded.validationError = "Compression block expected but missing";
            }
        }
        
        // Decode load time linker block if present
        decoded.hasLinkerBlock = decoded.loadTimeLinker && data.length >= idx + 8;
        if (decoded.loadTimeLinker) {
            if (data.length >= idx + 8) {
                decoded.linkerDataSize = ((data[idx] & 0xFF) << 8) | (data[idx + 1] & 0xFF);
                idx += 2;
                
                decoded.linkerTrack = (data[idx] >> 1) & 0x7F;
                decoded.linkerFace = data[idx] & 0x01;
                idx++;
                
                decoded.linkerSector = data[idx] & 0xFF;
                idx++;
                
                decoded.linkerBytesFirstSector = data[idx] & 0xFF;
                idx++;
                
                decoded.linkerStartOffset = data[idx] & 0xFF;
                idx++;
                
                decoded.linkerNbSectors = data[idx] & 0xFF;
                idx++;
                
                decoded.linkerBytesLastSector = data[idx] & 0xFF;
            } else {
                decoded.isValid = false;
                decoded.validationError = "Load time linker block expected but missing";
            }
        }
        
        return decoded;
    }
    
    /**
     * Generate a detailed analysis report for a directory entry
     * 
     * @param decoded The decoded entry
     * @return Detailed analysis string
     */
    public static String generateAnalysisReport(DecodedDirEntry decoded) {
        StringBuilder sb = new StringBuilder();
        String lineSep = System.lineSeparator();
        
        sb.append("Directory entry structure size: ").append(decoded.dataLength).append(" bytes").append(lineSep);
        
        if (decoded.dataLength >= 8) {
            sb.append(lineSep);
            sb.append("--- Main Structure ---").append(lineSep);
            sb.append("Compression: ").append(decoded.compressed ? "zx0" : "none").append(lineSep);
            sb.append("Load Time Linker: ").append(decoded.loadTimeLinker ? "enabled" : "disabled").append(lineSep);
            sb.append("File content size (uncompressed): ").append(decoded.uncompressedSize).append(" bytes").append(lineSep);
            sb.append("File Status: ").append(decoded.isEmpty ? "EMPTY" : "CONTAINS DATA").append(lineSep);
            
            if (!decoded.isEmpty) {
                sb.append(lineSep);
                sb.append("--- Disk Location ---").append(lineSep);
                sb.append("Track: ").append(decoded.track).append(lineSep);
                sb.append("Face: ").append(decoded.face).append(lineSep);
                sb.append("Sector: ").append(decoded.sector + 1).append(lineSep);
                sb.append("File storage - Start offset: ").append(decoded.startOffset).append(lineSep);
                sb.append("File storage - First sector bytes: ").append(decoded.bytesFirstSector).append(lineSep);
                sb.append("File storage - Last sector bytes: ").append(decoded.bytesLastSector).append(lineSep);
                sb.append("File storage - Total Number of sectors: ").append(decoded.nbSectors).append(lineSep);                
            }
            
            if (decoded.compressed) {
                sb.append(lineSep);
                sb.append("--- Compression Block ---").append(lineSep);
                sb.append("Block Present: ").append(decoded.hasCompressionBlock ? "YES" : "NO").append(lineSep);
                if (decoded.hasCompressionBlock) {
                    sb.append("Compressed Offset: ").append(decoded.compressedOffset).append(lineSep);
                    sb.append("Delta Bytes: ");
                    if (decoded.deltaBytes != null) {
                        for (byte b : decoded.deltaBytes) {
                            sb.append(String.format("%02X ", b & 0xFF));
                        }
                    }
                    sb.append(lineSep);
                }
            }
            
            if (decoded.loadTimeLinker) {
                sb.append(lineSep);
                sb.append("--- Load Time Linker Block ---").append(lineSep);
                sb.append("Block Present: ").append(decoded.hasLinkerBlock ? "YES" : "NO").append(lineSep);
                if (decoded.hasLinkerBlock) {
                    sb.append("Linker content size: ").append(decoded.linkerDataSize).append(" bytes").append(lineSep);
                    sb.append("Linker Track: ").append(decoded.linkerTrack).append(lineSep);
                    sb.append("Linker Face: ").append(decoded.linkerFace).append(lineSep);
                    sb.append("Linker Sector: ").append(decoded.linkerSector + 1).append(lineSep);
                    sb.append("Linker storage - Start offset: ").append(decoded.linkerStartOffset).append(lineSep);
                    sb.append("Linker storage - First sector bytes: ").append(decoded.linkerBytesFirstSector).append(lineSep);
                    sb.append("Linker storage - Last sector bytes: ").append(decoded.linkerBytesLastSector).append(lineSep);
                    sb.append("Linker storage - Total Number of sectors: ").append(decoded.linkerNbSectors).append(lineSep);
                }
            }
        }
        
        return sb.toString();
    }
    
    /**
     * Decode and generate full analysis in one call
     * 
     * @param entry The directory entry to analyze
     * @return Full analysis report
     */
    public static String analyzeEntry(DirEntry entry) {
        return generateAnalysisReport(decode(entry));
    }
} 