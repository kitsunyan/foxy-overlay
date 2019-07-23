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
IUSE="jack pulseaudio dbus startup-notification gnu-extensions"

CDEPEND="
	>=app-text/hunspell-1.5.4:=
	jack? ( virtual/jack )
	pulseaudio? (
		|| (
			media-sound/pulseaudio
			>=media-sound/apulse-0.1.9
		)
	)
	>=dev-libs/nss-3.36.8
	>=dev-libs/nspr-4.19
	dev-libs/atk
	dev-libs/expat
	>=x11-libs/gtk+-2.18:2
	>=x11-libs/gtk+-3.4.0:3=[X]
	>=media-libs/libpng-1.6.34:0=[apng]
	>=media-libs/mesa-10.2:*
	kernel_linux? ( !pulseaudio? ( media-libs/alsa-lib ) )
	virtual/freedesktop-icon-theme
	dbus? (
		>=sys-apps/dbus-0.60
		>=dev-libs/dbus-glib-0.72
	)
	startup-notification? ( >=x11-libs/startup-notification-0.8 )
	>=x11-libs/pixman-0.19.2
	>=virtual/libffi-3.0.10:=
	virtual/ffmpeg
	x11-libs/libXt
	>=dev-libs/icu-60.2
	>=media-libs/libjpeg-turbo-1.2.1
	>=dev-libs/libevent-2.0:0=[threads]
	>=dev-db/sqlite-3.21.1:3[secure-delete]
	>=media-libs/libvpx-1.5.0:0=[postproc]
	<media-libs/libvpx-1.8:0=[postproc]"

DEPEND="${CDEPEND}
	=www-client/icecat-sources-${PV}
	app-arch/zip
	app-arch/unzip
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
	virtual/cargo
	virtual/rust
	amd64? (
		>=dev-lang/yasm-1.1
		virtual/opengl
	)
	x86? (
		>=dev-lang/yasm-1.1
		virtual/opengl
	)"

RDEPEND="${CDEPEND}"

pkg_setup() {
	llvm_pkg_setup
}

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

	(mc() { echo "ac_add_options $1"; }

	mc '--enable-application=browser'
	mc '--with-app-basename=icecat'
	mc '--with-app-name=icecat'
	
	mc "--prefix=${EPREFIX}/usr"
	mc "--libdir=${EPREFIX}/usr/$(get_libdir)"
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
	mc '--with-system-icu'
	mc '--with-system-jpeg'
	mc '--with-system-png'
	mc '--with-system-nspr'
	mc "--with-nspr-prefix=${SYSROOT}${EPREFIX}/usr"
	mc '--with-system-nss'
	mc "--with-nss-prefix=${SYSROOT}${EPREFIX}/usr"
	mc '--with-system-libvpx'
	mc "--with-system-libevent=${SYSROOT}${EPREFIX}/usr"
	mc '--enable-system-hunspell'
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

	eapply_user
}

src_configure() {
	true
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
// Use LANG environment variable to choose locale
pref("intl.locale.requested", "");

// Disable default browser checking.
pref("browser.shell.checkDefaultBrowser", false);

// Opt all of us into e10s, instead of just 50%
pref("browser.tabs.remote.autostart", true);
END

	if ! use gnu-extensions; then
		for f in extensions/gnu/*; do
			rm -rfv "${D}/usr/$(get_libdir)/${PN}/browser/extensions/${f##*/}";
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
