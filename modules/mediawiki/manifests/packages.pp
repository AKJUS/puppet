# === Class mediawiki::packages
#
# Packages needed for mediawiki
class mediawiki::packages {
    include imagemagick::install
    include mediawiki::firejail

    stdlib::ensure_packages([
        'djvulibre-bin',
        'dvipng',
        'espeak-ng-espeak',
        'lame',
        'ghostscript',
        'htmldoc',
        'inkscape',
        'fonts-freefont-ttf',
        'ffmpeg',
        'locales-all',
        'oggvideotools',
        'libxi-dev',
        'libglu1-mesa-dev',
        'libglew-dev',
        'libvips-tools',
        'nodejs',
        'ploticus',
        'poppler-utils',
        'python3',
        'python3-venv',
        'python3-pip',
        'netpbm',
        'librsvg2-dev',
        'libjpeg-dev',
        'libgif-dev',
        'p7zip-full',
        'xvfb',
        'timidity',
        'librsvg2-bin',
        'python3-minimal',
        'python3-requests',
        'rsync',
        'python3-swiftclient',
    ])

    if !lookup(mediawiki::use_shellbox) {
        stdlib::ensure_packages(
            'lilypond',
            {
                ensure => absent,
            },
        )
    }
}
