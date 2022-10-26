package com.widedot.m6809.oldgamebuilder.to8.storage.sap;

import java.nio.file.Files;
import java.nio.file.Paths;

import com.widedot.m6809.util.FileUtil;

public class Raw2Sap {

	public static void main(String[] args) throws Exception {
		String inputFile = args[0];
		String outputDiskName = FileUtil.removeExtension(inputFile)+".sap";
		byte[] fdBytes = Files.readAllBytes(Paths.get(inputFile));
		Sap sap = new Sap(fdBytes, Sap.SAP_FORMAT1);
		sap.write(outputDiskName);
		System.out.println("Done.");
	}
	
}
