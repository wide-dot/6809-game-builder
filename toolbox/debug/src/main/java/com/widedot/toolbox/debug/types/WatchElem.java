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
    	
		value.set(switch (type) {
		    case Data.S8, Data.S8h -> (byte) intVal;
		    case Data.S16, Data.S16h -> (short) intVal;
		    case Data.U8, Data.U8h, Data.U16, Data.U16h -> intVal;
		    default -> throw new IllegalStateException();
		});
    }
    
    public int getValue() {	
		return(switch (type) {
		    case Data.S8, Data.S8h -> (byte) value.get();
		    case Data.S16, Data.S16h -> (short) value.get();
		    case Data.U8, Data.U8h, Data.U16, Data.U16h -> value.get();
		    default -> throw new IllegalStateException();
		});
    }
}
