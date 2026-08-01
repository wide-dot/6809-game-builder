package com.widedot.m6809.gamebuilder.plugin.animation;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;
import org.apache.commons.io.FileUtils;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the &lt;animation&gt; element : the table AnimateSprite walks.
 *
 * The layout is v1's, which its builder generated from the project properties
 * — a frame duration, then one imageset address per frame, then an end marker.
 * The duration sits *before* the label because the runtime reads it at -1,x.
 *
 * Frames name images, not symbols : the element writes {@code set_<image>},
 * the symbol the imageset index exports, so a game mode never spells out the
 * generated naming.
 */
@Slf4j
public class AnimationPlugin {

	/**
	 * End markers of constants-animation.equ. The value is written out rather
	 * than the symbol: the table has to assemble in whatever unit it lands in,
	 * and that unit has no reason to carry the engine's equates.
	 */
	private static final Map<String, String> ENDINGS = new LinkedHashMap<>();
	static {
		ENDINGS.put("reset", "$FF");               // _resetAnim, start over
		ENDINGS.put("goback", "$FE");              // _goBackNFrames, + frames
		ENDINGS.put("goto", "$FD");                // _goToAnimation, + animation
		ENDINGS.put("nextroutine", "$FC");         // _nextRoutine, hand over to the object
		ENDINGS.put("resetandsubroutine", "$FB");  // _resetAnimAndSubRoutine
		ENDINGS.put("nextsubroutine", "$FA");      // _nextSubRoutine
	}

	public static File getFile(ImmutableNode node, BuildContext ctx) throws Exception {

		String name = Attribute.getString(node, ctx, "name");
		Integer duration = Attribute.getInteger(node, ctx, "duration", 1);
		String end = Attribute.getString(node, ctx, "end", "reset");
		Integer frames = Attribute.getIntegerOpt(node, ctx, "frames");
		String target = Attribute.getStringOpt(node, ctx, "animation");

		if (!ENDINGS.containsKey(end)) {
			throw new Exception("animation " + name + " : end '" + end + "' is not one of "
			                    + ENDINGS.keySet());
		}
		if (duration < 0 || duration > 255) {
			throw new Exception("animation " + name + " : duration " + duration
			                    + " does not fit in a byte");
		}

		StringBuilder body = new StringBuilder();
		int count = 0;
		for (ImmutableNode child : node.getChildren()) {
			if (!"frame".equals(child.getNodeName())) {
				throw new Exception("Element <" + child.getNodeName() + "> is not valid inside <animation>");
			}
			body.append("        fdb   set_").append(Attribute.getString(child, ctx, "image"))
			    .append(System.lineSeparator());
			count++;
		}
		if (count == 0) {
			throw new Exception("animation " + name + " has no <frame>");
		}

		// the marker, then whatever operand it takes, then the comment — an
		// operand appended after the comment would be swallowed by it
		StringBuilder tail = new StringBuilder("        fcb   ").append(ENDINGS.get(end));
		String follows = "";
		if ("goback".equals(end)) {
			if (frames == null) {
				throw new Exception("animation " + name + " : end 'goback' also needs frames");
			}
			tail.append(",").append(frames);
		} else if ("goto".equals(end)) {
			if (target == null) {
				throw new Exception("animation " + name + " : end 'goto' also needs animation");
			}
			follows = "        fdb   " + target + System.lineSeparator();
		}
		tail.append("        ; ").append(end).append(System.lineSeparator()).append(follows);

		String content = "* Generated animation" + System.lineSeparator()
		               + name + " EXPORT" + System.lineSeparator()
		               + " SECTION code" + System.lineSeparator()
		               + "        fcb   " + duration + "     ; frames each image is held, read at -1,x"
		               + System.lineSeparator()
		               + name + System.lineSeparator()
		               + body
		               + tail
		               + " ENDSECTION" + System.lineSeparator();

		String filename = ctx.path + File.separator + ctx.settings.get("generate.unnamedFiles.dir")
		                + File.separator + name + ".anim.asm";
		File file = new File(filename);
		FileUtils.write(file, content, StandardCharsets.UTF_8, false);

		log.debug("animation {} : {} frames, ends on {}", name, count, end);
		return file;
	}
}
