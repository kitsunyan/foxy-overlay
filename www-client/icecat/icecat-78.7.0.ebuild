# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

FIREFOX_PATCHSET="firefox-78esr-patches-07.tar.xz"

LLVM_MAX_SLOT=11

PYTHON_COMPAT=( python3_{7,8,9} )
PYTHON_REQ_USE="ncurses,sqlite,ssl"

WANT_AUTOCONF="2.1"

inherit autotools check-reqs llvm python-any-r1 desktop gnome2-utils xdg

PATCH_URIS=(
	https://dev.gentoo.org/~{axs,polynomial-c,whissi}/mozilla/patchsets/${FIREFOX_PATCHSET}
)

SRC_URI="${PATCH_URIS[@]}"

DESCRIPTION="GNU IceCat Web Browser"
HOMEPAGE="https://www.gnu.org/software/gnuzilla"

KEYWORDS="amd64 arm64 x86"
SLOT="0"
LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
IUSE="jack pulseaudio screencast dbus wayland gnu-extensions"

REQUIRED_USE="screencast? ( wayland )"

BDEPEND="${PYTHON_DEPS}
	app-arch/unzip
	app-arch/zip
	>=dev-util/cbindgen-0.14.3
	>=net-libs/nodejs-10.21.0
	virtual/pkgconfig
	>=virtual/rust-1.41.0
	|| (
		(
			sys-devel/clang:11
			sys-devel/llvm:11
		)
		(
			sys-devel/clang:10
			sys-devel/llvm:10
		)
		(
			sys-devel/clang:9
			sys-devel/llvm:9
		)
	)
	amd64? ( >=dev-lang/yasm-1.1 )
	x86? ( >=dev-lang/yasm-1.1 )"

CDEPEND="
	>=dev-libs/nss-3.53.1
	>=dev-libs/nspr-4.25
	dev-libs/atk
	dev-libs/expat
	>=x11-libs/gtk+-2.18:2
	>=x11-libs/gtk+-3.4.0:3=[X]
	>=media-libs/libpng-1.6.35:0=[apng]
	>=media-libs/mesa-10.2:*
	media-libs/fontconfig
	>=media-libs/freetype-2.4.10
	kernel_linux? ( !pulseaudio? ( media-libs/alsa-lib ) )
	virtual/freedesktop-icon-theme
	>=x11-libs/pixman-0.19.2
	>=dev-libs/libffi-3.0.10:=
	media-video/ffmpeg
	x11-libs/libXt
	dbus? (
		sys-apps/dbus
		dev-libs/dbus-glib
	)
	screencast? ( media-video/pipewire:0/0.3 )
	>=media-libs/dav1d-0.3.0:=
	>=media-libs/libaom-1.0.0:=
	>=media-libs/harfbuzz-2.6.8:0=
	>=media-gfx/graphite2-1.3.13
	>=dev-libs/icu-67.1
	>=media-libs/libjpeg-turbo-1.2.1
	>=dev-libs/libevent-2.0:0=[threads]
	>=media-libs/libvpx-1.8.2:0=[postproc]
	>=media-libs/libwebp-1.1.0:0=
	jack? ( virtual/jack )"

RDEPEND="${CDEPEND}
	pulseaudio? (
		|| (
			media-sound/pulseaudio
			>=media-sound/apulse-0.1.12-r4
		)
	)"

DEPEND="${CDEPEND}
	=www-client/icecat-sources-${PV}
	pulseaudio? (
		|| (
			media-sound/pulseaudio
			>=media-sound/apulse-0.1.12-r4[sdk]
		)
	)
	wayland? ( >=x11-libs/gtk+-3.11:3[wayland] )
	amd64? ( virtual/opengl )
	x86? ( virtual/opengl )"

moz_clear_vendor_checksums() {
	einfo "Clearing cargo checksums for ${1} ..."
	sed -i "${S}"/third_party/rust/${1}/.cargo-checksum.json \
	-e 's/\("files":{\)[^}]*/\1/' || die
}

pkg_pretend() {
	CHECKREQS_DISK_BUILD='6400M'
	check-reqs_pkg_pretend
}

pkg_setup() {
	CHECKREQS_DISK_BUILD='6400M'
	check-reqs_pkg_setup

	llvm_pkg_setup

	python-any-r1_pkg_setup

	# Ensure we use C locale when building, bug #746215
	export LC_ALL=C
}

src_unpack() {
	default
	tar -xf "/usr/src/${P}.tar.gz" || die
}

src_prepare() {
	eapply "${WORKDIR}/firefox-patches"
	eapply_user

	einfo "Removing pre-built binaries ..."
	find "${S}"/third_party -type f \( -name '*.so' -o -name '*.o' \) -print -delete || die

	# Clearing checksums where we have applied patches
	moz_clear_vendor_checksums target-lexicon-0.9.0

	xdg_src_prepare
}

src_configure() {
	(mc() { echo "ac_add_options $1"; }

	mc '--enable-application=browser'
	mc '--with-app-basename=icecat'
	mc '--with-app-name=icecat'
	mc '--disable-crashreporter'
	mc '--disable-updater'
	
	mc "--prefix=${EPREFIX}/usr"
	mc "--libdir=${EPREFIX}/usr/$(get_libdir)"
	mc "CC=${CHOST}-gcc"
	mc "CXX=${CHOST}-g++"
	mc "--with-libclang-path=$(llvm-config --libdir)"
	mc '--enable-linker=gold'
	mc '--enable-hardening'
	mc '--enable-optimize'
	mc '--enable-rust-simd'
	mc "--x-includes=${SYSROOT}${EPREFIX}/usr/include"
	mc "--x-libraries=${SYSROOT}${EPREFIX}/usr/$(get_libdir)"

	# Branding
	mc '--enable-official-branding'
	mc '--with-distribution-id=org.gnu'
	mc '--with-unsigned-addon-scopes=app,system'
	
	# System libraries
	mc '--with-system-zlib'
	mc '--with-system-av1'
	mc '--with-system-icu'
	mc '--with-system-harfbuzz'
	mc '--with-system-graphite2'
	mc '--with-system-jpeg'
	mc '--with-system-png'
	mc '--with-system-nspr'
	mc '--with-system-nss'
	mc '--with-system-libvpx'
	mc "--with-system-libevent=${SYSROOT}${EPREFIX}/usr"
	mc '--with-system-webp'
	mc '--enable-system-ffi'
	mc '--enable-system-pixman'
	
	if use jack; then
		mc '--enable-jack'
	else
		mc '--disable-jack'
	fi
	if use pulseaudio; then
		mc '--enable-pulseaudio'
		mc '--disable-alsa'
	else
		mc '--disable-pulseaudio'
		mc '--enable-alsa'
	fi
	if use screencast; then
		mc '--enable-pipewire'
	else
		mc '--disable-pipewire'
	fi
	if use dbus; then
		mc '--enable-dbus'
	else
		mc '--disable-dbus'
	fi
	if use wayland; then
		mc '--enable-default-toolkit=cairo-gtk3-wayland'
	else
		mc '--enable-default-toolkit=cairo-gtk3'
	fi

	mc '--disable-cargo-incremental'
	mc '--disable-install-strip'
	mc '--disable-strip'
	mc '--disable-debug-symbols'
	mc '--disable-tests'
	mc '--disable-eme'

	echo "mk_add_options XARGS=${EPREFIX}/usr/bin/xargs") \
	> .mozconfig
	./mach configure || die
}

src_compile() {
	PATH="${FILESDIR}:${PATH}" ICECATDIR="/usr/$(get_libdir)/${PN}" \
	./mach build || die
}

src_install() {
	local f s

	PATH="${FILESDIR}:${PATH}" DESTDIR="${D}" \
	./mach install || die

	local vendorjs="${D}/usr/$(get_libdir)/${PN}/browser/defaults/preferences/vendor.js"
	install -Dm644 /dev/stdin "$vendorjs" <<END
// Use system hunspell
pref("spellchecker.dictionary_path", "${EPREFIX}/usr/share/myspell");

// Use graphite
sticky_pref("gfx.font_rendering.graphite.enabled", true);

// Use LANG environment variable to choose locale
pref("intl.locale.requested", "");

// Disable default browser checking.
pref("browser.shell.checkDefaultBrowser", false);

// Opt all of us into e10s, instead of just 50%
pref("browser.tabs.remote.autostart", true);
END

	if ! use gnu-extensions; then
		for f in extensions/gnu/*; do
			rm -rfv "${D}/usr/$(get_libdir)/${PN}/browser/extensions/${f##*/}"*
		done
		rmdir -pv "${D}/usr/$(get_libdir)/${PN}/browser/extensions"
	fi

	install -m755 -d "${D}/usr/share/pixmaps"
	install -Dm644 "browser/branding/official/default48.png" "${D}/usr/share/pixmaps/icecat.png"

	for f in browser/branding/official/default*.png; do
		s="${f%.png}"
		s="${s#*/default}"
		newicon --size "${s}" "${f}" "${PN}.png"
	done

	newmenu "${FILESDIR}/${PN}.desktop" "${PN}.desktop"
}

pkg_preinst() {
	xdg_pkg_preinst
}

pkg_postinst() {
	xdg_pkg_postinst
}
