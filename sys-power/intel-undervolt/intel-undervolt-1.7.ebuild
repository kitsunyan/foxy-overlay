# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit linux-info systemd toolchain-funcs

DESCRIPTION="Intel CPU undervolting and throttling configuration tool"
HOMEPAGE="https://github.com/kitsunyan/intel-undervolt"

KEYWORDS="-* amd64"
SLOT="0"
LICENSE="GPL-3"
IUSE="systemd elogind"

SRC_URI="https://github.com/kitsunyan/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

DEPEND="
	systemd? ( sys-apps/systemd:0= )
	elogind? ( sys-auth/elogind )"
RDEPEND=""

CONFIG_CHECK="~INTEL_RAPL ~X86_MSR"

src_configure() {
	local myconf=(
		$(use_enable systemd)
		$(use_enable elogind)
		--enable-openrc
	)
	econf "${myconf[@]}"
}
