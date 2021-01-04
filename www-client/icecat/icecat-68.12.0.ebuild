# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{7,8,9} )
PYTHON_REQ_USE='ncurses,sqlite,ssl,threads(+)'
LLVM_MAX_SLOT=11

inherit check-reqs llvm python-any-r1 desktop gnome2-utils xdg-utils

DESCRIPTION="GNU IceCat Web Browser"
HOMEPAGE="https://www.gnu.org/software/gnuzilla"

KEYWORDS="amd64 arm64 x86"
SLOT="0"
LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
IUSE="jack pulseaudio dbus startup-notification gnu-extensions"

CDEPEND="
	jack? ( virtual/jack )
	pulseaudio? (
		|| (
			media-sound/pulseaudio
			>=media-sound/apulse-0.1.9
		)
	)
	>=dev-libs/nss-3.44.4
	>=dev-libs/nspr-4.21
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
	dbus? (
		>=sys-apps/dbus-0.60
		>=dev-libs/dbus-glib-0.72
	)
	startup-notification? ( >=x11-libs/startup-notification-0.8 )
	>=x11-libs/pixman-0.19.2
	>=dev-libs/libffi-3.0.10:=
	media-video/ffmpeg
	x11-libs/libXt
	>=media-libs/dav1d-0.3.0:=
	>=media-libs/libaom-1.0.0:=
	>=media-libs/harfbuzz-2.4.0:0=
	>=media-gfx/graphite2-1.3.13
	>=dev-libs/icu-63.1
	>=media-libs/libjpeg-turbo-1.2.1
	>=dev-libs/libevent-2.0:0=[threads]
	>=dev-db/sqlite-3.28.0:3[secure-delete]
	>=media-libs/libvpx-1.8:0=[postproc]"

DEPEND="${CDEPEND}
	=www-client/icecat-sources-${PV}
	dev-lang/python:2.7[ncurses,sqlite,ssl,threads(+)]
	${PYTHON_DEPS}
	app-arch/zip
	app-arch/unzip
	>=dev-util/cbindgen-0.8.7
	>=net-libs/nodejs-8.11.0
	>=sys-devel/binutils-2.30
	sys-apps/findutils
	virtual/pkgconfig
	>=virtual/rust-1.34
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
	pulseaudio? ( media-sound/pulseaudio )
	amd64? (
		>=dev-lang/yasm-1.1
		virtual/opengl
	)
	x86? (
		>=dev-lang/yasm-1.1
		virtual/opengl
	)"

RDEPEND="${CDEPEND}"

pkg_pretend() {
	CHECKREQS_DISK_BUILD='4G'
	check-reqs_pkg_pretend
}

pkg_setup() {
	CHECKREQS_DISK_BUILD='4G'
	check-reqs_pkg_setup

	llvm_pkg_setup

	python-any-r1_pkg_setup
	# workaround to set python3 into PYTHON3 until mozilla doesn't need py2
	if [[ "${PYTHON_COMPAT[@]}" != "${PYTHON_COMPAT[@]#python3*}" ]]; then
		export PYTHON3=${PYTHON}
		python_export python2_7 PYTHON EPYTHON
	fi
}

src_unpack() {
	tar -xf "/usr/src/${P}.tar.bz2" || die
}

src_prepare() {
	sed -i config/baseconfig.mk \
	-e 's;$(libdir)/$(MOZ_APP_NAME)-$(MOZ_APP_VERSION);$(libdir)/$(MOZ_APP_NAME);g'
	sed -i config/baseconfig.mk \
	-e 's;$(libdir)/$(MOZ_APP_NAME)-devel-$(MOZ_APP_VERSION);$(libdir)/$(MOZ_APP_NAME)-devel;g'

	# recreate python environment
	rm -rf obj-*

	eapply \
	"${FILESDIR}/2000_system_harfbuzz_support.patch" \
	"${FILESDIR}/2001_system_graphite2_support.patch" \
	"${FILESDIR}/7002_system_av1_support.patch" \
	"${FILESDIR}/7003_system_libvpx.patch" \
	"${FILESDIR}/rust-lto.patch" || die

	eapply_user
}

src_configure() {
	(mc() { echo "ac_add_options $1"; }

	mc '--enable-application=browser'
	mc '--with-app-basename=icecat'
	mc '--with-app-name=icecat'
	
	mc "--prefix=${EPREFIX}/usr"
	mc "--libdir=${EPREFIX}/usr/$(get_libdir)"
	mc "CC=${CHOST}-gcc"
	mc "CXX=${CHOST}-g++"
	mc '--enable-linker=gold'
	mc '--enable-hardening'
	mc '--enable-optimize'
	mc '--enable-rust-simd'
	mc '--without-ccache'
	mc "--x-includes=${SYSROOT}${EPREFIX}/usr/include"
	mc "--x-libraries=${SYSROOT}${EPREFIX}/usr/$(get_libdir)"

	# Branding
	mc '--enable-official-branding'
	mc '--with-distribution-id=org.gnu'
	
	# System libraries
	mc '--with-system-zlib'
	mc '--with-system-bz2'
	mc '--with-system-av1'
	mc '--with-system-icu'
	mc '--with-system-harfbuzz'
	mc '--with-system-graphite2'
	mc '--with-system-jpeg'
	mc '--with-system-png'
	mc '--with-system-nspr'
	mc "--with-nspr-prefix=${SYSROOT}${EPREFIX}/usr"
	mc '--with-system-nss'
	mc "--with-nss-prefix=${SYSROOT}${EPREFIX}/usr"
	mc '--with-system-libvpx'
	mc "--with-system-libevent=${SYSROOT}${EPREFIX}/usr"
	mc '--enable-system-sqlite'
	mc '--enable-system-ffi'
	
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
	if use startup-notification; then
		mc '--enable-startup-notification'
	else
		mc '--disable-startup-notification'
	fi
	mc '--disable-crashreporter'
	mc '--disable-updater'
	mc '--disable-debug-symbols'
	mc '--disable-tests'
	mc '--disable-eme'
	mc '--disable-gconf'

	echo 'mk_add_options XARGS=/usr/bin/xargs') \
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
	if use startup-notification; then
		sed -e 's/StartupNotify=false/StartupNotify=true/' \
		-i "${D}/usr/share/applications/${PN}.desktop"
	fi
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}
