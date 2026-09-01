package com.widedot.m6809.gamebuilder.plugin.machine;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.config.XmlLoader;
import com.widedot.m6809.gamebuilder.spi.configuration.NodeAttr;
import com.widedot.m6809.gamebuilder.spi.configuration.SourceMap;
import com.widedot.m6809.gamebuilder.spi.globals.Machines;

/**
 * Decodes {@code engine/config/machine.xml} — the machines, exactly as
 * {@code storage.xml} holds the media geometry.
 */
public class MachineDefs {

	/** what a window writes to say its page comes from a register */
	private static final String REGISTER = "register:";

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
			int pageSize = NodeAttr.getInteger(ram, result.sources, "pagesize", 0x4000);
			List<Machines.Window> windows = windows(child, result.sources, pageSize);
			// What a generated table writes in front of a page number is the
			// mask of the window that pages : one declaration, where it
			// belongs. It was a <pagebyte> element of its own, which could
			// name a mask no window used.
			Machines.Window masked = null;
			for (Machines.Window w : windows) {
				if (w.or != null) {
					masked = w;
					break;
				}
			}
			if (masked == null) {
				throw new Exception(result.sources.locate(child) + ": machine '" + name
						+ "' declares no window carrying an 'or' mask — generated tables"
						+ " would have nothing to write in front of a page number");
			}
			machines.put(name, new Machines.Machine(name,
					NodeAttr.getInteger(ram, result.sources, "pages"),
					pageSize, masked.or + "+", masked.include, windows));
		}
	}

	private static List<Machines.Window> windows(ImmutableNode machine, SourceMap sources,
			int pageSize) throws Exception {
		List<Machines.Window> windows = new ArrayList<Machines.Window>();
		for (ImmutableNode node : machine.getChildren()) {
			if (!"window".equals(node.getNodeName())) {
				continue;
			}
			String name = NodeAttr.getString(node, sources, "name");
			int address = NodeAttr.getInteger(node, sources, "address");
			int size = NodeAttr.getInteger(node, sources, "size");
			String page = NodeAttr.getString(node, sources, "page");

			Integer fixedPage = null;
			String register = null;
			if (page.startsWith(REGISTER)) {
				register = page.substring(REGISTER.length());
			} else {
				fixedPage = Integer.valueOf(
						com.widedot.m6809.gamebuilder.spi.configuration.Values.parseInt(page));
			}

			List<Machines.Slice> slices = slices(node, sources);
			if (size < pageSize && slices.isEmpty()) {
				throw new Exception(sources.locate(node) + ": window '" + name + "' shows $"
						+ Integer.toHexString(size) + " of a page of $"
						+ Integer.toHexString(pageSize)
						+ ": it must declare which slices of the page it can show");
			}
			if (size > pageSize) {
				throw new Exception(sources.locate(node) + ": window '" + name + "' is larger ($"
						+ Integer.toHexString(size) + ") than a page ($"
						+ Integer.toHexString(pageSize) + ")");
			}
			windows.add(new Machines.Window(name, address, size, fixedPage, register,
					optional(node, "or"), optional(node, "include"), slices));
		}
		for (int i = 0; i < windows.size(); i++) {
			for (int j = i + 1; j < windows.size(); j++) {
				Machines.Window a = windows.get(i);
				Machines.Window b = windows.get(j);
				if (a.address < b.end() && b.address < a.end()) {
					throw new Exception(sources.locate(machine) + ": windows '" + a.name
							+ "' and '" + b.name + "' overlap — a CPU address must name"
							+ " one window and one only");
				}
			}
		}
		return windows;
	}

	private static List<Machines.Slice> slices(ImmutableNode window, SourceMap sources)
			throws Exception {
		List<Machines.Slice> slices = new ArrayList<Machines.Slice>();
		for (ImmutableNode node : window.getChildren()) {
			if (!"slice".equals(node.getNodeName())) {
				continue;
			}
			slices.add(new Machines.Slice(NodeAttr.getInteger(node, sources, "index"),
					NodeAttr.getInteger(node, sources, "value")));
		}
		return slices;
	}

	private static String optional(ImmutableNode node, String name) {
		return (String) node.getAttributes().get(name);
	}

	public Machines.Machine get(String key) {
		return machines.get(key);
	}
}
