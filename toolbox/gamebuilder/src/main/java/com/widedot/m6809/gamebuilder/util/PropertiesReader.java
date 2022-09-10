package com.widedot.m6809.gamebuilder.util;

import lombok.Builder;

@Builder(buildMethodName = "build")
public class PropertiesReader
{

	private OrderedProperties properties;
	
	public String get(String propertyName)
	{
		String result = properties.getProperty(propertyName);
		
		if (result != null)
		{ return result; }

		String message = String.format("Error reading property %s : there is no defined value.", propertyName);
		throw new RuntimeException(message);
	}

}

