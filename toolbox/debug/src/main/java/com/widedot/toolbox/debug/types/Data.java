package com.widedot.toolbox.debug.types;

import java.util.HashMap;

import imgui.flag.ImGuiDataType;
import imgui.flag.ImGuiInputTextFlags;

public class Data {
    public final static String U8  = "u8";
    public final static String S8  = "s8";
    public final static String U16 = "u16";
    public final static String S16 = "s16";
    
    public final static String U8h  = "u8h";
    public final static String S8h  = "s8h";
    public final static String U16h = "u16h";
    public final static String S16h = "s16h";
    
    public final static HashMap<String, String> format = new HashMap<String, String>();
    public final static HashMap<String, Integer> imType = new HashMap<String, Integer>();
    public final static HashMap<String, Integer> byteLen = new HashMap<String, Integer>();
    public final static HashMap<String, Integer> imFlags = new HashMap<String, Integer>();
    
    static {
    	format.put(U8,   "%u");
    	format.put(S8,   "%d");
    	format.put(U16,  "%u");
    	format.put(S16,  "%d");
    	format.put(U8h,  "%02X");
    	format.put(S8h,  "%02X");
    	format.put(U16h, "%04X");
    	format.put(S16h, "%04X");
    	
    	imType.put(U8,   ImGuiDataType.U8);
    	imType.put(S8,   ImGuiDataType.S8);
    	imType.put(U16,  ImGuiDataType.U16);
    	imType.put(S16,  ImGuiDataType.S16);
    	imType.put(U8h,  ImGuiDataType.U8);
    	imType.put(S8h,  ImGuiDataType.S8);
    	imType.put(U16h, ImGuiDataType.U16);
    	imType.put(S16h, ImGuiDataType.S16);
    	
    	byteLen.put(U8,   1);
    	byteLen.put(S8,   1);
    	byteLen.put(U16,  2);
    	byteLen.put(S16,  2);
    	byteLen.put(U8h,  1);
    	byteLen.put(S8h,  1);
    	byteLen.put(U16h, 2);
    	byteLen.put(S16h, 2);
    	
    	imFlags.put(U8,   ImGuiInputTextFlags.CharsDecimal);
    	imFlags.put(S8,   ImGuiInputTextFlags.CharsDecimal);
    	imFlags.put(U16,  ImGuiInputTextFlags.CharsDecimal);
    	imFlags.put(S16,  ImGuiInputTextFlags.CharsDecimal);
    	imFlags.put(U8h,  ImGuiInputTextFlags.CharsHexadecimal | ImGuiInputTextFlags.CharsUppercase);
    	imFlags.put(S8h,  ImGuiInputTextFlags.CharsHexadecimal | ImGuiInputTextFlags.CharsUppercase);
    	imFlags.put(U16h, ImGuiInputTextFlags.CharsHexadecimal | ImGuiInputTextFlags.CharsUppercase);
    	imFlags.put(S16h, ImGuiInputTextFlags.CharsHexadecimal | ImGuiInputTextFlags.CharsUppercase);
    }
}
