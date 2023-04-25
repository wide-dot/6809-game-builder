package com.widedot.toolbox.debug.ui;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.Symbols;
import com.widedot.toolbox.debug.types.VideoBufferImage;

import imgui.ImVec2;
import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class SpriteRender {

	private static final int COLOR_WHITE = 0x88FFFFFF;
	private static final int COLOR_GREY = 0x88AAAAAA;
	private static final int COLOR_RED = 0x880000FF;
	private static final int COLOR_PURPLE = 0x88FF00FF;
	private static final int COLOR_CENTER = 0xFFFF00FF;
	private static final int COLOR_GREEN = 0x8800FF00;
	private static final int COLOR_BLUE = 0x88FF0000;	
	private static final int COLOR_LBLUE = 0x88FFEF0F;
	
	private static int xscale = 6;
	private static int yscale = 3;
	
	private static int XRES = 160;
	private static int YRES = 200;
	
	private static int VRES = 256;	
	
	private static int xoffset = (VRES-XRES)/2;
	private static int yoffset = (VRES-YRES)/2;

	private static ImVec2 vMin;
	
	public static ImBoolean workingChk = new ImBoolean(true);
	public static VideoBufferImage image = new VideoBufferImage(XRES, YRES);
		
	public static void show(ImBoolean showImGui) {
		
        if (ImGui.begin("Sprite Render", showImGui)) {
			vMin = ImGui.getWindowContentRegionMin();
			vMin.x += ImGui.getWindowPos().x;
			vMin.y += ImGui.getWindowPos().y+25;
			
	   	 	ImGui.checkbox("visible buffer##workingChkSR", workingChk);
	   	 	ImGui.text("Page: "+image.getPage(workingChk));
			ImGui.getWindowDrawList().addRectFilled(vMin.x, vMin.y, vMin.x+xscale*VRES, vMin.y+yscale*VRES, COLOR_GREY);
			int x1 = (int) vMin.x+xscale*xoffset;
			int y1 = (int) vMin.y+yscale*yoffset;
			int x2 = x1+xscale*XRES;
			int y2 = y1+yscale*YRES;
			ImGui.getWindowDrawList().addImage(image.get(workingChk), x1, y1, x2, y2);
			ImGui.getWindowDrawList().addRect(x1-1, y1-1, x2+1, y2+1, COLOR_PURPLE);
			
			drawGrid(x1, y1, x2, y2);			
			displayRenderBox("object_list_first");
	   	 	
    	    ImGui.end();
        }
	}
	
	private static void drawGrid(int x1, int y1, int x2, int y2) {
		for (int x = x1; x < x2; x += 2*xscale) {
			ImGui.getWindowDrawList().addLine(x-1, y1, x-1, y2, COLOR_BLUE);
			ImGui.getWindowDrawList().addLine(x, y1, x, y2, COLOR_BLUE);
		}
	}
	
	private static void displayRenderBox(String list) {

   	 	String rsv_bufferName = (image.getPage(workingChk)==2?"rsv_buffer_0":"rsv_buffer_1");
   	 	String rsv_bufferStr = Symbols.symbols.get(rsv_bufferName);
   	 	String run_object_nextStr = Symbols.symbols.get("run_object_next");
   	 	String x_pixelStr = Symbols.symbols.get("x_pixel");
   		String y_pixelStr = Symbols.symbols.get("y_pixel");
   	 	String rsv_x1_pixelStr = Symbols.symbols.get("rsv_x1_pixel");
   		String rsv_y1_pixelStr = Symbols.symbols.get("rsv_y1_pixel");
   		String rsv_x2_pixelStr = Symbols.symbols.get("rsv_x2_pixel");
   		String rsv_y2_pixelStr = Symbols.symbols.get("rsv_y2_pixel");
   	 	String rsv_prev_x1_pixelStr = Symbols.symbols.get("buf_prev_x1_pixel");
   		String rsv_prev_y1_pixelStr = Symbols.symbols.get("buf_prev_y1_pixel");
   		String rsv_prev_x2_pixelStr = Symbols.symbols.get("buf_prev_x2_pixel");
   		String rsv_prev_y2_pixelStr = Symbols.symbols.get("buf_prev_y2_pixel");

   		Long rsv_buffer       = Long.parseLong(rsv_bufferStr, 16);
   		int run_object_next   = Integer.parseInt(run_object_nextStr, 16);

   		int x_pixel = Integer.parseInt(x_pixelStr, 16); // center x
   		int y_pixel = Integer.parseInt(y_pixelStr, 16); //  enter y
   		
   		int rsv_x1_pixel = Integer.parseInt(rsv_x1_pixelStr, 16); // x+x_offset-(x_size/2) screen coordinate b
   		int rsv_y1_pixel = Integer.parseInt(rsv_y1_pixelStr, 16); // y+y_offset-(y_size/2) screen coordinate b, must follow x1_pixel
   		int rsv_x2_pixel = Integer.parseInt(rsv_x2_pixelStr, 16); // x+x_offset+(x_size/2) screen coordinate b
   		int rsv_y2_pixel = Integer.parseInt(rsv_y2_pixelStr, 16); // y+y_offset+(y_size/2) screen coordinate b, must follow x2_pixel
   		
        int rsv_prev_x1_pixel = Integer.parseInt(rsv_prev_x1_pixelStr, 16); // previous x+x_offset-(x_size/2) screen coordinate b
        int rsv_prev_y1_pixel = Integer.parseInt(rsv_prev_y1_pixelStr, 16); // previous y+y_offset-(y_size/2) screen coordinate b, must follow x1_pixel
        int rsv_prev_x2_pixel = Integer.parseInt(rsv_prev_x2_pixelStr, 16); // previous x+x_offset+(x_size/2) screen coordinate b
        int rsv_prev_y2_pixel = Integer.parseInt(rsv_prev_y2_pixelStr, 16); // previous y+y_offset+(y_size/2) screen coordinate b, must follow x2_pixel
   	 	
		String listFirst = Symbols.symbols.get(list);
    	Long curAdr = Emulator.getAbsoluteAddress(1, listFirst);
   	 	if (curAdr==null) {return;}
   	 	
   	 	Integer next = Emulator.get(curAdr, 2);
   	    int cx, cy, x1, y1, x2, y2;
  	 	int prev_x1, prev_y1, prev_x2, prev_y2;
   	 	
   	 	while (next != 0) {
	   	 	Long obj = Emulator.getAbsoluteAddress(1, next);
	   	 	if (obj == null)
	   	 		break;

			cx = Emulator.get(obj+x_pixel, 1);
			cy = Emulator.get(obj+y_pixel, 1);
			
			x1 = Emulator.get(obj+rsv_x1_pixel, 1);
			y1 = Emulator.get(obj+rsv_y1_pixel, 1);
			x2 = Emulator.get(obj+rsv_x2_pixel, 1);
			y2 = Emulator.get(obj+rsv_y2_pixel, 1);
	   	 	
	   	 	Long bufferPos = obj+rsv_buffer;
			prev_x1 = Emulator.get(bufferPos+rsv_prev_x1_pixel, 1);
			prev_y1 = Emulator.get(bufferPos+rsv_prev_y1_pixel, 1);
			prev_x2 = Emulator.get(bufferPos+rsv_prev_x2_pixel, 1);
			prev_y2 = Emulator.get(bufferPos+rsv_prev_y2_pixel, 1);
			
            ImGui.getWindowDrawList().addRect(vMin.x+xscale*prev_x1, vMin.y+yscale*prev_y1,
            		                          vMin.x+xscale*(prev_x2+1), vMin.y+yscale*(prev_y2+1), COLOR_PURPLE);
            
            ImGui.getWindowDrawList().addRect(vMin.x+xscale*x1, vMin.y+yscale*y1,
                                              vMin.x+xscale*(x2+1), vMin.y+yscale*(y2+1), COLOR_WHITE);

            // center
            ImGui.getWindowDrawList().addLine(vMin.x+xscale*cx, vMin.y+yscale*cy+yscale/2, vMin.x+xscale*(cx+1)+1, vMin.y+yscale*cy+yscale/2, COLOR_CENTER);
            ImGui.getWindowDrawList().addLine(vMin.x+xscale*cx+xscale/2, vMin.y+yscale*cy-yscale/2, vMin.x+xscale*cx+xscale/2, vMin.y+yscale*(cy+1)+yscale/2, COLOR_CENTER);
            
            // id
            ImGui.getWindowDrawList().addText(vMin.x+xscale*x1, vMin.y+yscale*(y1-5), COLOR_WHITE, Integer.toHexString(next));
            
			next = Emulator.get(obj+run_object_next, 2);
            
   	 	}
	}
}
