# Maintainer: nullstacked <nullstacked@users.noreply.github.com>
pkgname=kvmd-web-defaults
pkgver=1.0.0
pkgrel=1
pkgdesc="Server-side UI defaults for PiKVM via CSS custom properties in /etc/kvmd/web.css"
arch=('any')
url="https://github.com/nullstacked/kvmd-plugins"
license=('GPL3')
depends=('kvmd')
install=kvmd-web-defaults.install
source=()
md5sums=()

package() {
    # Install patch apply script
    install -Dm755 "$srcdir/../files/apply-patches.sh" "$pkgdir/usr/share/kvmd-web-defaults/apply-patches.sh"

    # Install ALPM hook
    install -Dm644 "$srcdir/../kvmd-web-defaults.hook" "$pkgdir/etc/pacman.d/hooks/kvmd-web-defaults.hook"

    # Install default web.css if not present
    install -Dm644 "$srcdir/../files/web.css.example" "$pkgdir/usr/share/kvmd-web-defaults/web.css.example"
}
