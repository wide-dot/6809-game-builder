import java.nio.file.Files;
import java.nio.file.Paths;

import fr.bento8.to8.build.BuildDisk;
import fr.bento8.to8.build.Game;
import fr.bento8.to8.compiledSprite.backupDrawErase.AssemblyGenerator;
import fr.bento8.to8.compiledSprite.draw.SimpleAssemblyGenerator;
import fr.bento8.to8.image.Sprite;
import fr.bento8.to8.image.SpriteSheet;

/**
 * Drives the v1 sprite encoders on a single PNG, outside of a game project.
 *
 * BuildDisk normally reaches the encoders through a full disk build, so the few
 * globals it would have set (lwasm path, pragma, include dirs, output dir) are
 * set here from the r-type configuration values. Everything else is the v1 code
 * path untouched: same SpriteSheet, same generator, same lwasm invocation.
 *
 * usage: V1Harness <png> <name> <variant> <outDir> <lwasm> [maxTries]
 */
public class V1Harness {

	public static void main(String[] args) throws Exception {
		String png = args[0], name = args[1], variant = args[2], outDir = args[3], lwasm = args[4];
		int maxTries = args.length > 5 ? Integer.parseInt(args[5]) : 500000;

		Files.createDirectories(Paths.get(outDir, "debug"));

		BuildDisk.game = new Game();
		BuildDisk.game.lwasm = lwasm;
		BuildDisk.game.useCache = false;
		// Same search budget as gfxcomp hardcodes, and as r-type configures.
		// Raising it does not buy determinism : the exhaustive/random decision
		// compares the node's group count against a threshold derived from a
		// factorial table that stops at 9!, so once maxTries reaches 362880 the
		// threshold saturates and any node of 10 groups or more still takes the
		// random branch. Measured on shell_3 : 542 vs 544 bytes at 500000, and
		// 542 vs 541 at 100000000.
		BuildDisk.game.maxTries = maxTries;
		Game.generatedCodeDirName = outDir + "/";
		Game.generatedCodeDirNameDebug = outDir + "/debug/";
		Game.pragma = "--pragma=undefextern";
		Game.includeDirs = new String[] { "--includedir=.", "--includedir=../.." };
		Game.defineList = new String[0];

		Sprite sprite = new Sprite(name);
		sprite.spriteFile = png;

		SpriteSheet ss = new SpriteSheet(sprite, null, null, 1, 1, 1, variant, true, SpriteSheet.CENTER);

		if (variant.contains("B")) {
			AssemblyGenerator asm = new AssemblyGenerator(ss, outDir, 0);
			asm.compileCode("A000");
			System.out.println("x1=" + asm.getX1_offset() + " y1=" + asm.getY1_offset()
			                 + " xs=" + asm.getX_size() + " ys=" + asm.getY_size()
			                 + " center=" + ss.center_offset
			                 + " eraseData=" + asm.getEraseDataSize());
		} else {
			SimpleAssemblyGenerator asm = new SimpleAssemblyGenerator(ss, outDir, 0,
			                                  SimpleAssemblyGenerator._NO_ALPHA);
			asm.compileCode("A000");
			System.out.println("x1=" + asm.getX1_offset() + " y1=" + asm.getY1_offset()
			                 + " xs=" + asm.getX_size() + " ys=" + asm.getY_size()
			                 + " center=" + ss.center_offset);
		}
	}
}
