package com.widedot.toolbox.debug.types;

import imgui.type.ImString;

public class Watch {
    public ImString label = new ImString(100);
    
    public WatchElem page = new WatchElem(Data.U8, pageType);
    public WatchElem address = new WatchElem(Data.U16h, addressType);
    public WatchElem offset = new WatchElem(Data.S8, offsetType);
    public WatchElem value = new WatchElem(Data.S8, valueType);
    
    public final static String[] pageType = {Data.U8, Data.U8h};
    public final static String[] addressType = {Data.U16, Data.U16h};
    public final static String[] offsetType = {Data.U8, Data.S8, Data.U16, Data.S16, Data.U8h, Data.S8h, Data.U16h, Data.S16h};
    public final static String[] valueType = {Data.U8, Data.S8, Data.U16, Data.S16, Data.U8h, Data.S8h, Data.U16h, Data.S16h};

	public Watch() {
	}
	
	public Watch(Watch watch) {
		this.label = new ImString(watch.label.get());		
		this.page.set(watch.page);
		this.address.set(watch.address);
		this.offset.set(watch.offset);
		this.value.set(watch.value);
	}
}
