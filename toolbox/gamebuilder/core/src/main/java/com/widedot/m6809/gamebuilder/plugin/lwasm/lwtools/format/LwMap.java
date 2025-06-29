package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LwMap {
    
    private Map<String, Integer> symbols;
    private Path path;
    
    // Pattern to match: Symbol: <symbol_name> (<file_path>) = <hex_value>
    private static final Pattern SYMBOL_PATTERN = Pattern.compile(
        "Symbol:\\s+([^\\s]+)\\s+\\([^)]+\\)\\s+=\\s+([0-9A-Fa-f]{4})"
    );
    
    public LwMap(String filename) throws Exception {
        path = Paths.get(filename);
        symbols = new HashMap<>();
        parseMapFile();
    }
    
    private void parseMapFile() throws Exception {
        try {
            List<String> lines = Files.readAllLines(path, StandardCharsets.UTF_8);
            
            for (String line : lines) {
                line = line.trim();
                if (line.isEmpty()) {
                    continue;
                }
                
                Matcher matcher = SYMBOL_PATTERN.matcher(line);
                if (matcher.matches()) {
                    String symbolName = matcher.group(1);
                    String hexValue = matcher.group(2);
                    
                    try {
                        int value = Integer.parseInt(hexValue, 16);
                        symbols.put(symbolName, value);
                        
                        if (log.isDebugEnabled()) {
                            log.debug("LwMap: {} = 0x{} ({})", symbolName, hexValue, value);
                        }
                    } catch (NumberFormatException e) {
                        log.warn("Failed to parse hex value '{}' for symbol '{}'", hexValue, symbolName);
                    }
                } else {
                    if (log.isDebugEnabled()) {
                        log.debug("LwMap: Skipping line (no match): {}", line);
                    }
                }
            }
            
            log.debug("LwMap: Loaded {} symbols from {}", symbols.size(), path);
            
        } catch (IOException e) {
            throw new Exception("Failed to read LwMap file: " + path, e);
        }
    }
    
    /**
     * Get the value for a symbol
     * @param symbolName The symbol name to look up
     * @return The integer value of the symbol, or null if not found
     */
    public Integer getSymbolValue(String symbolName) {
        return symbols.get(symbolName);
    }
    
    /**
     * Check if a symbol exists in the map
     * @param symbolName The symbol name to check
     * @return true if the symbol exists, false otherwise
     */
    public boolean hasSymbol(String symbolName) {
        return symbols.containsKey(symbolName);
    }
    
    /**
     * Get all symbols as a map
     * @return Map of symbol names to their values
     */
    public Map<String, Integer> getAllSymbols() {
        return new HashMap<>(symbols);
    }
    
    /**
     * Get the number of symbols loaded
     * @return The number of symbols
     */
    public int getSymbolCount() {
        return symbols.size();
    }
} 