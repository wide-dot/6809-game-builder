package com.widedot.m6809.gamebuilder.spi.configuration;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;

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

	// ------------------------------------------------------------------
	// Context-based API.
	//
	// The defaults key is derived from the element name (<element>.<attr>),
	// so it cannot drift from the element that reads it — retyping it by
	// hand is how the direntry size guard ended up reading directory.maxsize
	// and stayed inactive. Errors carry the source position of the element.
	// ------------------------------------------------------------------

	public static String getString(ImmutableNode node, BuildContext ctx, String attrName) throws Exception {
		return resolve(node, ctx, attrName, null, false);
	}

	public static String getString(ImmutableNode node, BuildContext ctx, String attrName, String defaultVal) throws Exception {
		return resolve(node, ctx, attrName, defaultVal, false);
	}

	public static String getStringOpt(ImmutableNode node, BuildContext ctx, String attrName) throws Exception {
		return resolve(node, ctx, attrName, null, true);
	}

	public static Integer getInteger(ImmutableNode node, BuildContext ctx, String attrName) throws Exception {
		return toInt(node, ctx, attrName, resolve(node, ctx, attrName, null, false));
	}

	public static Integer getInteger(ImmutableNode node, BuildContext ctx, String attrName, Integer defaultVal) throws Exception {
		String v = resolve(node, ctx, attrName, defaultVal == null ? null : defaultVal.toString(), defaultVal != null);
		return v == null ? defaultVal : toInt(node, ctx, attrName, v);
	}

	public static Integer getIntegerOpt(ImmutableNode node, BuildContext ctx, String attrName) throws Exception {
		return toInt(node, ctx, attrName, resolve(node, ctx, attrName, null, true));
	}

	public static boolean getBoolean(ImmutableNode node, BuildContext ctx, String attrName, boolean defaultVal) throws Exception {
		String v = resolve(node, ctx, attrName, String.valueOf(defaultVal), true);
		if (v == null) return defaultVal;
		if (v.equalsIgnoreCase("true")) return true;
		if (v.equalsIgnoreCase("false")) return false;
		// the old behaviour made anything but "true" silently false
		throw new Exception(at(node, ctx) + "<" + node.getNodeName() + "> attribute '" + attrName
				+ "' must be true or false, got '" + v + "'");
	}

	private static String resolve(ImmutableNode node, BuildContext ctx, String attrName,
			String defaultVal, boolean optional) throws Exception {
		String val = (String) node.getAttributes().get(attrName);
		if (val == null && ctx.defaults != null) {
			val = ctx.defaults.getString(node.getNodeName() + "." + attrName, defaultVal);
		}
		if (!optional && val == null) {
			throw new Exception(at(node, ctx) + "<" + node.getNodeName() + "> is missing attribute '"
					+ attrName + "'");
		}
		log.debug("{}.{}={}", node.getNodeName(), attrName, val);
		return val;
	}

	private static Integer toInt(ImmutableNode node, BuildContext ctx, String attrName, String v) throws Exception {
		if (v == null) return null;
		try {
			return Values.parseInt(v);
		} catch (NumberFormatException e) {
			throw new Exception(at(node, ctx) + "<" + node.getNodeName() + "> attribute '" + attrName
					+ "': '" + v + "' is not a number (decimal, 0x or $ notation)");
		}
	}

	private static String at(ImmutableNode node, BuildContext ctx) {
		return ctx.sources == null ? "" : ctx.sources.locate(node) + ": ";
	}
}