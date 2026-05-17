################################################################################
#
# elise
#
################################################################################

ELISE_VERSION = local
ELISE_SITE = $(BR2_EXTERNAL_HERMES_PATH)/src/elise
ELISE_SITE_METHOD = local

ELISE_DEPENDENCIES = qt6base qt6declarative qt6svg qt6multimedia mpv \
	sdbus-cpp hermes-ipc host-sdbus-cpp

ELISE_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release

$(eval $(cmake-package))
