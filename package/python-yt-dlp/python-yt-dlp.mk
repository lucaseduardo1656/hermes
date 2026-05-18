################################################################################
#
# python-yt-dlp
#
################################################################################

PYTHON_YT_DLP_VERSION = 2026.3.17
PYTHON_YT_DLP_SOURCE  = yt_dlp-$(PYTHON_YT_DLP_VERSION).tar.gz
PYTHON_YT_DLP_SITE    = https://files.pythonhosted.org/packages/8b/34/7c6b4e3f89cb6416d2cd7ab6dab141a1df97ab0fb22d15816db2c92148c9
PYTHON_YT_DLP_SETUP_TYPE   = pep517
PYTHON_YT_DLP_LICENSE      = Unlicense
PYTHON_YT_DLP_LICENSE_FILES = LICENSE
PYTHON_YT_DLP_DEPENDENCIES = host-python-hatchling

$(eval $(python-package))
