package com.widedot.m6809.gamebuilder.configuration;

import java.io.File;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.XMLConfiguration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.util.FileUtil;
import com.widedot.m6809.util.math.Hex;

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
	public Integer ramStart;
	public Integer ramEnd;
	public Integer orgOffset;
	public Integer clusterSize;
	public Integer origin;
	
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
    		
    		log.debug("name: " + name + " type: " + type + " compression: " + compression);
    		
    		// MULTIPAGE only
    		if (type.equals(MULTIPAGE)) {
	    		String ramStr = pkg.getString("[@ram]", null);
        		if (ramStr == null) {
        			throw new Exception("ram is missing for package of type "+MULTIPAGE);
        		}
    			String[] ramRange = ramStr.split("-");
    			if (ramRange.length != 2) {
    				throw new Exception("ram value : <" + ramStr + "> should be expressed with two values separated by an hyphen in hexadecimal or decimal (ex:$0000-$3FFF or 0-16383)");
    			}
    			
    			ramStart = Hex.parse(ramRange[0]);
    			ramEnd = Hex.parse(ramRange[1]);
        		
	    		String orgOffsetStr = pkg.getString("[@org-offset]", "0");
	    		orgOffset = Hex.parse(orgOffsetStr);
	    		
	    		String clusterSizeStr = pkg.getString("[@cluster-size]", null);
	    		if (clusterSize == null) {
	    			clusterSize = ramEnd-ramStart;
	    		} else {
	    			clusterSize = Hex.parse(clusterSizeStr);
	    		}
	    		
	    		log.debug("MULTIPAGE ram :" + ramStr + " (" + ramStart + "-" + ramEnd + ") org-offset: " + orgOffsetStr + " (" + orgOffset + ") cluster-size: " + clusterSizeStr + " (" + clusterSize + ")");
    		}
    		
    		// ABSOLUTE only
    		if(type.equals(ABSOLUTE)) {
    			String orgStr = pkg.getString("[@org]", null);
        		if (orgStr == null) {
        			throw new Exception("org is missing for package of type "+ABSOLUTE);
        		}
   				origin = Hex.parse(orgStr);	
   				
   				log.debug("ABSOLUTE org: " + orgStr + " (" + origin + ")");
    		}
    		
    		fileset = new FileSet(pkg, path);
    	}
	}
}
