################################################################################
#
# hermes-ipc — D-Bus interface definitions for the Hermes stack.
#
# Ships only XMLs + a CMake helper module; produces no runtime artifacts.
# Consumers (hermes-systemd, elise, …) generate sdbus-c++ stubs at build
# time via host-sdbus-cpp's sdbus-c++-xml2cpp.
#
################################################################################

HERMES_IPC_VERSION       = local
HERMES_IPC_SITE          = $(BR2_EXTERNAL_HERMES_PATH)/../hermes-ipc
HERMES_IPC_SITE_METHOD   = local
HERMES_IPC_INSTALL_STAGING = YES
HERMES_IPC_INSTALL_TARGET  = NO

# host-sdbus-cpp provides sdbus-c++-xml2cpp; consumers depend on that
# transitively. hermes-ipc itself is a pure data package.
HERMES_IPC_DEPENDENCIES = host-sdbus-cpp

$(eval $(cmake-package))
