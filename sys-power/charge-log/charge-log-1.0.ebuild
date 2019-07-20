# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit xdg-utils

DESCRIPTION="Battery charge history logger"
HOMEPAGE="https://github.com/kitsunyan/charge-log"

SLOT="0"
LICENSE="GPL-3+"
KEYWORDS="amd64 x86"
IUSE="systemd gtk gtk3"
REQUIRED_USE="|| ( gtk gtk3 )"

SRC_URI="https://github.com/kitsunyan/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

DEPEND="
	systemd? ( sys-apps/systemd:0= )
	!gtk3? ( x11-libs/gtk+:2 )
	gtk3? ( x11-libs/gtk+:3 )"
RDEPEND="${DEPEND}"

src_configure() {
	local myconf=(
		$(use_enable systemd)
		--enable-openrc
	)
	if use gtk3; then
		myconf+=(
			--enable-gtk3
		)
	else
		myconf+=(
			--enable-gtk2
		)
	fi
	econf "${myconf[@]}"
}

pkg_postinst() {
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_desktop_database_update
}
