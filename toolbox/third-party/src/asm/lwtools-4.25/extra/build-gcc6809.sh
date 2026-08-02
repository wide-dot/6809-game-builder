#!/bin/sh
#
# Build script for the m6809 GCC cross-compiler with newlib.
#
# This script will optionally download, then patch and build GCC and
# newlib for the m6809 target, using lwtools as the assembler/linker.
#
# Three GCC versions are supported (selectable via --gcc-version):
#   - 4.6.4:            the legacy lwtools toolchain.  Builds cc1; the
#                       backend ICEs partway through libgcc.
#   - 9.5.0:            first hop of the forward-port.  cc1 + libgcc +
#                       newlib all working; this is the installed default.
#   - 16.1.0 (default): second hop, with the cc0 -> MODE_CC migration.
#                       cc1 + libgcc + newlib all working.
#
# Usage:
#   ./build-gcc6809.sh [--gcc-version=4.6.4|9.5.0|16.1.0] [--fetch] \
#                      [--prefix=/usr/local/m6809] [--clean] [--reconfigure]
#
# Prerequisites:
#   - lwtools (lwasm, lwlink, lwar) built and in PATH or in ../lwasm etc.
#   - GNU make, gawk, bison, flex, makeinfo (texinfo)
#   - GMP, MPFR, MPC (fetched automatically via GCC's download_prerequisites)
#   - A working C compiler for the host (g++-15 from Homebrew when building
#     GCC 9.5.0 on arm64 Darwin — see notes below).
#
# This script is resumable: re-run it after installing missing prerequisites
# and it will pick up where the previous run left off. Use --clean to start
# over, or --reconfigure to just re-run GCC's configure step.

set -e

# --- Defaults ---
GCC_VERSION=16.1.0
NEWLIB_VERSION=4.6.0.20260123
NEWLIB_PATCH_LEVEL=1
PREFIX=/usr/local/m6809
FETCH=no
CLEAN=no
RECONFIGURE=no

# --- Parse arguments ---
for arg in "$@"; do
	case "$arg" in
		--gcc-version=*)
			GCC_VERSION="${arg#--gcc-version=}"
			;;
		--fetch)
			FETCH=yes
			;;
		--prefix=*)
			PREFIX="${arg#--prefix=}"
			;;
		--clean)
			CLEAN=yes
			;;
		--reconfigure)
			RECONFIGURE=yes
			;;
		--help|-h)
			echo "Usage: $0 [--gcc-version=VER] [--fetch] [--prefix=DIR] [--clean] [--reconfigure]"
			echo ""
			echo "  --gcc-version  GCC version to build (4.6.4, 9.5.0 or 16.1.0; default: 16.1.0)"
			echo "  --fetch        Download GCC and newlib source tarballs"
			echo "  --prefix       Installation prefix (default: /usr/local/m6809)"
			echo "  --clean        Remove build and unpacked source dirs before building"
			echo "  --reconfigure  Force re-running of GCC configure step"
			exit 0
			;;
		*)
			echo "Unknown option: $arg" >&2
			exit 1
			;;
	esac
done

# --- Version-specific knobs ---
case "${GCC_VERSION}" in
	4.6.4)
		GCC_PATCH_LEVEL=11
		GCC_TARBALL_EXT=tar.bz2
		TARGET_TRIPLE=m6809-unknown
		HOST_FIX_AARCH64_DARWIN=inline   # patched via shell, not in .patch
		HOST_FIX_16K_PAGES=yes
		HOST_CXX_OVERRIDE=
		HOST_USES_SYSTEM_ZLIB=no
		EXTRA_CONFIGURE=--enable-obsolete
		NEWLIB_TARGET_CFLAGS=          # 4.6 ICEs in libgcc before reaching newlib
		;;
	9.5.0)
		GCC_PATCH_LEVEL=1
		GCC_TARBALL_EXT=tar.xz
		TARGET_TRIPLE=m6809-unknown-none
		HOST_FIX_AARCH64_DARWIN=in_patch # gcc6809lw-9.5.0-1.patch carries it
		HOST_FIX_16K_PAGES=no            # GCC 9 already uses aligned(16384)
		HOST_CXX_OVERRIDE=g++-15         # libc++ <map> + safe-ctype clash on arm64 Darwin
		HOST_USES_SYSTEM_ZLIB=yes        # bundled zlib's fdopen macro vs macOS stdio.h
		EXTRA_CONFIGURE="--disable-libstdcxx --disable-multilib --disable-lto --disable-decimal-float --disable-libquadmath --with-system-zlib"
		# The plus_constant ICE that gcc6809lw-9.5.0-1.patch fixes used to
		# block libm/math/ef_fmod.c at -O2.  With the fix in place that
		# specific issue is gone, but two other (unrelated, real)
		# limitations still bite at higher optimisation:
		#   - -O2 inlines hash_bigkey.c:__big_split into a frame >32 KiB,
		#     which the 6809 backend correctly refuses (16-bit signed S
		#     offsets max out near 32640 bytes).
		#   - -Os tightens code layout enough that the m6809 backend
		#     picks the short 'bra' form for a branch that exceeds the
		#     +/-127-byte range, and lwasm rejects the assembly.
		# Both are tractable but out of scope for the toolchain bring-up.
		# -O0 sidesteps both and produces working libc.a / libm.a / libg.a.
		NEWLIB_TARGET_CFLAGS=-O0
		;;
	16.1.0)
		GCC_PATCH_LEVEL=1
		GCC_TARBALL_EXT=tar.xz
		TARGET_TRIPLE=m6809-unknown-none
		HOST_FIX_AARCH64_DARWIN=upstream # GCC 16 ships host-aarch64-darwin.cc itself
		HOST_FIX_16K_PAGES=no            # GCC 16 aligns pch correctly
		HOST_CXX_OVERRIDE=g++-15         # libc++ <map> + safe-ctype clash still present
		HOST_USES_SYSTEM_ZLIB=yes        # bundled zlib's fdopen vs macOS stdio.h still
		EXTRA_CONFIGURE="--disable-libstdcxx --disable-multilib --disable-lto --disable-decimal-float --disable-libquadmath --with-system-zlib"
		# Newlib stays at -O0 because the m6809 backend has many
		# pre-existing latent issues at -O1+: register-spill failures
		# (siprintf/sniprintf FILE-struct init), unbounded reload
		# loops, ICEs, and >32 KiB frames (hash_bigkey).  A `-k -O2`
		# rebuild surfaces 60+ ICEs and several stuck cc1 processes
		# across stdio, string, math, and search.  These are real
		# backend limits, not regressions, and fixing them properly
		# would be days of work without test coverage.
		# This session DID land three backend improvements that help
		# user code at -O2 even though newlib itself can't use them:
		#   - gcc6809lw-16.1.0-1.patch's cbranch length attrs fixed
		#     the lwasm "Byte overflow" failures.
		#   - TARGET_CONDITIONAL_REGISTER_USAGE is now wired (it was
		#     commented out and -msoft-reg-count=N was a silent no-op).
		#   - TARGET_SPILL_CLASS returns ALL_REGS as a CRIS-style
		#     fallback for LRA spill class exhaustion.
		#   - m6809_hard_regno_mode_ok restricts M-regs to QImode
		#     (HImode allocation into M-regs was a latent ICE source
		#     because *movhi_1 has no insn pattern moving HI in/out).
		# User code may pass `-msoft-reg-count=8 -O2` and the spill-
		# class fallback may help; newlib's pressure profile is just
		# more than the backend can tolerate today.
		NEWLIB_TARGET_CFLAGS=-O0
		;;
	*)
		echo "Error: unsupported --gcc-version=${GCC_VERSION} (try 4.6.4, 9.5.0 or 16.1.0)" >&2
		exit 1
		;;
esac

# --- Derived names ---
GCC_TARBALL=gcc-${GCC_VERSION}.${GCC_TARBALL_EXT}
GCC_URL=https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/${GCC_TARBALL}
GCC_SRCDIR=gcc-${GCC_VERSION}
GCC_PATCH=gcc6809lw-${GCC_VERSION}-${GCC_PATCH_LEVEL}.patch

NEWLIB_TARBALL=newlib-${NEWLIB_VERSION}.tar.gz
NEWLIB_URL=https://sourceware.org/pub/newlib/${NEWLIB_TARBALL}
NEWLIB_SRCDIR=newlib-${NEWLIB_VERSION}
NEWLIB_PATCH=newlib6809lw-$(echo ${NEWLIB_VERSION} | sed 's/\..*//')-${NEWLIB_PATCH_LEVEL}.patch

SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)
BUILDDIR=${SCRIPTDIR}/gcc-build-${GCC_VERSION}

# --- Optional clean ---
if [ "${CLEAN}" = "yes" ]; then
	echo "Cleaning previous build and unpacked sources..."
	rm -rf "${BUILDDIR}"
	rm -rf "${SCRIPTDIR}/${GCC_SRCDIR}"
	rm -rf "${SCRIPTDIR}/${NEWLIB_SRCDIR}"
fi

# --- Check prerequisites up front ---
missing=""
for tool in make gawk bison flex makeinfo patch tar curl; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		missing="${missing} ${tool}"
	fi
done
if [ -n "${HOST_CXX_OVERRIDE}" ] && ! command -v "${HOST_CXX_OVERRIDE}" >/dev/null 2>&1; then
	missing="${missing} ${HOST_CXX_OVERRIDE}"
fi
if [ -n "${missing}" ]; then
	echo "Error: missing required tools:${missing}" >&2
	echo "On macOS: brew install gawk bison flex texinfo gcc" >&2
	echo "On Debian/Ubuntu: apt install build-essential gawk bison flex texinfo" >&2
	exit 1
fi
export AWK=gawk

# --- Locate lwtools ---
LWTOOLSDIR=$(cd "${SCRIPTDIR}/.." && pwd)
LWASM=${LWTOOLSDIR}/lwasm/lwasm
LWLINK=${LWTOOLSDIR}/lwlink/lwlink
LWAR=${LWTOOLSDIR}/lwar/lwar

if [ ! -x "${LWASM}" ]; then
	# Try PATH
	if command -v lwasm >/dev/null 2>&1; then
		LWASM=$(command -v lwasm)
		LWLINK=$(command -v lwlink)
		LWAR=$(command -v lwar)
	else
		echo "Error: lwtools not found. Build lwtools first or add to PATH." >&2
		exit 1
	fi
fi

LWTOOLS_BINDIR=$(dirname "${LWASM}")
echo "Using lwtools from: ${LWTOOLS_BINDIR}"

# --- Fetch sources ---
cd "${SCRIPTDIR}"

if [ "${FETCH}" = "yes" ]; then
	if [ ! -f "${GCC_TARBALL}" ]; then
		echo "Downloading ${GCC_TARBALL}..."
		curl -L -o "${GCC_TARBALL}" "${GCC_URL}"
	fi
	if [ ! -f "${NEWLIB_TARBALL}" ]; then
		echo "Downloading ${NEWLIB_TARBALL}..."
		curl -L -o "${NEWLIB_TARBALL}" "${NEWLIB_URL}"
	fi
fi

# --- Verify sources exist ---
for f in "${GCC_TARBALL}" "${GCC_PATCH}" "${NEWLIB_TARBALL}" "${NEWLIB_PATCH}"; do
	if [ ! -f "$f" ]; then
		echo "Error: $f not found. Use --fetch to download, or place files in ${SCRIPTDIR}." >&2
		exit 1
	fi
done

# --- Unpack and patch GCC ---
# Dry-run patch first so a failure leaves the tree untouched and re-runnable.
if [ ! -d "${GCC_SRCDIR}" ]; then
	echo "Unpacking ${GCC_TARBALL}..."
	tar xf "${GCC_TARBALL}"
fi

if [ ! -f "${GCC_SRCDIR}/.patched-${GCC_PATCH_LEVEL}" ]; then
	echo "Applying ${GCC_PATCH}..."
	cd "${GCC_SRCDIR}"
	if ! patch -p1 --dry-run --silent < "../${GCC_PATCH}"; then
		echo "Error: ${GCC_PATCH} would not apply cleanly." >&2
		echo "Re-run with --clean to start from a fresh tree." >&2
		exit 1
	fi
	patch -p1 < "../${GCC_PATCH}"
	touch ".patched-${GCC_PATCH_LEVEL}"
	cd "${SCRIPTDIR}"
fi

# --- Host-specific patches (applied to the unpacked GCC tree) ---
# GCC 4.6.4 predates Apple Silicon and has no aarch64-darwin host_hooks,
# which causes cc1 to fail linking with "Undefined symbols: _host_hooks".
# Add a trivial host-hook file and wire it into config.host.  GCC 9.5.0
# carries the same fix in its .patch file, so this block is a no-op there.
if [ "${HOST_FIX_AARCH64_DARWIN}" = "inline" ] && \
   [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ] && \
   [ ! -f "${GCC_SRCDIR}/.aarch64-darwin-host-hooks" ]; then
	echo "Adding aarch64-darwin host_hooks to GCC source tree..."
	mkdir -p "${GCC_SRCDIR}/gcc/config/aarch64"
	cat > "${GCC_SRCDIR}/gcc/config/aarch64/host-aarch64-darwin.c" <<'EOF'
/* aarch64-darwin host-specific hook definitions. */
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "hosthooks.h"
#include "hosthooks-def.h"
#include "config/host-darwin.h"

const struct host_hooks host_hooks = HOST_HOOKS_INITIALIZER;
EOF
	cat > "${GCC_SRCDIR}/gcc/config/aarch64/x-darwin" <<'EOF'
host-aarch64-darwin.o : $(srcdir)/config/aarch64/host-aarch64-darwin.c \
  $(CONFIG_H) $(SYSTEM_H) coretypes.h hosthooks.h $(HOSTHOOKS_DEF_H) \
  config/host-darwin.h
	$(COMPILER) -c $(ALL_COMPILERFLAGS) $(ALL_CPPFLAGS) $(INCLUDES) $<
EOF
	# Insert aarch64-darwin case into config.host, right after the i386/x86_64 darwin block.
	if ! grep -q "aarch64-\*-darwin" "${GCC_SRCDIR}/gcc/config.host"; then
		awk '
		/i\[34567\]86-\*-darwin\* \| x86_64-\*-darwin\*\)/ { in_block = 1 }
		{ print }
		in_block && /^    ;;/ {
			print "  aarch64-*-darwin* | arm64-*-darwin* | arm-*-darwin*)"
			print "    out_host_hook_obj=\"${out_host_hook_obj} host-aarch64-darwin.o\""
			print "    host_xmake_file=\"${host_xmake_file} aarch64/x-darwin\""
			print "    ;;"
			in_block = 0
		}
		' "${GCC_SRCDIR}/gcc/config.host" > "${GCC_SRCDIR}/gcc/config.host.new"
		mv "${GCC_SRCDIR}/gcc/config.host.new" "${GCC_SRCDIR}/gcc/config.host"
	fi
	touch "${GCC_SRCDIR}/.aarch64-darwin-host-hooks"
	# Force reconfigure so the new config.host entry takes effect.
	RECONFIGURE=yes
fi

# Apple Silicon uses 16 KiB pages; GCC 4.6.4's host-darwin.c aligns
# pch_address_space to 4 KiB, tripping an assertion in cc1.  GCC 9.5.0
# already aligns to 16 KiB so this only applies to the older build.
if [ "${HOST_FIX_16K_PAGES}" = "yes" ] && \
   [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ] && \
   [ ! -f "${GCC_SRCDIR}/.16k-page-alignment" ]; then
	echo "Bumping pch_address_space alignment to 16 KiB for Apple Silicon..."
	sed -i.bak 's/__attribute__((aligned (4096)))/__attribute__((aligned (16384)))/' \
		"${GCC_SRCDIR}/gcc/config/host-darwin.c"
	rm -f "${GCC_SRCDIR}/gcc/config/host-darwin.c.bak"
	touch "${GCC_SRCDIR}/.16k-page-alignment"
fi

# --- Locate GCC prerequisites (GMP, MPFR, MPC) ---
# Prefer system/Homebrew-installed copies; fall back to GCC's download_prerequisites.
GMP_PREFIX=""
MPFR_PREFIX=""
MPC_PREFIX=""
if command -v brew >/dev/null 2>&1; then
	GMP_PREFIX=$(brew --prefix gmp 2>/dev/null || true)
	MPFR_PREFIX=$(brew --prefix mpfr 2>/dev/null || true)
	MPC_PREFIX=$(brew --prefix libmpc 2>/dev/null || true)
fi

if [ -n "${GMP_PREFIX}" ] && [ -n "${MPFR_PREFIX}" ] && [ -n "${MPC_PREFIX}" ] && \
   [ -d "${GMP_PREFIX}" ] && [ -d "${MPFR_PREFIX}" ] && [ -d "${MPC_PREFIX}" ]; then
	echo "Using Homebrew GMP/MPFR/MPC:"
	echo "  GMP:  ${GMP_PREFIX}"
	echo "  MPFR: ${MPFR_PREFIX}"
	echo "  MPC:  ${MPC_PREFIX}"
elif [ ! -d "${GCC_SRCDIR}/gmp" ] || [ ! -d "${GCC_SRCDIR}/mpfr" ] || [ ! -d "${GCC_SRCDIR}/mpc" ]; then
	echo "GMP/MPFR/MPC not found via Homebrew; fetching into GCC source tree..."
	if ! command -v wget >/dev/null 2>&1; then
		echo "Error: contrib/download_prerequisites requires wget, which is not installed." >&2
		echo "Either:" >&2
		echo "  brew install gmp mpfr libmpc   (preferred on macOS)" >&2
		echo "  brew install wget              (to use GCC's bundled download)" >&2
		exit 1
	fi
	cd "${GCC_SRCDIR}"
	./contrib/download_prerequisites
	cd "${SCRIPTDIR}"
fi

# --- Unpack and patch newlib ---
if [ ! -d "${NEWLIB_SRCDIR}" ]; then
	echo "Unpacking ${NEWLIB_TARBALL}..."
	tar xzf "${NEWLIB_TARBALL}"
fi

if [ ! -f "${NEWLIB_SRCDIR}/.patched-${NEWLIB_PATCH_LEVEL}" ]; then
	echo "Applying ${NEWLIB_PATCH}..."
	cd "${NEWLIB_SRCDIR}"
	if ! patch -p1 --dry-run --silent < "../${NEWLIB_PATCH}"; then
		echo "Error: ${NEWLIB_PATCH} would not apply cleanly." >&2
		echo "Re-run with --clean to start from a fresh tree." >&2
		exit 1
	fi
	patch -p1 < "../${NEWLIB_PATCH}"
	touch ".patched-${NEWLIB_PATCH_LEVEL}"
	cd "${SCRIPTDIR}"
fi

# Teach newlib's top-level config.sub about m6809.  Newlib's configure
# resolves config.sub via the real source path (not through the GCC
# tree symlink), so GCC's already-patched config.sub doesn't apply here.
# Insert m6809 into the basic_machine list, idempotently.
if ! grep -q '^[[:space:]]*| m6809 |' "${NEWLIB_SRCDIR}/config.sub"; then
	echo "Teaching newlib's config.sub about m6809..."
	sed -i.bak 's/| m6811 | m68hc11 | m6812 | m68hc12/| m6809 | m6811 | m68hc11 | m6812 | m68hc12/' \
		"${NEWLIB_SRCDIR}/config.sub"
	rm -f "${NEWLIB_SRCDIR}/config.sub.bak"
fi

# --- Symlink newlib into GCC tree ---
cd "${GCC_SRCDIR}"
[ -L newlib ] || ln -sf "../${NEWLIB_SRCDIR}/newlib" newlib
[ -L libgloss ] || ln -sf "../${NEWLIB_SRCDIR}/libgloss" libgloss
cd "${SCRIPTDIR}"

# --- Install toolchain wrapper scripts ---
echo "Installing toolchain scripts to ${PREFIX}/bin..."
mkdir -p "${PREFIX}/bin"
cp "${SCRIPTDIR}/as" "${PREFIX}/bin/${TARGET_TRIPLE}-as"
cp "${SCRIPTDIR}/ld" "${PREFIX}/bin/${TARGET_TRIPLE}-ld"
cp "${SCRIPTDIR}/ar" "${PREFIX}/bin/${TARGET_TRIPLE}-ar"
chmod +x "${PREFIX}/bin/${TARGET_TRIPLE}-as" \
         "${PREFIX}/bin/${TARGET_TRIPLE}-ld" \
         "${PREFIX}/bin/${TARGET_TRIPLE}-ar"

# lwar archives carry their own symbol index; ranlib is a no-op.
# nm/objdump/strip aren't meaningful for lwasm objects either.
for tool in nm objdump ranlib strip; do
	ln -sf /usr/bin/true "${PREFIX}/bin/${TARGET_TRIPLE}-${tool}"
done

# --- Configure ---
export PATH="${PREFIX}/bin:${LWTOOLS_BINDIR}:${PATH}"
if [ -n "${HOST_CXX_OVERRIDE}" ]; then
	export CC=$(echo "${HOST_CXX_OVERRIDE}" | sed 's/g++/gcc/')
	export CXX="${HOST_CXX_OVERRIDE}"
fi

mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

if [ "${RECONFIGURE}" = "yes" ]; then
	echo "Forcing re-configure: removing existing build files..."
	rm -f Makefile config.status
fi

if [ ! -f Makefile ]; then
	echo "Configuring GCC..."
	CONFIGURE_EXTRA=""
	if [ -n "${GMP_PREFIX}" ] && [ -d "${GMP_PREFIX}" ]; then
		CONFIGURE_EXTRA="${CONFIGURE_EXTRA} --with-gmp=${GMP_PREFIX}"
	fi
	if [ -n "${MPFR_PREFIX}" ] && [ -d "${MPFR_PREFIX}" ]; then
		CONFIGURE_EXTRA="${CONFIGURE_EXTRA} --with-mpfr=${MPFR_PREFIX}"
	fi
	if [ -n "${MPC_PREFIX}" ] && [ -d "${MPC_PREFIX}" ]; then
		CONFIGURE_EXTRA="${CONFIGURE_EXTRA} --with-mpc=${MPC_PREFIX}"
	fi
	"../${GCC_SRCDIR}/configure" \
		--enable-languages=c \
		--target=${TARGET_TRIPLE} \
		--program-prefix=${TARGET_TRIPLE}- \
		--srcdir="../${GCC_SRCDIR}" \
		--disable-threads \
		--disable-nls \
		--disable-libssp \
		--with-newlib \
		--prefix="${PREFIX}" \
		--with-as="${PREFIX}/bin/${TARGET_TRIPLE}-as" \
		--with-ld="${PREFIX}/bin/${TARGET_TRIPLE}-ld" \
		--with-ar="${PREFIX}/bin/${TARGET_TRIPLE}-ar" \
		${EXTRA_CONFIGURE} \
		${CONFIGURE_EXTRA}
fi

# --- Build ---
echo "Building GCC..."
make all-gcc

echo "Building libgcc..."
make all-target-libgcc

echo "Building newlib..."
if [ -n "${NEWLIB_TARGET_CFLAGS}" ]; then
	make all-target-newlib CFLAGS_FOR_TARGET="${NEWLIB_TARGET_CFLAGS}"
else
	make all-target-newlib
fi

# --- Install ---
echo "Installing GCC and libgcc to ${PREFIX}..."
make install-gcc install-target-libgcc

echo "Installing newlib libraries and headers to ${PREFIX}..."
mkdir -p "${PREFIX}/${TARGET_TRIPLE}/lib" "${PREFIX}/${TARGET_TRIPLE}/include"

NEWLIB_BUILDDIR="${BUILDDIR}/${TARGET_TRIPLE}/newlib"
for lib in libc.a libm.a libg.a; do
	if [ -f "${NEWLIB_BUILDDIR}/${lib}" ]; then
		cp "${NEWLIB_BUILDDIR}/${lib}" "${PREFIX}/${TARGET_TRIPLE}/lib/"
	fi
done

cp -r "${NEWLIB_BUILDDIR}/targ-include"/* "${PREFIX}/${TARGET_TRIPLE}/include/"
cp -r "${SCRIPTDIR}/${GCC_SRCDIR}/newlib/libc/include"/* "${PREFIX}/${TARGET_TRIPLE}/include/"

echo ""
echo "Build complete. Installed to ${PREFIX}"
echo "Ensure lwtools and ${PREFIX}/bin are in your PATH to use the toolchain."
