################################################################################
#
# python-ytmusicapi
#
################################################################################

PYTHON_YTMUSICAPI_VERSION = 1.12.0
PYTHON_YTMUSICAPI_SOURCE  = ytmusicapi-$(PYTHON_YTMUSICAPI_VERSION).tar.gz
PYTHON_YTMUSICAPI_SITE    = https://files.pythonhosted.org/packages/4f/16/728305b1e6d100f2f2c696f6de08b3717f3db323bd666a8246397d70bcad
PYTHON_YTMUSICAPI_SETUP_TYPE   = setuptools
PYTHON_YTMUSICAPI_LICENSE      = MIT
PYTHON_YTMUSICAPI_LICENSE_FILES = LICENSE
PYTHON_YTMUSICAPI_DEPENDENCIES = host-python-setuptools-scm

$(eval $(python-package))
