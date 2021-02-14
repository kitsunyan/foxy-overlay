# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit multiprocessing

DESCRIPTION="GNU IceCat Web Browser Sources"
HOMEPAGE="https://www.gnu.org/software/gnuzilla"

LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
SLOT="${PV}"
KEYWORDS="amd64 ~arm64 ~x86"
IUSE=""

GNUZILLA_PV="bb1c105f4416c2973f394680c2d579918a1da77a"
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

	# split into stages for sandboxing
	'eapply' "${FILESDIR}/stages.patch" || die
	echo 'en-US' > data/shipped-locales

	# substitute version
	local pv=(${PV//./ })
	'sed' -e "s/^\(readonly FFMAJOR=\).*/\1${pv[0]}/" -i makeicecat &&
	'sed' -e "s/^\(readonly FFMINOR=\).*/\1${pv[1]}/" -i makeicecat &&
	'sed' -e "s/^\(readonly FFSUB=\).*/\1${pv[2]}/" -i makeicecat || die

	PATH="${FILESDIR}:${PATH}" UNPACK=only ./makeicecat || die
}

src_prepare() {
	eapply_user

	# use gzip instead of bzip2
	sed -e 's/tar cfj/tar cfz/' -e 's/\.bz2/.gz/' -i makeicecat || die

	# remove locales
	sed -e 's/\(\bfind l10n .*\)/\1 || true/' -i makeicecat || die
	for f in data/files-to-append/l10n/*; do
		[ -e "output/icecat-${PV}/l10n/${f##*/}" ] || rm -rf "$f"
	done

	# parallel find+sed
	local fcmd='\(\bfind .*\) -execdir \(/bin/sed .*\) '"';'"
	local frepl='\1 -print0 | xargs -0 -P '"$(makeopts_jobs)"' -i \2'
	sed -e "s,$fcmd,$frepl," -i makeicecat || die

	PATH="${FILESDIR}:${PATH}" UNPACK= RENAME_CMD=prename ./makeicecat || die
}

src_install() {
	install -Dm644 "output/icecat-${PV}-gnu"*".tar.gz" \
	"${D}/usr/src/icecat-${PV}.tar.gz" || die
}
