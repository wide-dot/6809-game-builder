package com.widedot.toolbox.text.phoneme;

import java.util.regex.Pattern;

public class Element {
	public String key;
	public String value;
	public Pattern p;
	
	public Element(String key, String value, Pattern p) {
		this.key = key;
		this.value = value;
		this.p = p;
	}
}