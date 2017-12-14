set(CPACK_DEB_COMPONENT_INSTALL ON)
set(CPACK_GENERATOR "DEB")
set(CPACK_CMAKE_GENERATOR "Ninja")
set(CPACK_PACKAGING_INSTALL_PREFIX "opt/bb")
set(CPACK_PACKAGE_CONTACT "osubbotin@bloomberg.net")

set(CPACK_PACKAGE_NAME "bsl")
set(CPACK_PACKAGE_FILE_NAME "libbsl-dev")
set(CPACK_PACKAGE_VERSION "3.2.0")
set(CPACK_PACKAGE_DESCRIPTION "BDE runtime.")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "BDE bsl library and headers.")

set(CPACK_INSTALL_CMAKE_PROJECTS
    "/bb/bde/osubbotin/workspace/bde/_build/unix-linux-x86_64-2.6.32-gcc-6.2.0-opt_dbg_exc_mt_cpp11/;/bde;bsl-headers;/"
    "/bb/bde/osubbotin/workspace/bde/_build/unix-linux-x86_64-2.6.32-gcc-6.2.0-opt_dbg_exc_mt_cpp11/;bde;bsl;/"
    "/bb/bde/osubbotin/workspace/bde/_build/unix-linux-x86_64-2.6.32-gcc-6.2.0-opt_dbg_exc_mt_cpp11/;bde;bsl-symlinks;/"
    "/bb/bde/osubbotin/workspace/bde/_build/unix-linux-x86_64-2.6.32-gcc-6.2.0-opt_dbg_exc_mt_64_cpp11/;bde;bsl;/"
    "/bb/bde/osubbotin/workspace/bde/_build/unix-linux-x86_64-2.6.32-gcc-6.2.0-opt_dbg_exc_mt_64_cpp11/;bde;bsl-symlinks;/"
)

