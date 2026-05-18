################################################################################
#
# python-spotipy
#
################################################################################

PYTHON_SPOTIPY_VERSION = 2.26.0
PYTHON_SPOTIPY_SOURCE  = spotipy-$(PYTHON_SPOTIPY_VERSION).tar.gz
PYTHON_SPOTIPY_SITE    = https://files.pythonhosted.org/packages/88/00/2de6f99c9b8e5fd519fd55b11ec94b8e97a51e8a9fdf546edfe6aaf8727b
PYTHON_SPOTIPY_SETUP_TYPE = setuptools
PYTHON_SPOTIPY_LICENSE    = MIT
PYTHON_SPOTIPY_LICENSE_FILES = LICENSE.md

$(eval $(python-package))
