# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="GNU IceCat Web Browser Sources"
HOMEPAGE="https://www.gnu.org/software/gnuzilla"

KEYWORDS="*"
SLOT="${PVR}"
LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
IUSE=""

GNUZILLA_PV="76dced64ce0e72fe3030dc2f7b22cda8e36b165e"
SRC_URI="
	https://git.savannah.gnu.org/cgit/gnuzilla.git/snapshot/gnuzilla-${GNUZILLA_PV}.tar.gz
	https://ftp.mozilla.org/pub/mozilla.org/firefox/releases/${PV}esr/source/firefox-${PV}esr.source.tar.xz
	https://hg.mozilla.org/l10n/compare-locales/archive/RELEASE_3_3_0.zip -> mozilla-compare-locales-3.3.0.zip"

DEPEND="
	dev-perl/rename
	app-arch/libarchive"
RDEPEND=""

src_unpack() {
	for a in ${A}; do
		unpack "${a}" || die
		break
	done
	mv "gnuzilla-${GNUZILLA_PV}" "${P}"
	cd "${P}"

	eapply \
	"${FILESDIR}/makeicecat-stuff.patch" \
	"${FILESDIR}/stages.patch" \
	"${FILESDIR}/sandbox.patch" || die
	local pv=(${PV//./ })
	sed -e "s/^FFMAJOR.*/FFMAJOR=${pv[0]}/g" -i makeicecat &&
	sed -e "s/^FFMINOR.*/FFMINOR=${pv[1]}/g" -i makeicecat &&
	sed -e "s/^FFSUB.*/FFSUB=${pv[2]}/g" -i makeicecat || die

	rm -rf output
	echo 'en-US' > data/shipped-locales
	UNPACK=only bash makeicecat || die
}

src_prepare() {
	eapply_user
	for f in data/files-to-append/l10n/*; do
	  [ -e "output/icecat-${PV}/l10n/${f##*/}" ] || rm -rf "$f"
	done
	UNPACK= bash makeicecat || die
}

src_install() {
	install -Dm644 "output/icecat-${PV}-gnu"*".tar.bz2" \
	"${D}/usr/src/icecat-${PV}.tar.bz2" || die
}
