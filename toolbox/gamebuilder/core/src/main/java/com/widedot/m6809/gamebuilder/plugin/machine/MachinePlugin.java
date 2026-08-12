package com.widedot.m6809.gamebuilder.plugin.machine;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.globals.Machines;

import lombok.extern.slf4j.Slf4j;

/**
 * Picks the target machine out of the machine definitions, exactly the way
 * {@code <floppydisk model="…">} picks a media out of the storage geometry :
 * the file comes from a default the configuration declares, the name comes
 * from the element, and the decoding reports file:line like everything else.
 *
 * What it brings into the build is small on purpose — the RAM page count the
 * occupancy report draws, and the expression a generated table writes in
 * front of a page number. Both were hard-coded in the builder before ; both
 * belong to the machine.
 */
@Slf4j
public class MachinePlugin {

	public static void run(ImmutableNode node, BuildContext ctx) throws Exception {

		String name = Attribute.getString(node, ctx, "name");
		String definitions = Attribute.getString(node, ctx, "definitions");

		MachineDefs defs = new MachineDefs(ctx.path + definitions);
		Machines.Machine machine = defs.get(name);
		if (machine == null) {
			throw new Exception(ctx.sources.locate(node) + ": machine '" + name
					+ "' is not declared in " + definitions + " (it declares: "
					+ defs.machines.keySet() + ")");
		}

		ctx.machines.declare(machine);
		ctx.regions.setRamPages(machine.ramPages);
		log.debug("machine {} : {} RAM pages, page byte '{}'", name, machine.ramPages,
				machine.pageExpr);
	}
}
