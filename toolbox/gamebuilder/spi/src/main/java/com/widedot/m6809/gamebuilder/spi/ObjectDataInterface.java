package com.widedot.m6809.gamebuilder.spi;

import java.util.List;

public interface ObjectDataInterface {
	byte[] getBytes() throws Exception;

	List<byte[]> getExportedConst() throws Exception;

	List<byte[]> getExported() throws Exception;

	List<byte[]> getInternal() throws Exception;

	List<byte[]> getIncomplete8() throws Exception;

	List<byte[]> getIncomplete16() throws Exception;
}
