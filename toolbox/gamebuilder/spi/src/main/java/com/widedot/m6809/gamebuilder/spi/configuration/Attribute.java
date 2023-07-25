package com.widedot.m6809.gamebuilder.spi.configuration;

import org.apache.commons.configuration2.tree.ImmutableNode;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Attribute {

	public static String getString(ImmutableNode node, String attrName, String fullAttrName) throws Exception {
		return getString(node, (Defaults)null, attrName, fullAttrName, (String)null, false);
	}
	
	public static String getString(ImmutableNode node, Defaults defaults, String attrName, String fullAttrName) throws Exception {
		return getString(node, defaults, attrName, fullAttrName, (String)null, false);
	}
	
	public static String getString(ImmutableNode node, Defaults defaults, String attrName, String fullAttrName, String defaultVal) throws Exception {
		return getString(node, defaults, attrName, fullAttrName, defaultVal, false);
	}
	
	public static String getStringOpt(ImmutableNode node, Defaults defaults, String attrName, String fullAttrName) throws Exception {
		return getString(node, defaults, attrName, fullAttrName, (String)null, true);
	}
	
	public static String getString(ImmutableNode node, Defaults defaults, String attrName, String fullAttrName, String defaultVal, boolean optional) throws Exception {
		String val = (String) node.getAttributes().get(attrName);
		if (val == null && defaults != null) {
			val = defaults.getString(fullAttrName, defaultVal);
		}

		if (!optional && val == null) {
			String m = fullAttrName + " attribute is missing";
			
			log.error(m);
			throw new Exception(m);
		}
		
		log.debug("{}={}", fullAttrName, val);
		
		return val;
	}

	public static Integer getInteger(ImmutableNode node, String attrName, String fullAttrName) throws Exception {
		return getInteger(node, (Defaults)null, attrName, fullAttrName, (Integer)null, false);
	}
	
	public static Integer getInteger(ImmutableNode node, Defaults defaults, String attrName, String fullAttrName) throws Exception {
		return getInteger(node, defaults, attrName, fullAttrName, (Integer)null, false);
	}

	public static Integer getInteger(ImmutableNode node, Defaults defaults, String attrName, String fullAttrName, Integer defaultVal) throws Exception {
		return getInteger(node, defaults, attrName, fullAttrName, defaultVal, false);
	}

	public static Integer getIntegerOpt(ImmutableNode node, Defaults defaults, String attrName, String fullAttrName) throws Exception {
		return getInteger(node, defaults, attrName, fullAttrName, (Integer)null, true);
	}
	
	public static Integer getInteger(ImmutableNode node, Defaults defaults, String attrName, String fullAttrName, Integer defaultVal, boolean optional) throws Exception {
		return Integer.decode(getString(node, defaults, attrName, fullAttrName, (defaultVal==null?(String)null:defaultVal.toString()), optional));
	}

	public static boolean getBoolean(ImmutableNode node, Defaults defaults, String attrName, String fullAttrName, Boolean defaultVal) throws Exception {
		return (getString(node, defaults, attrName, fullAttrName, String.valueOf(defaultVal), false).equals("true")?true:false);
	}
}
