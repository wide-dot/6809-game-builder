package com.widedot.toolbox.debug.types;

import com.widedot.toolbox.debug.Symbols;

import imgui.type.ImBoolean;
import imgui.type.ImInt;
import imgui.type.ImString;

public class WatchElem {
    public ImInt value = new ImInt(0);
	public ImString symbol = new ImString(100);
	public ImBoolean symbolFiltering = new ImBoolean(false);
    public String type;
    public String[] types;
    
    public WatchElem(String type, String[] types) {
        this.type = type;
        this.types = types;
    }
    
    public void set(WatchElem w) {
    	this.value = new ImInt(w.value);
    	this.symbol = new ImString(w.symbol);
    	this.symbolFiltering = new ImBoolean(w.symbolFiltering);
    	this.type = new String(w.type);
    	this.types = w.types;
    }
    
    public void refreshValue() {
    	int intVal;
    	String val = Symbols.symbols.get(symbol.get());
    	
    	if(val == null || val.equals("")) {
    		intVal = value.get();
    	} else {
    		intVal = Integer.parseInt(val, 16);
    	}
    	
    	switch(type)
    	{
    		case Data.S8 :
    		case Data.S8h : intVal = (byte) intVal; break;
    		case Data.S16 :
    		case Data.S16h : intVal = (short) intVal; break;
    		case Data.U8 :
    		case Data.U8h :  
    		case Data.U16 :
    		case Data.U16h : break ;// intVal == intVal, so no op,
    		default : throw new IllegalStateException(); 			
    	}
    	
    	value.set(intVal);
    	
    }
    
    public int getValue() {	 	
    	switch(type)
    	{
    		case Data.S8 :
    		case Data.S8h : return (byte) value.get(); 
    		case Data.S16 :
    		case Data.S16h : return (short) value.get();
    		case Data.U8 :
    		case Data.U8h :  
    		case Data.U16 :
    		case Data.U16h : return value.get(); 
    		default : throw new IllegalStateException(); 			
    	}
    }
}
