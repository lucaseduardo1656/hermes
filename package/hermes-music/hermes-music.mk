################################################################################
#
# hermes-music
#
# Installs the daemon as Python source files. Cross-compiled binaries
# (PyInstaller) don't work because PyInstaller only produces host-arch
# binaries — we ship sources and let a first-boot bootstrap unit create
# a venv on the target and pip-install the requirements.
#
################################################################################

HERMES_MUSIC_VERSION = 0.1.0
HERMES_MUSIC_SITE        = $(BR2_EXTERNAL_HERMES_PATH)/src/hermes-music
HERMES_MUSIC_SITE_METHOD = local

HERMES_MUSIC_DEPENDENCIES = python3 python-pip

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

	# First-boot bootstrap (creates venv + pip install).
	$(INSTALL) -D -m 0755 $(HERMES_MUSIC_PKGDIR)/hermes-music-bootstrap.sh \
		$(TARGET_DIR)/usr/lib/hermes-music/bootstrap.sh

	# systemd units.
	$(INSTALL) -D -m 0644 $(HERMES_MUSIC_PKGDIR)/hermes-music.service \
		$(TARGET_DIR)/usr/lib/systemd/system/hermes-music.service
	$(INSTALL) -D -m 0644 $(HERMES_MUSIC_PKGDIR)/hermes-music-bootstrap.service \
		$(TARGET_DIR)/usr/lib/systemd/system/hermes-music-bootstrap.service
endef

define HERMES_MUSIC_INSTALL_INIT_SYSTEMD
	ln -sf /usr/lib/systemd/system/hermes-music.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/hermes-music.service
	ln -sf /usr/lib/systemd/system/hermes-music-bootstrap.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/hermes-music-bootstrap.service
endef

$(eval $(generic-package))
