# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="GNU IceCat Web Browser Sources"
HOMEPAGE="https://www.gnu.org/software/gnuzilla"

KEYWORDS="*"
SLOT="${PVR}"
LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
IUSE=""

GNUZILLA_PV="6634ee332979f7a78b11cbf09a77364143a981ed"
SRC_URI="
	https://git.savannah.gnu.org/cgit/gnuzilla.git/snapshot/gnuzilla-${GNUZILLA_PV}.tar.gz
	https://ftp.mozilla.org/pub/mozilla.org/firefox/releases/${PV}esr/source/firefox-${PV}esr.source.tar.xz"

DEPEND="
	dev-vcs/mercurial
	dev-perl/rename
	net-misc/wget
	app-crypt/gnupg"
RDEPEND=""

src_unpack() {
	for a in ${A}; do
		unpack "${a}" || die
		break
	done
	mv "gnuzilla-${GNUZILLA_PV}" "${P}"
	cd "${P}"

	patch -Np1 -i "${FILESDIR}/makeicecat-stuff.patch" || die
	patch -Np1 -i "${FILESDIR}/stages.patch" || die
	patch -Np1 -i "${FILESDIR}/us-locale.patch" || die
	sed -e '/sha256sum/d' -i makeicecat || die
	sed -e "s/^FFMAJOR.*/FFMAJOR=${PV:0:2}/g" -i makeicecat || die
	sed -e "s/^FFMINOR.*/FFMINOR=${PV:(-3):(-2)}/g" -i makeicecat || die
	sed -e "s/^FFSUB.*/FFSUB=${PV:(5)}/g" -i makeicecat || die

	rm -rf output
	PATH=${FILESDIR}:${PATH} UNPACK=only bash makeicecat || die
}

src_prepare() {
	eapply_user
	UNPACK= bash makeicecat || die
}

src_install() {
	mkdir -p "${D}/usr/src"
	mv "output/icecat-${PV}" "${D}/usr/src"
}
