################################################################################
#
# hermes-music
#
################################################################################

HERMES_MUSIC_VERSION = 0.1.0
HERMES_MUSIC_SITE    = $(TOPDIR)/src/hermes-music
HERMES_MUSIC_SITE_METHOD = local

HERMES_MUSIC_DEPENDENCIES = python3

define HERMES_MUSIC_BUILD_CMDS
	cd $(@D) && \
	python3 -m venv .venv && \
	.venv/bin/pip install --quiet -r requirements.txt pyinstaller && \
	.venv/bin/pyinstaller \
		--onefile \
		--name hermes-music \
		--add-data "$$(python3 -c 'import ytmusicapi,os;print(os.path.dirname(ytmusicapi.__file__))'):ytmusicapi" \
		--hidden-import uvicorn.logging \
		--hidden-import uvicorn.loops.auto \
		--hidden-import uvicorn.protocols.http.auto \
		--hidden-import uvicorn.lifespan.on \
		--hidden-import yt_dlp.extractor \
		main.py
endef

define HERMES_MUSIC_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/dist/hermes-music \
		$(TARGET_DIR)/usr/bin/hermes-music
	$(INSTALL) -D -m 0644 $(@D)/hermes-music.service \
		$(TARGET_DIR)/usr/lib/systemd/system/hermes-music.service
endef

define HERMES_MUSIC_INSTALL_INIT_SYSTEMD
	ln -sf /usr/lib/systemd/system/hermes-music.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/hermes-music.service
endef

$(eval $(generic-package))
