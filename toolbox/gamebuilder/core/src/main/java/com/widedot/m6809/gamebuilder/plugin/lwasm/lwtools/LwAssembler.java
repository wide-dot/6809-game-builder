package com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools;

import java.io.File;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;
import com.widedot.m6809.gamebuilder.spi.globals.LinkSymbols;
import java.io.IOException;
import java.lang.reflect.Constructor;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map.Entry;

import org.apache.commons.io.FileUtils;

import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.util.Constants;
import com.widedot.m6809.util.ThirdPartyTools;
import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class LwAssembler
{

	/**
	 * Bump when the way lwasm is driven changes (flags, formats) : the cache
	 * below replays the outputs of a previous run.
	 */
	private static final String CACHE_VERSION = "1";

	// format types
	public static final String OBJ  = "obj";
	public static final String DECB = "decb";
	public static final String OS9  = "os9";
	public static final String RAW  = "raw";
	public static final String HEX  = "hex";
	public static final String SREC = "srec";
	public static final String IHEX = "ihex";
	
	// auxiliary output types
	public static final String LST = "lst";
	public static final String LWMAP = "lwmap";
	
	public static final HashMap<String, String> formatClass = new HashMap<String, String>() {
		private static final long serialVersionUID = 1L;
		{
			put(OBJ,  "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwObject");
			put(DECB, "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
			put(OS9,  "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
			put(RAW,  "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
			put(HEX,  "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
			put(SREC, "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
			put(IHEX, "com.widedot.m6809.gamebuilder.plugin.lwasm.lwtools.format.LwRaw");
		}
	};
	
	public static ObjectDataInterface assemble(String asmFile, String rootPath, BuildContext ctx, String format, String processor) throws Exception {
		
		Path path = Paths.get(asmFile).toAbsolutePath().normalize();
		String buildDir = FileUtil.getDir(asmFile) + File.separator +ctx.settings.get("build.dir") + File.separator;
		String asmBasename = FileUtil.removeExtension(FileUtil.getBasename(asmFile));
		String binFilename = buildDir + asmBasename + "." + format;
		String lstFilename = buildDir + asmBasename + "." + LST;
		String mapFilename = buildDir + asmBasename + "." + LWMAP;

		Files.createDirectories(Paths.get(buildDir));

		List.of(binFilename, lstFilename, mapFilename)
		    .stream()
			.map(File::new)
			.forEach(File::delete);

		
		File del = new File (binFilename);
		del.delete();
		del = new File (lstFilename);
		del.delete();
		del = new File (mapFilename);
		del.delete();
	
		String lwasm = ThirdPartyTools.resolve("lwasm");
		List<String> command = new ArrayList<String>(List.of(lwasm,
				   path.toString(),
				   "--" + processor,
				   "--format=" + format,
				   "--output=" + binFilename,
				   "--list="   + lstFilename,
				   "--includedir=" + rootPath,
				   "--includedir=" + path.getParent().toString(),
				   "--map=" + mapFilename
				   ));
		
		for (Entry<String, String> define : ctx.defines.values.entrySet()) {
			String val = define.getValue();
			if (val.startsWith("$")) {
				command.add("--define="+define.getKey()+"="+Integer.parseInt(val.substring(1),16));
			} else {
				command.add("--define="+define.getKey()+"="+define.getValue());
			}
		}

		log.debug("{}", command);

		// An assembly is a pure function of the source tree and the command
		// line : same sources, same includes, same defines, same outputs. It
		// is also the dominant cost of a warm build — measured on r-type at
		// 204 spawns for 19.7 s of a 23 s build, every one of them repeated
		// between the discovery pass and the real pass, and again at the next
		// run of a working session. Finished outputs (bin, lst, lwmap) are
		// kept under the hash of everything the assembly can see.
		Path cache = cacheDir(path, rootPath, command);
		if (cache != null && Files.isDirectory(cache)) {
			Files.copy(cache.resolve("out." + format), Paths.get(binFilename));
			Files.copy(cache.resolve("out." + LST), Paths.get(lstFilename));
			Files.copy(cache.resolve("out." + LWMAP), Paths.get(mapFilename));
			log.debug("lwasm cache hit for {}", asmBasename);
		} else {
			Process p;
			try {
				p = new ProcessBuilder(command).inheritIO().start();
			} catch (IOException e) {
				throw new Exception(lwasm + " could not be run. The assembler ships with the"
						+ " build under toolbox/third-party/bin/<os>/ ; pass -Dbasedir=<repository root>"
						+ " so it can be found, put it on the PATH, or point at it with"
						+ " -Dlwasm.path=/full/path (or the LWASM environment variable).", e);
			}
			int result = p.waitFor();
			if (result != 0) {
				throw new Exception("Build Aborted !");			
			}
			if (cache != null) {
				storeToCache(cache, binFilename, lstFilename, mapFilename, format);
			}
		}
        
        Class<?> clazz = Class.forName(formatClass.get(format));
        Constructor<?> ctor = clazz.getConstructor(String.class, LinkSymbols.class);
        ObjectDataInterface object = (ObjectDataInterface) ctor.newInstance(new Object[] { binFilename, ctx.linkSymbols });
        
        // export builder ctx.defines
        String defineKey = Constants.BUILDER_DEFINE_PREFIX + "lwasm.size." + asmBasename;
        String binLength = Integer.toString(object.getBytes().length);
        
        if (ctx.defines.values.containsKey(defineKey)) {
        	log.warn("Duplicate filename: <" + asmBasename + ">. Builder will overwrite the define: <" + defineKey + ">. Use gensource attribute on lwasm element to set an alias");
        }

        ctx.defines.newValues.put(defineKey, binLength);
        log.debug("generate define : {} {}", defineKey,  binLength);
        
        // add a file tag in the build directory
        File tag = new File(buildDir+ctx.settings.get("build.dir.tag"));
        tag.createNewFile();
        
		return object;
	}
	
	public static void clean(String path, Settings settings) throws IOException {
		log.info("Clean build directories ...");
	    deleteDirectoryRecursion(Paths.get(path), settings.get("build.dir"), settings.get("build.dir.tag"));
	    log.info("Clean ended.");
	}
	
	public static void deleteDirectoryRecursion(Path path, String buildDirName, String buildDirTag) throws IOException {
		if (Files.isDirectory(path, LinkOption.NOFOLLOW_LINKS)) {
			
			// only delete the directory that ends with the expected name
			if (path.getFileName().toString().equals(buildDirName)) {
				
				// to ensure that the directory is a one created by the builder, a file tag is controlled
				File tag = new File(path.toString()+File.separator+buildDirTag);
				if (tag.isFile()) {
					log.debug("delete: {}", path.toString());
					FileUtils.deleteDirectory(path.toFile());
				} else {
					log.warn("cancel deletion of: {} - tag: {} not found", path.toString(), tag.toString());
				}
				
			} else {
				try (DirectoryStream<Path> entries = Files.newDirectoryStream(path)) {
					for (Path entry : entries) {
						deleteDirectoryRecursion(entry, buildDirName, buildDirTag);
					}
				}
			}
		}
	}

	/**
	 * The cache key covers everything the assembly can see : the source, every
	 * file reachable through its INCLUDE / includebin lines (resolved the way
	 * lwasm resolves them : against the including file's directory, then the
	 * include dirs), and the full command line (defines, format, processor).
	 * An include that cannot be resolved is keyed as missing — if it was
	 * conditional the content hash is over-approximated, never wrong.
	 */
	private static Path cacheDir(Path source, String rootPath, List<String> command)
			throws Exception {
		String basedir = System.getProperty("basedir");
		if (basedir == null) {
			return null;
		}
		java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
		java.nio.charset.Charset utf8 = java.nio.charset.StandardCharsets.UTF_8;
		md.update((CACHE_VERSION + "|").getBytes(utf8));
		// the command line minus the absolute output paths : those change with
		// the build dir without changing what is produced
		for (String arg : command) {
			if (arg.startsWith("--output=") || arg.startsWith("--list=") || arg.startsWith("--map=")) {
				continue;
			}
			md.update(arg.getBytes(utf8));
			md.update((byte) 0);
		}
		java.util.Set<Path> seen = new java.util.LinkedHashSet<Path>();
		hashSourceTree(source, Paths.get(rootPath), md, seen);
		StringBuilder hex = new StringBuilder();
		for (byte b : md.digest()) {
			hex.append(String.format("%02x", b));
		}
		return Paths.get(basedir, ".lwasm-cache", hex.toString());
	}

	private static final java.util.regex.Pattern INCLUDE_LINE = java.util.regex.Pattern.compile(
			"^\\s*(?:include|includebin|use)\\s+\"?([^\"\\s]+)\"?.*",
			java.util.regex.Pattern.CASE_INSENSITIVE);

	private static void hashSourceTree(Path file, Path includeDir,
			java.security.MessageDigest md, java.util.Set<Path> seen) throws Exception {
		Path normalized = file.toAbsolutePath().normalize();
		if (!seen.add(normalized)) {
			return;
		}
		byte[] content = Files.readAllBytes(normalized);
		md.update(content);
		md.update((byte) 0);
		for (String line : new String(content, java.nio.charset.StandardCharsets.ISO_8859_1)
				.split("\\r?\\n")) {
			java.util.regex.Matcher m = INCLUDE_LINE.matcher(line);
			if (!m.matches()) {
				continue;
			}
			String ref = m.group(1);
			Path resolved = null;
			for (Path base : new Path[] { normalized.getParent(), includeDir }) {
				Path candidate = base.resolve(ref).normalize();
				if (Files.isRegularFile(candidate)) {
					resolved = candidate;
					break;
				}
			}
			if (resolved == null) {
				// conditional or truly missing : key its absence, do not guess
				md.update(("missing:" + ref).getBytes(java.nio.charset.StandardCharsets.UTF_8));
				md.update((byte) 0);
				continue;
			}
			hashSourceTree(resolved, includeDir, md, seen);
		}
	}

	private static void storeToCache(Path cache, String binFilename, String lstFilename,
			String mapFilename, String format) throws Exception {
		Path tmp = cache.resolveSibling(cache.getFileName() + ".tmp-" + Thread.currentThread().getId());
		Files.createDirectories(tmp);
		Files.copy(Paths.get(binFilename), tmp.resolve("out." + format));
		Files.copy(Paths.get(lstFilename), tmp.resolve("out." + LST));
		Files.copy(Paths.get(mapFilename), tmp.resolve("out." + LWMAP));
		try {
			Files.move(tmp, cache, java.nio.file.StandardCopyOption.ATOMIC_MOVE);
		} catch (java.nio.file.FileAlreadyExistsException | java.nio.file.AccessDeniedException race) {
			try (java.util.stream.Stream<Path> entries = Files.list(tmp)) {
				for (Path f : (Iterable<Path>) entries::iterator) {
					Files.deleteIfExists(f);
				}
			}
			Files.deleteIfExists(tmp);
		}
	}
}
