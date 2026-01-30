package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;
import com.widedot.toolbox.debug.types.VideoBufferImage;

import imgui.ImVec2;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class CollisionBox {

	private static final int COLOR_WHITE = 0xFFFFFFFF;
	private static final int COLOR_BLACK = 0xFF000000;
	private static final int COLOR_GREY = 0x88AAAAAA;
	private static final int COLOR_RED = 0x280000FF;
	private static final int COLOR_ORANGE = 0x2842ADF5;
	private static final int COLOR_PURPLE = 0x28FF00FF;
	private static final int COLOR_GREEN = 0x2800FF00;
	private static final int COLOR_BLUE = 0x28FF0000;	
	private static final int COLOR_LBLUE = 0x28FFEF0F;
	private static final int COLOR_TERRAIN_BACKGROUND = 0x800000FF; // Semi-transparent red (ABGR: alpha=0x80, blue=0x00, green=0x00, red=0xFF)
	private static final int COLOR_TERRAIN_FOREGROUND = 0x8000A5FF; // Semi-transparent orange (ABGR: alpha=0x80, blue=0x00, green=0xA5, red=0xFF)
	private static final int COLOR_TERRAIN_EMPTY = 0x40FFFFFF; // Semi-transparent white for empty tiles (ABGR format)
	
	private static int xscale = 4;
	private static int yscale = 2;
	
	private static int XRES = 160;
	private static int YRES = 200;
	
	private static int VRES = 256;	
	
	private static int xoffset = (VRES-XRES)/2;
	private static int yoffset = (VRES-YRES)/2;

	private static ImVec2 vMin;
	
	public static ImBoolean workingChk = new ImBoolean(true);
	public static ImBoolean addressChk = new ImBoolean(true);
	public static ImBoolean potentialChk = new ImBoolean(true);
	public static ImBoolean terrainBackgroundChk = new ImBoolean(false);
	public static ImBoolean terrainForegroundChk = new ImBoolean(false);
	public static ImBoolean terrainGridChk = new ImBoolean(false);
	public static ImBoolean collisionBoxChk = new ImBoolean(true);
	public static VideoBufferImage image = new VideoBufferImage(XRES, YRES);
	
	public static void show(ImBoolean showImGui) {
		
        if (ImGui.begin("Collision", showImGui)) {
			vMin = ImGui.getWindowContentRegionMin();
			vMin.x += ImGui.getWindowPos().x;
			vMin.y += ImGui.getWindowPos().y+25;
			
	   	 	ImGui.checkbox("visible buffer##workingChk", workingChk);
	   	 	ImGui.sameLine();
	   	 	ImGui.checkbox("address##addressChk", addressChk);
	   	 	ImGui.sameLine();
	   	 	ImGui.checkbox("potential##potentialChk", potentialChk);
	   	 	ImGui.sameLine();
	   	 	ImGui.checkbox("background##terrainBackgroundChk", terrainBackgroundChk);
	   	 	ImGui.sameLine();
	   	 	ImGui.checkbox("foreground##terrainForegroundChk", terrainForegroundChk);
	   	 	ImGui.sameLine();
	   	 	ImGui.checkbox("grid##terrainGridChk", terrainGridChk);
	   	 	ImGui.sameLine();
	   	 	ImGui.checkbox("collision box##collisionBoxChk", collisionBoxChk);
	   	 	
	   	 	ImGui.text("Page: "+image.getPage(workingChk));
			ImGui.getWindowDrawList().addRectFilled(vMin.x, vMin.y, vMin.x+xscale*VRES, vMin.y+yscale*VRES, COLOR_GREY);
			int x1 = (int) vMin.x+xscale*xoffset;
			int y1 = (int) vMin.y+yscale*yoffset;
			int x2 = x1+xscale*XRES;
			int y2 = y1+yscale*YRES;
			
			ImGui.getWindowDrawList().addImage(image.get(workingChk), x1, y1, x2, y2);
			ImGui.getWindowDrawList().addRect(x1-1, y1-1, x2+1, y2+1, COLOR_PURPLE);
			
			// Display terrain overlay if enabled
			if (terrainBackgroundChk.get()) {
				displayTerrain(0, COLOR_TERRAIN_BACKGROUND); // Background map is at offset 0
			}
			if (terrainForegroundChk.get()) {
				displayTerrain(2, COLOR_TERRAIN_FOREGROUND); // Foreground map is at offset 2
			}
			if (terrainGridChk.get()) {
				displayTerrainGrid(); // Display grid for all terrain tiles
			}
			
			// Display collision boxes if enabled
			if (collisionBoxChk.get()) {
				displayList("AABB_list_friend", COLOR_GREEN);
				displayList("AABB_list_ennemy", COLOR_BLUE);
				displayList("AABB_list_ennemy_unkillable", COLOR_BLUE);
				displayList("AABB_list_player", COLOR_LBLUE);
				displayList("AABB_list_bonus", COLOR_PURPLE);
				displayList("AABB_list_forcepod", COLOR_ORANGE);
				displayList("AABB_list_foefire", COLOR_RED);
				displayList("AABB_list_supernova", COLOR_RED);
			}
    	    ImGui.end();
        }
	}
	
	private static void displayList(String list, int color) {
    	String listFirst = Symbols.symbols.get(list);
    	if (listFirst == null) return;
    	
   	 	Long curAdr = Emulator.getAbsoluteAddress(1, listFirst);
   	 	if (curAdr==null) {return;}
   	 	Integer next = Emulator.get(curAdr, 2);
   	 	if (next==0) {return;}
   	 	int p=0, rx=0, ry=0, cx=0, cy=0;
   	 	do {
	   	 	Long hitbox = Emulator.getAbsoluteAddress(1, next);
	   	 	
	   	 	if (hitbox == null)
	   	 		break;
	   	 	
			p = Emulator.get(hitbox, 1);
			rx = Emulator.get(hitbox+1, 1);
			ry = Emulator.get(hitbox+2, 1);
			cx = Emulator.get(hitbox+3, 1);
			cy = Emulator.get(hitbox+4, 1);

            ImGui.getWindowDrawList().addRect(xscale*xoffset+vMin.x+xscale*(cx-rx)-1, yscale*yoffset+vMin.y+yscale*(cy-ry)-1,
                    xscale*xoffset+vMin.x+xscale*(cx+rx+1)+1, yscale*yoffset+vMin.y+yscale*(cy+ry+1)+1, COLOR_BLACK);
            
            ImGui.getWindowDrawList().addRect(xscale*xoffset+vMin.x+xscale*(cx-rx), yscale*yoffset+vMin.y+yscale*(cy-ry),
            		                          xscale*xoffset+vMin.x+xscale*(cx+rx+1), yscale*yoffset+vMin.y+yscale*(cy+ry+1), COLOR_WHITE);
            
            ImGui.getWindowDrawList().addRect(xscale*xoffset+vMin.x+xscale*(cx-rx)+1, yscale*yoffset+vMin.y+yscale*(cy-ry)+1,
                    xscale*xoffset+vMin.x+xscale*(cx+rx+1)-1, yscale*yoffset+vMin.y+yscale*(cy+ry+1)-1, COLOR_WHITE);
			
            ImGui.getWindowDrawList().addRectFilled(xscale*xoffset+vMin.x+xscale*(cx-rx), yscale*yoffset+vMin.y+yscale*(cy-ry),
                    xscale*xoffset+vMin.x+xscale*(cx+rx+1), yscale*yoffset+vMin.y+yscale*(cy+ry+1), color);
            
            if (addressChk.get()) {
            	ImGui.getWindowDrawList().addText(ImGui.getFont(), 16, xscale*xoffset+vMin.x+xscale*(cx-rx), yscale*yoffset+vMin.y+yscale*(cy-ry-20),
            										COLOR_WHITE, Integer.toHexString(next));
            }
            
            if (potentialChk.get()) {
            	ImGui.getWindowDrawList().addText(ImGui.getFont(), 16, xscale*xoffset+vMin.x+xscale*(cx-rx), yscale*yoffset+vMin.y+yscale*(cy-ry-10),
            										COLOR_WHITE, ""+p);
            }
            
			next = Emulator.get(hitbox+7, 2);
            
   	 	} while (next != 0);
	}
	
	private static void displayTerrain(int mapOffset, int terrainColor) {
		// Get terrainCollision.main.page to determine the page for the map
		String pageSymbol = Symbols.symbols.get("terrainCollision.main.page");
		if (pageSymbol == null) return;
		
		Long pageAddr = Emulator.getAbsoluteAddress(1, pageSymbol);
		if (pageAddr == null) return;
		
		// Read the page number (1 byte) - mask to get only the 5 lower bits (0-31)
		Integer pageNumRaw = Emulator.get(pageAddr, 1);
		if (pageNumRaw == null) return;
		// Mask with 0x1F to get only the 5 lower bits (page number 0-31)
		int pageNum = pageNumRaw & 0x1F;
		
		// Get terrainCollision.maps address - use the same page as terrainCollision.main.page
		String mapsSymbol = Symbols.symbols.get("terrainCollision.maps");
		if (mapsSymbol == null) return;
		
		Long mapsAddr = Emulator.getAbsoluteAddress(pageNum, mapsSymbol);
		if (mapsAddr == null) return;
		
		// Read the map pointer at the specified offset (2 bytes, little-endian)
		// mapOffset: 0 for background, 2 for foreground
		Integer mapPtr = Emulator.get(mapsAddr + mapOffset, 2);
		if (mapPtr == null || mapPtr == 0) return;
		
		// Get the actual map address using the same page (both are on the same page)
		Long mapAddr = Emulator.getAbsoluteAddress(pageNum, mapPtr);
		if (mapAddr == null) return;
		
		// Get camera scroll position
		String cameraSymbol = Symbols.symbols.get("glb_camera_x_pos");
		if (cameraSymbol == null) return;
		
		Long cameraAddr = Emulator.getAbsoluteAddress(1, cameraSymbol);
		if (cameraAddr == null) return;
		
		// Read scroll viewport variables
		String scrollVpXPosSymbol = Symbols.symbols.get("scroll_vp_x_pos");
		String scrollVpYPosSymbol = Symbols.symbols.get("scroll_vp_y_pos");
		String scrollVpHtilesSymbol = Symbols.symbols.get("scroll_vp_h_tiles");
		String scrollVpVtilesSymbol = Symbols.symbols.get("scroll_vp_v_tiles");
		String scrollTileWidthSymbol = Symbols.symbols.get("scroll_tile_width");
		String scrollTileHeightSymbol = Symbols.symbols.get("scroll_tile_height");
		
		if (scrollVpXPosSymbol == null || scrollVpYPosSymbol == null || 
		    scrollVpHtilesSymbol == null || scrollVpVtilesSymbol == null ||
		    scrollTileWidthSymbol == null || scrollTileHeightSymbol == null) {
			return;
		}
		
		Long scrollVpXPosAddr = Emulator.getAbsoluteAddress(1, scrollVpXPosSymbol);
		Long scrollVpYPosAddr = Emulator.getAbsoluteAddress(1, scrollVpYPosSymbol);
		Long scrollVpHtilesAddr = Emulator.getAbsoluteAddress(1, scrollVpHtilesSymbol);
		Long scrollVpVtilesAddr = Emulator.getAbsoluteAddress(1, scrollVpVtilesSymbol);
		Long scrollTileWidthAddr = Emulator.getAbsoluteAddress(1, scrollTileWidthSymbol);
		Long scrollTileHeightAddr = Emulator.getAbsoluteAddress(1, scrollTileHeightSymbol);
		
		if (scrollVpXPosAddr == null || scrollVpYPosAddr == null ||
		    scrollVpHtilesAddr == null || scrollVpVtilesAddr == null ||
		    scrollTileWidthAddr == null || scrollTileHeightAddr == null) {
			return;
		}
		
		// Read scroll variables (all 1 byte)
		Integer scrollVpXPos = Emulator.get(scrollVpXPosAddr, 1);
		Integer scrollVpYPos = Emulator.get(scrollVpYPosAddr, 1);
		Integer scrollVpHtiles = Emulator.get(scrollVpHtilesAddr, 1);
		Integer scrollVpVtiles = Emulator.get(scrollVpVtilesAddr, 1);
		Integer scrollTileWidth = Emulator.get(scrollTileWidthAddr, 1);
		Integer scrollTileHeight = Emulator.get(scrollTileHeightAddr, 1);
		
		if (scrollVpXPos == null || scrollVpYPos == null ||
		    scrollVpHtiles == null || scrollVpVtiles == null ||
		    scrollTileWidth == null || scrollTileHeight == null) {
			return;
		}
		
		// Read camera position (16 bits, signed, in pixels) - still needed for world coordinates
		Integer cameraXRaw = Emulator.get(cameraAddr, 2);
		if (cameraXRaw == null) return;
		
		// Handle as signed 16-bit value (already in pixels, no conversion needed)
		int cameraXInt;
		if ((cameraXRaw & 0x8000) != 0) {
			// Negative value (signed 16-bit)
			cameraXInt = (cameraXRaw | 0xFFFF0000);
		} else {
			// Positive value
			cameraXInt = cameraXRaw;
		}
		
		// Collision tile dimensions: 3 pixels wide, 6 pixels tall
		final int COLLISION_TILE_WIDTH = 3;
		final int COLLISION_TILE_HEIGHT = 6;
		final int TILES_PER_BYTE = 8; // 8 bits per byte
		
		// Get map width in bytes from lvlMapWidth symbol
		int MAP_WIDTH_BYTES = 48; // Default fallback
		String lvlMapWidthSymbol = Symbols.symbols.get("lvlMapWidth");
		if (lvlMapWidthSymbol != null) {
			try {
				MAP_WIDTH_BYTES = Integer.parseInt(lvlMapWidthSymbol, 16);
			} catch (NumberFormatException e) {
				// Keep default if parsing fails
			}
		}
		
		// Convert scroll tiles to collision tiles
		// scroll_vp_h_tiles and scroll_vp_v_tiles are in scroll tile units
		// Each scroll tile is scroll_tile_width × scroll_tile_height pixels (12×12)
		// Each collision tile is 3px × 6px
		// In X: scroll tile is 12px wide, displayed as 24px (rectangular pixels). Collision tile is 3px wide, displayed as 6px.
		// So: 24px / 6px = 4 collision tiles per scroll tile in X
		// In Y: scroll tile is 12px high. Collision tile is 6px high.
		// So: 12px / 6px = 2 collision tiles per scroll tile in Y
		int collisionTilesPerScrollTileX = (scrollTileWidth * 2) / (COLLISION_TILE_WIDTH * 2); // (12*2)/(3*2) = 24/6 = 4
		int collisionTilesPerScrollTileY = scrollTileHeight / COLLISION_TILE_HEIGHT; // 12/6 = 2
		
		// scroll_vp_x_pos and scroll_vp_y_pos are in pixels and represent the offset for rendering on screen
		// scroll_vp_x_pos is already in displayed pixels (already doubled for rectangular pixels)
		int viewportOffsetX = scrollVpXPos + 1; // Already in displayed pixels
		int viewportOffsetY = scrollVpYPos; // Not doubled in Y
		
		// Calculate visible area in collision tiles based on viewport
		// scroll_vp_h_tiles and scroll_vp_v_tiles are the number of scroll tiles to display
		// Convert to collision tile units
		int visibleCollisionTilesX = scrollVpHtiles * collisionTilesPerScrollTileX; // 12 * 4 = 48
		int visibleCollisionTilesY = scrollVpVtiles * collisionTilesPerScrollTileY; // 15 * 2 = 30
		
		// For the start position, we need to find which collision tile corresponds to camera position
		// The camera position is in world pixels, we need to convert to collision tiles
		int startCollisionTileX = cameraXInt / COLLISION_TILE_WIDTH;
		int startCollisionTileY = 0; // Start from top of map
		
		// Calculate which bytes we need to read
		int startByteX = startCollisionTileX / TILES_PER_BYTE;
		int endByteX = (startCollisionTileX + visibleCollisionTilesX + TILES_PER_BYTE - 1) / TILES_PER_BYTE;
		
		// Handle negative byte indices
		if (startByteX < 0) startByteX = 0;
		
		// Calculate bit offset within the first byte
		int startBitOffset = startCollisionTileX % TILES_PER_BYTE;
		
		// Limit rows to viewport and map height
		int MAP_HEIGHT_ROWS = 30; // Default based on yOffset table
		String lvlMapHeightSymbol = Symbols.symbols.get("lvlMapHeight");
		if (lvlMapHeightSymbol != null) {
			try {
				int mapHeightPixels = Integer.parseInt(lvlMapHeightSymbol, 16);
				MAP_HEIGHT_ROWS = mapHeightPixels / COLLISION_TILE_HEIGHT;
			} catch (NumberFormatException e) {
				// Keep default
			}
		}
		
		// Number of visible rows (limited by viewport and map height)
		int visibleRows = Math.min(visibleCollisionTilesY, MAP_HEIGHT_ROWS - startCollisionTileY);
		if (visibleRows < 0) visibleRows = 0;
		
		// Read map data and render tiles
		for (int row = 0; row < visibleRows; row++) {
			int mapRow = startCollisionTileY + row;
			if (mapRow < 0 || mapRow >= MAP_HEIGHT_ROWS) continue;
			
			for (int byteX = startByteX; byteX <= endByteX; byteX++) {
				// Skip negative byte indices
				if (byteX < 0) continue;
				
				// Calculate byte offset in map (logical address)
				int byteOffset = (mapRow * MAP_WIDTH_BYTES) + byteX;
				
				// Calculate logical address and convert to physical address
				// We need to recalculate the address considering half-page boundaries
				int logicalAddr = mapPtr + byteOffset;
				Long byteAddr = Emulator.getAbsoluteAddress(pageNum, logicalAddr);
				if (byteAddr == null || byteAddr == 0) continue;
				
				// Read the byte
				Integer mapByte = Emulator.get(byteAddr, 1);
				if (mapByte == null) continue;
				
				// Process each bit in the byte
				int startBit = (byteX == startByteX) ? startBitOffset : 0;
				for (int bit = startBit; bit < TILES_PER_BYTE; bit++) {
					// Calculate collision tile position in map
					int collisionTileX = byteX * TILES_PER_BYTE + bit;
					
					// Check if within visible viewport area
					if (collisionTileX < startCollisionTileX || 
					    collisionTileX >= startCollisionTileX + visibleCollisionTilesX ||
					    mapRow < startCollisionTileY || 
					    mapRow >= startCollisionTileY + visibleCollisionTilesY) {
						continue;
					}
					
					// Calculate world pixel position
					int worldPixelX = collisionTileX * COLLISION_TILE_WIDTH;
					int worldPixelY = mapRow * COLLISION_TILE_HEIGHT;
					
					// Convert to screen coordinates (subtract camera position)
					int screenPixelX = worldPixelX - cameraXInt;
					int screenPixelY = worldPixelY;
					
					// Apply viewport offset for screen positioning
					// screenPixelX and screenPixelY are relative to camera
					// We need to add viewport offset to position on screen
					int displayX = screenPixelX + viewportOffsetX;
					int displayY = screenPixelY + viewportOffsetY;
					
					// Only draw if visible on screen
					if (displayX >= -COLLISION_TILE_WIDTH * 2 && displayX < XRES && 
					    displayY >= 0 && displayY < YRES) {
						
						// Draw 3x6 pixel rectangle
						// Collision tile is 3px wide, but displayed as 6px due to rectangular pixels
						// So we double the width when drawing
						int drawX1 = (int)(xscale * xoffset + vMin.x + xscale * displayX);
						int drawY1 = (int)(yscale * yoffset + vMin.y + yscale * displayY);
						int drawX2 = drawX1 + xscale * COLLISION_TILE_WIDTH;
						int drawY2 = drawY1 + yscale * COLLISION_TILE_HEIGHT;
						
						// Check if the bit is set (bits are from MSB to LSB: $80, $40, $20, $10, $08, $04, $02, $01)
						int bitMask = 0x80 >> bit;
						if ((mapByte & bitMask) != 0) {
							// Draw collision tile (color depends on background/foreground)
							ImGui.getWindowDrawList().addRectFilled(drawX1, drawY1, drawX2, drawY2, terrainColor);
						}
						// No longer drawing empty tiles here - use grid checkbox instead
					}
					
					// Stop if we've gone past the visible area
					if (collisionTileX >= startCollisionTileX + visibleCollisionTilesX) break;
				}
			}
		}
		
	}
	
	private static void displayTerrainGrid() {
		// Get terrainCollision.main.page to determine the page for the map
		String pageSymbol = Symbols.symbols.get("terrainCollision.main.page");
		if (pageSymbol == null) return;
		
		Long pageAddr = Emulator.getAbsoluteAddress(1, pageSymbol);
		if (pageAddr == null) return;
		
		// Read the page number (1 byte) - mask to get only the 5 lower bits (0-31)
		Integer pageNumRaw = Emulator.get(pageAddr, 1);
		if (pageNumRaw == null) return;
		// Mask with 0x1F to get only the 5 lower bits (page number 0-31)
		int pageNum = pageNumRaw & 0x1F;
		
		// Get terrainCollision.maps address - use the same page as terrainCollision.main.page
		String mapsSymbol = Symbols.symbols.get("terrainCollision.maps");
		if (mapsSymbol == null) return;
		
		Long mapsAddr = Emulator.getAbsoluteAddress(pageNum, mapsSymbol);
		if (mapsAddr == null) return;
		
		// Read scroll viewport variables
		String scrollVpXPosSymbol = Symbols.symbols.get("scroll_vp_x_pos");
		String scrollVpYPosSymbol = Symbols.symbols.get("scroll_vp_y_pos");
		String scrollVpHtilesSymbol = Symbols.symbols.get("scroll_vp_h_tiles");
		String scrollVpVtilesSymbol = Symbols.symbols.get("scroll_vp_v_tiles");
		String scrollTileWidthSymbol = Symbols.symbols.get("scroll_tile_width");
		String scrollTileHeightSymbol = Symbols.symbols.get("scroll_tile_height");
		
		if (scrollVpXPosSymbol == null || scrollVpYPosSymbol == null || 
		    scrollVpHtilesSymbol == null || scrollVpVtilesSymbol == null ||
		    scrollTileWidthSymbol == null || scrollTileHeightSymbol == null) {
			return;
		}
		
		Long scrollVpXPosAddr = Emulator.getAbsoluteAddress(1, scrollVpXPosSymbol);
		Long scrollVpYPosAddr = Emulator.getAbsoluteAddress(1, scrollVpYPosSymbol);
		Long scrollVpHtilesAddr = Emulator.getAbsoluteAddress(1, scrollVpHtilesSymbol);
		Long scrollVpVtilesAddr = Emulator.getAbsoluteAddress(1, scrollVpVtilesSymbol);
		Long scrollTileWidthAddr = Emulator.getAbsoluteAddress(1, scrollTileWidthSymbol);
		Long scrollTileHeightAddr = Emulator.getAbsoluteAddress(1, scrollTileHeightSymbol);
		
		if (scrollVpXPosAddr == null || scrollVpYPosAddr == null ||
		    scrollVpHtilesAddr == null || scrollVpVtilesAddr == null ||
		    scrollTileWidthAddr == null || scrollTileHeightAddr == null) {
			return;
		}
		
		// Read scroll variables (all 1 byte)
		Integer scrollVpXPos = Emulator.get(scrollVpXPosAddr, 1);
		Integer scrollVpYPos = Emulator.get(scrollVpYPosAddr, 1);
		Integer scrollVpHtiles = Emulator.get(scrollVpHtilesAddr, 1);
		Integer scrollVpVtiles = Emulator.get(scrollVpVtilesAddr, 1);
		Integer scrollTileWidth = Emulator.get(scrollTileWidthAddr, 1);
		Integer scrollTileHeight = Emulator.get(scrollTileHeightAddr, 1);
		
		if (scrollVpXPos == null || scrollVpYPos == null ||
		    scrollVpHtiles == null || scrollVpVtiles == null ||
		    scrollTileWidth == null || scrollTileHeight == null) {
			return;
		}
		
		// Get camera scroll position
		String cameraSymbol = Symbols.symbols.get("glb_camera_x_pos");
		if (cameraSymbol == null) return;
		
		Long cameraAddr = Emulator.getAbsoluteAddress(1, cameraSymbol);
		if (cameraAddr == null) return;
		
		// Read camera position (16 bits, signed, in pixels)
		Integer cameraXRaw = Emulator.get(cameraAddr, 2);
		if (cameraXRaw == null) return;
		
		// Handle as signed 16-bit value
		int cameraXInt;
		if ((cameraXRaw & 0x8000) != 0) {
			cameraXInt = (cameraXRaw | 0xFFFF0000);
		} else {
			cameraXInt = cameraXRaw;
		}
		
		// Collision tile dimensions: 3 pixels wide, 6 pixels tall
		final int COLLISION_TILE_WIDTH = 3;
		final int COLLISION_TILE_HEIGHT = 6;
		
		// Convert scroll tiles to collision tiles
		int collisionTilesPerScrollTileX = (scrollTileWidth * 2) / (COLLISION_TILE_WIDTH * 2);
		int collisionTilesPerScrollTileY = scrollTileHeight / COLLISION_TILE_HEIGHT;
		
		// Viewport offset (scroll_vp_x_pos is already in displayed pixels)
		int viewportOffsetX = scrollVpXPos + 1;
		int viewportOffsetY = scrollVpYPos;
		
		// Calculate visible area in collision tiles
		int visibleCollisionTilesX = scrollVpHtiles * collisionTilesPerScrollTileX;
		int visibleCollisionTilesY = scrollVpVtiles * collisionTilesPerScrollTileY;
		
		// Start position
		int startCollisionTileX = cameraXInt / COLLISION_TILE_WIDTH;
		int startCollisionTileY = 0;
		
		// Draw grid for all visible collision tiles
		for (int row = 0; row < visibleCollisionTilesY; row++) {
			int mapRow = startCollisionTileY + row;
			
			for (int tileX = 0; tileX < visibleCollisionTilesX; tileX++) {
				int collisionTileX = startCollisionTileX + tileX;
				
				// Calculate world pixel position
				int worldPixelX = collisionTileX * COLLISION_TILE_WIDTH;
				int worldPixelY = mapRow * COLLISION_TILE_HEIGHT;
				
				// Convert to screen coordinates
				int screenPixelX = worldPixelX - cameraXInt;
				int screenPixelY = worldPixelY;
				
				// Apply viewport offset
				int displayX = screenPixelX + viewportOffsetX;
				int displayY = screenPixelY + viewportOffsetY;
				
				// Only draw if visible on screen
				if (displayX >= -COLLISION_TILE_WIDTH * 2 && displayX < XRES && 
				    displayY >= 0 && displayY < YRES) {
					
					// Draw grid rectangle (outline only)
					int drawX1 = (int)(xscale * xoffset + vMin.x + xscale * displayX);
					int drawY1 = (int)(yscale * yoffset + vMin.y + yscale * displayY);
					int drawX2 = drawX1 + xscale * COLLISION_TILE_WIDTH;
					int drawY2 = drawY1 + yscale * COLLISION_TILE_HEIGHT;
					
					ImGui.getWindowDrawList().addRect(drawX1, drawY1, drawX2, drawY2, COLOR_TERRAIN_EMPTY);
				}
			}
		}
	}
}
