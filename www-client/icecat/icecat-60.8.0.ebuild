# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=(python3_{5,6,7})
PYTHON_REQ_USE='ncurses,sqlite,ssl,threads(+)'
LLVM_MAX_SLOT=8

inherit desktop gnome2-utils xdg-utils llvm

DESCRIPTION="GNU IceCat Web Browser"
HOMEPAGE="https://www.gnu.org/software/gnuzilla"

KEYWORDS="amd64 arm64 x86"
SLOT="0"
LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
IUSE="dbus startup-notification gnu-extensions"

CDEPEND="
	>=dev-libs/nss-3.43
	>=dev-libs/nspr-4.21
	dev-libs/atk
	dev-libs/expat
	>=x11-libs/cairo-1.10[X]
	>=x11-libs/gtk+-2.18:2
	>=x11-libs/gtk+-3.4.0:3=[X]
	x11-libs/gdk-pixbuf
	>=x11-libs/pango-1.22.0
	>=media-libs/libpng-1.6.35:0=[apng]
	>=media-libs/mesa-10.2:*
	media-libs/fontconfig
	>=media-libs/freetype-2.4.10
	kernel_linux? ( media-libs/alsa-lib )
	virtual/freedesktop-icon-theme
	dbus? ( >=sys-apps/dbus-0.60
		>=dev-libs/dbus-glib-0.72 )
	startup-notification? ( >=x11-libs/startup-notification-0.8 )
	>=x11-libs/pixman-0.19.2
	>=dev-libs/glib-2.26:2
	>=sys-libs/zlib-1.2.3
	>=virtual/libffi-3.0.10:=
	virtual/ffmpeg
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrender
	x11-libs/libXt
	>=media-libs/dav1d-0.2.0:=
	>=media-libs/libaom-1.0.0:=
	>=media-libs/harfbuzz-2.3.1:0= >=media-gfx/graphite2-1.3.13
	>=dev-libs/icu-63.1:=
	>=media-libs/libjpeg-turbo-1.2.1
	>=dev-db/sqlite-3.27.2:3[secure-delete]
	>=media-libs/libwebp-1.0.2:0="

DEPEND="${CDEPEND}
	=www-client/icecat-sources-${PV}
	app-arch/zip
	app-arch/unzip
	>=dev-util/cbindgen-0.8.2
	>=net-libs/nodejs-8.11.0
	>=sys-devel/binutils-2.30
	sys-apps/findutils
	|| (
		(
			sys-devel/clang:8
			sys-devel/llvm:8
		)
		(
			sys-devel/clang:7
			sys-devel/llvm:7
		)
		(
			sys-devel/clang:6
			sys-devel/llvm:6
		)
	)
	>=virtual/cargo-1.31.0
	>=virtual/rust-1.31.0
	amd64? ( >=dev-lang/yasm-1.1 virtual/opengl )
	x86? ( >=dev-lang/yasm-1.1 virtual/opengl )"

RDEPEND="${CDEPEND}"

src_unpack() {
	cp -rp "/usr/src/${P}" . || die
}

src_prepare() {
	sed -i config/baseconfig.mk \
	-e 's;$(libdir)/$(MOZ_APP_NAME)-$(MOZ_APP_VERSION);$(libdir)/$(MOZ_APP_NAME);g'
	sed -i config/baseconfig.mk \
	-e 's;$(libdir)/$(MOZ_APP_NAME)-devel-$(MOZ_APP_VERSION);$(libdir)/$(MOZ_APP_NAME)-devel;g'

	patch -Np1 -i "${FILESDIR}/rust_133-part0.patch" || die
	patch -Np1 -i "${FILESDIR}/rust_133-part1.patch"
	patch -Np1 -i "${FILESDIR}/rust_133-part2.patch" || die
	patch -Np1 -i "${FILESDIR}/deny_missing_docs.patch" || die
	patch -Np1 -i "${FILESDIR}/fix-addons.patch" || die

	(echo 'ac_add_options --enable-application=browser'
	echo 'ac_add_options --with-app-basename=icecat'
	echo 'ac_add_options --with-app-name=icecat'
	
	echo 'ac_add_options --prefix=/usr'
	echo "ac_add_options --libdir=/usr/`get_libdir`"
	echo 'ac_add_options --enable-linker=gold'
	echo 'ac_add_options --enable-hardening'
	echo 'ac_add_options --enable-optimize'
	echo 'ac_add_options --enable-rust-simd'

	# Branding
	echo 'ac_add_options --enable-official-branding'
	echo 'ac_add_options --with-distribution-id=org.gnu'
	
	# System libraries
	echo 'ac_add_options --with-system-zlib'
	echo 'ac_add_options --with-system-bz2'
	echo 'ac_add_options --with-system-icu'
	echo 'ac_add_options --with-system-jpeg'
	echo 'ac_add_options --with-system-nspr'
	echo 'ac_add_options --with-system-nss'
	echo 'ac_add_options --enable-system-sqlite'
	echo 'ac_add_options --enable-system-ffi'
	
	# Features
	echo 'ac_add_options --enable-alsa'
	if use startup-notification; then
		echo 'ac_add_options --enable-startup-notification'
	fi
	echo 'ac_add_options --disable-crashreporter'
	echo 'ac_add_options --disable-updater'
	echo 'ac_add_options --disable-debug-symbols'
	echo 'ac_add_options --disable-tests'
	echo 'ac_add_options --disable-eme'
	echo 'ac_add_options --disable-gconf'

	echo 'mk_add_options XARGS=/usr/bin/xargs') \
	> .mozconfig

	eapply_user
}

src_configure() {
	true
}

src_compile() {
	PATH="${FILESDIR}:${PATH}" ICECATDIR="/usr/`get_libdir`/${PN}" \
	CC=clang CXX=clang++ AR=llvm-ar NM=llvm-nm RANLIB=llvm-ranlib \
	./mach build || die
}

src_install() {
	local f s

	PATH="${FILESDIR}:${PATH}" DESTDIR="${D}" \
	./mach install || die

	local vendorjs="${D}/usr/`get_libdir`/${PN}/browser/defaults/preferences/vendor.js"
	install -Dm644 /dev/stdin "$vendorjs" <<END
// Use LANG environment variable to choose locale
pref("intl.locale.requested", "");

// Disable default browser checking.
pref("browser.shell.checkDefaultBrowser", false);

// Opt all of us into e10s, instead of just 50%
pref("browser.tabs.remote.autostart", true);
END

	if ! use gnu-extensions; then
		for f in extensions/gnu/*; do
			rm -rfv "${D}/usr/`get_libdir`/${PN}/browser/extensions/${f##*/}";
		done
		rmdir -pv "${D}/usr/`get_libdir`/${PN}/browser/extensions"
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
