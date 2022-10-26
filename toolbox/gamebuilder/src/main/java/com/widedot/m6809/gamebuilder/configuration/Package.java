package com.widedot.m6809.gamebuilder.configuration;

import java.io.File;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Package {
	
	public static final String MULTIPAGE = "multi-page";
	public static final String ABSOLUTE = "absolute";
	public static final String RELOCATABLE = "relocatable";
	
	public String catalog;
	public String filename;
	public File file;
	public FileSet fileset;
	
	public String name;
	public String type;
	public String compression;
	public String ram;
	public Integer orgOffset;
	public Integer clusterSize;
	public Integer _org;
	
	public Package(HierarchicalConfiguration<ImmutableNode> node, String path) throws Exception {
		filename = node.getString("", null);
		if (filename == null) {
			throw new Exception("file value is missing for package");
		}
		filename = path + filename;
		
		catalog = node.getString("[@catalog]", null);
		log.debug("package: " + filename + " catalog: " + catalog);
		
		file = new File(filename);
		if (!file.exists() || file.isDirectory()) {
			throw new Exception("File "+file.getName()+" does not exists !");
		}
		
		parse();
	}
	
	private void parse() throws Exception {
	    String path = FileUtil.getParentDir(file);
		
	    // parse the xml
		Configurations configs = new Configurations();
	    XMLConfiguration node = configs.xml(file);		
	    
	    List<HierarchicalConfiguration<ImmutableNode>> pkgFields = node.configurationsAt("package");
    	for(HierarchicalConfiguration<ImmutableNode> pkg : pkgFields)
    	{	
    		// multi-page :  name="titlescreen" type="multi-page" compression="none" ram="$0000-3FFF" org-offset="0" cluster-size="$2000"
    		// absolute :    name="titlescreen-main" type="absolute" compression="none" org="$6100"
    		// relocatable : name="data" type="relocatable" compression="zx0"
    		
    		// for all all types
    		name = pkg.getString("[@name]", null);
    		if (name == null) {
    			throw new Exception("name is missing for package");
    		}
    		
    		type = pkg.getString("[@type]", null);
    		if (type == null) {
    			throw new Exception("type is missing for package");
    		}
    		
    		compression = pkg.getString("[@compression]", "none");
    		
    		// MULTIPAGE only
    		if (type.equals(MULTIPAGE)) {
	    		ram = pkg.getString("[@ram]", null);
        		if (ram == null) {
        			throw new Exception("ram is missing for package of type "+MULTIPAGE);
        		}
        		
	    		String orgOffsetStr = pkg.getString("[@org-offset]", "0");
    			if (orgOffsetStr.contains("$")) {
    				orgOffset = Integer.parseInt(orgOffsetStr.replace("$", ""), 16);	
    			} else {
    				orgOffset = Integer.parseInt(orgOffsetStr);
    			}	    		
	    		
	    		String clusterSizeStr = pkg.getString("[@cluster-size]", null);
	    		if (clusterSize == null) {
	    			String[] ramRange = ram.split("-");
	    			if (ramRange.length != 2) {
	    				throw new Exception("ram value : <" + ram + "> should be expressed with two values separated by an hyphen in hexadecimal or decimal (ex:$0000-$3FFF or 0-16383)");
	    			}
	    			int[] ramRangeDec = new int[ramRange.length];
	    			if (ramRange[0].contains("$")) {
	    				ramRangeDec[0] = Integer.parseInt(ramRange[0].replace("$", ""), 16);	
	    			} else {
	    				ramRangeDec[0] = Integer.parseInt(ramRange[0]);
	    			}
	    			if (ramRange[1].contains("$")) {
	    				ramRangeDec[1] = Integer.parseInt(ramRange[1].replace("$", ""), 16);	
	    			} else {
	    				ramRangeDec[1] = Integer.parseInt(ramRange[1]);
	    			}
	    			clusterSize = ramRangeDec[1]-ramRangeDec[0];
	    		} else {
	    			if (clusterSizeStr.contains("$")) {
	    				clusterSize = Integer.parseInt(clusterSizeStr.replace("$", ""), 16);	
	    			} else {
	    				clusterSize = Integer.parseInt(clusterSizeStr);
	    			}
	    		}
    		}
    		
    		// ABSOLUTE only
    		if(type.equals(ABSOLUTE)) {
    			String orgStr = pkg.getString("[@org]", null);
        		if (orgStr == null) {
        			throw new Exception("org is missing for package of type "+ABSOLUTE);
        		}
    			if (orgStr.contains("$")) {
    				_org = Integer.parseInt(orgStr.replace("$", ""), 16);	
    			} else {
    				_org = Integer.parseInt(orgStr);
    			}
    		}
    		
    		fileset = new FileSet(pkg, path);
    	}
	}
}
