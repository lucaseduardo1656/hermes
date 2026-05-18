################################################################################
#
# hermes-music
#
# Ships the daemon as Python source files. Runtime dependencies are split:
#
# - Wheels that ship native code (fastapi, uvicorn, pydantic-core, …) come
#   from the corresponding Buildroot package selections, so they are
#   cross-compiled for aarch64 and end up under /usr/lib/python3.13/
#   site-packages on the target.
#
# - Pure-Python deps that Buildroot doesn't package (yt-dlp, ytmusicapi,
#   spotipy, diskcache) are installed at build time using the host pip
#   into the target's site-packages with --no-deps. They contain no
#   compiled extensions, so they're portable as-is.
#
# This removes the old first-boot bootstrap that ran pip on the Pi and
# cost ~45 s on a fresh image.
#
################################################################################

HERMES_MUSIC_VERSION = 0.1.0
HERMES_MUSIC_SITE        = $(BR2_EXTERNAL_HERMES_PATH)/src/hermes-music
HERMES_MUSIC_SITE_METHOD = local

HERMES_MUSIC_DEPENDENCIES = \
	python3 \
	python-aiofiles \
	python-dotenv \
	python-fastapi \
	python-httpx \
	python-pydantic \
	python-pydantic-settings \
	python-requests \
	python-spotipy \
	python-starlette \
	python-uvicorn \
	python-yt-dlp \
	python-ytmusicapi

define HERMES_MUSIC_INSTALL_TARGET_CMDS
	# Daemon sources (the entry point + modules).
	mkdir -p $(TARGET_DIR)/usr/share/hermes-music
	cp -a $(@D)/main.py             $(TARGET_DIR)/usr/share/hermes-music/
	cp -a $(@D)/config.py           $(TARGET_DIR)/usr/share/hermes-music/
	cp -a $(@D)/downloader.py       $(TARGET_DIR)/usr/share/hermes-music/
	cp -a $(@D)/history.py          $(TARGET_DIR)/usr/share/hermes-music/
	cp -a $(@D)/resolver.py         $(TARGET_DIR)/usr/share/hermes-music/
	cp -a $(@D)/requirements.txt    $(TARGET_DIR)/usr/share/hermes-music/
	cp -a $(@D)/api                 $(TARGET_DIR)/usr/share/hermes-music/
	cp -a $(@D)/auth                $(TARGET_DIR)/usr/share/hermes-music/
	cp -a $(@D)/providers           $(TARGET_DIR)/usr/share/hermes-music/

	# systemd unit.
	$(INSTALL) -D -m 0644 $(HERMES_MUSIC_PKGDIR)/hermes-music.service \
		$(TARGET_DIR)/usr/lib/systemd/system/hermes-music.service
endef

define HERMES_MUSIC_INSTALL_INIT_SYSTEMD
	ln -sf /usr/lib/systemd/system/hermes-music.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/hermes-music.service
endef

$(eval $(generic-package))
