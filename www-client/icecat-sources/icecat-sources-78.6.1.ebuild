# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="GNU IceCat Web Browser Sources"
HOMEPAGE="https://www.gnu.org/software/gnuzilla"

KEYWORDS="*"
SLOT="${PVR}"
LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
IUSE=""

GNUZILLA_PV="10ca84bd9d255caeed506ef36bd3dbe2ad6375ab"
SRC_URI="
	https://git.savannah.gnu.org/cgit/gnuzilla.git/snapshot/gnuzilla-${GNUZILLA_PV}.tar.gz
	https://ftp.mozilla.org/pub/mozilla.org/firefox/releases/${PV}esr/source/firefox-${PV}esr.source.tar.xz
	https://hg.mozilla.org/l10n/compare-locales/archive/RELEASE_8_0_0.zip -> mozilla-compare-locales-8.0.0.zip"

DEPEND="
	app-arch/libarchive"
RDEPEND=""

src_unpack() {
	for a in ${A}; do
		unpack "${a}" || die
		break
	done
	mv "gnuzilla-${GNUZILLA_PV}" "${P}"
	cd "${P}"

	sed -e '/\.source\.tar\.xz \?| \?sha256sum -c/d' -i makeicecat || die
	eapply \
	"${FILESDIR}/stages.patch" \
	"${FILESDIR}/sandbox.patch" || die
	local pv=(${PV//./ })
	sed -e "s/^FFMAJOR.*/FFMAJOR=${pv[0]}/g" -i makeicecat &&
	sed -e "s/^FFMINOR.*/FFMINOR=${pv[1]}/g" -i makeicecat &&
	sed -e "s/^FFSUB.*/FFSUB=${pv[2]}/g" -i makeicecat &&
	sed -e 's/\(\bfind l10n .*\)/\1 || true/' -i makeicecat || die
	sed -e 's/cfj\( .*\).bz2/cfz\1.gz/' -i makeicecat || die

	# parallel find+sed
	local nproc="`grep -Po '(?<=-j)\d+' <<< "$MAKEOPTS"`"
	[ -z "$nproc" ] && nproc='1'
	local fcmd='\(\bfind .*\) -execdir \(/bin/sed .*\) '"';'"
	local frepl='\1 -print0 | xargs -0 -P '"$nproc"' -i \2'
	sed -e "s,$fcmd,$frepl," -i makeicecat || die

	rm -rf output
	echo 'en-US' > data/shipped-locales
	PATH="${FILESDIR}:${PATH}" UNPACK=only bash makeicecat || die
}

src_prepare() {
	eapply_user
	for f in data/files-to-append/l10n/*; do
	  [ -e "output/icecat-${PV}/l10n/${f##*/}" ] || rm -rf "$f"
	done
	PATH="${FILESDIR}:${PATH}" UNPACK= bash makeicecat || die
}

src_install() {
	install -Dm644 "output/icecat-${PV}-gnu"*".tar.gz" \
	"${D}/usr/src/icecat-${PV}.tar.gz" || die
}
