package com.widedot.m6809.gamebuilder.plugin.machine;

import java.io.File;
import java.util.HashMap;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.config.XmlLoader;
import com.widedot.m6809.gamebuilder.spi.configuration.NodeAttr;
import com.widedot.m6809.gamebuilder.spi.globals.Machines;

/**
 * The machine definitions file, read exactly like the storage geometry one :
 * same loader, same decoding with file:line positions, one file holding every
 * declination and a name to pick from it.
 */
public class MachineDefs {

	public HashMap<String, Machines.Machine> machines;

	public MachineDefs(String filename) throws Exception {
		machines = new HashMap<String, Machines.Machine>();

		File file = new File(filename);
		if (!file.exists() || file.isDirectory()) {
			throw new Exception("File " + filename + " does not exists !");
		}

		XmlLoader.Result result = XmlLoader.load(file);
		for (ImmutableNode child : result.root.getChildren()) {
			if (!"machine".equals(child.getNodeName())) {
				continue;
			}
			String name = NodeAttr.getString(child, result.sources, "name");
			ImmutableNode ram = NodeAttr.child(child, result.sources, "ram");
			ImmutableNode pagebyte = NodeAttr.child(child, result.sources, "pagebyte");
			machines.put(name, new Machines.Machine(name,
					NodeAttr.getInteger(ram, result.sources, "pages"),
					NodeAttr.getString(pagebyte, result.sources, "expr"),
					NodeAttr.getString(pagebyte, result.sources, "include")));
		}
	}

	public Machines.Machine get(String key) {
		return machines.get(key);
	}
}
