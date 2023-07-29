package com.widedot.m6809.gamebuilder.spi;

import java.util.List;

public interface ObjectDataInterface {
	byte[] getBytes() throws Exception;

	List<byte[]> getExportAbs() throws Exception;

	List<byte[]> getExportRel() throws Exception;

	List<byte[]> getIntern() throws Exception;

	List<byte[]> getExtern8() throws Exception;

	List<byte[]> getExtern16() throws Exception;
}
