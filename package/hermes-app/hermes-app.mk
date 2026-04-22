################################################################################
#
# hermes-app
#
################################################################################

HERMES_APP_VERSION = local
HERMES_APP_SITE = $(BR2_EXTERNAL_HERMES_PATH)/src/hermes-app
HERMES_APP_SITE_METHOD = local

HERMES_APP_DEPENDENCIES = qt6base qt6declarative qt6svg

HERMES_APP_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release

$(eval $(cmake-package))
