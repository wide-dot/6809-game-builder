package com.widedot.toolbox.debug.util;

public class WavFileException extends Exception
{
	private static final long serialVersionUID = -192301259023169132L;

	public WavFileException()
	{
		super();
	}

	public WavFileException(String message)
	{
		super(message);
	}

	public WavFileException(String message, Throwable cause)
	{
		super(message, cause);
	}

	public WavFileException(Throwable cause) 
	{
		super(cause);
	}
}
