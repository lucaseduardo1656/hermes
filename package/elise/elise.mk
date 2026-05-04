################################################################################
#
# elise
#
################################################################################

ELISE_VERSION = local
ELISE_SITE = $(BR2_EXTERNAL_HERMES_PATH)/src/elise
ELISE_SITE_METHOD = local

ELISE_DEPENDENCIES = qt6base qt6declarative qt6svg qt6virtualkeyboard qt6multimedia

ELISE_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release

$(eval $(cmake-package))
