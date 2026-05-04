################################################################################
#
# hermes-systemd — system D-Bus daemon (org.hermes.System1).
#
################################################################################

HERMES_SYSTEMD_VERSION     = local
HERMES_SYSTEMD_SITE        = $(BR2_EXTERNAL_HERMES_PATH)/../hermes-systemd
HERMES_SYSTEMD_SITE_METHOD = local

HERMES_SYSTEMD_DEPENDENCIES = sdbus-cpp hermes-ipc host-sdbus-cpp

HERMES_SYSTEMD_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release

define HERMES_SYSTEMD_INSTALL_INIT_SYSTEMD
	# CMake install already drops the unit under /usr/lib/systemd/system/.
	# Enable at boot via multi-user.target wants symlink.
	ln -sf /usr/lib/systemd/system/hermes-systemd.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/hermes-systemd.service
endef

$(eval $(cmake-package))
