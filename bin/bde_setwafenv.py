#!/usr/bin/env python
from __future__ import division, absolute_import, print_function

import os
import re
import sys
import optparse
import platform


if platform.system() == 'Windows':
    print('This tool is currently not supported on windows.', file=sys.stderr)
    sys.exit(1)


def _where(program):
    def is_exe(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

    for path in os.environ["PATH"].split(os.pathsep):
        path = path.strip('"')
        exe_file = os.path.join(path, program)
        if is_exe(exe_file):
            return path

    return None


def _get_lib_path():
    # Uses the local BDE waf customziations if they exist
    path = _where('waf')

    def err():
        print('Cannot find the BDE customizations for waf in '
              'the waflib directory. Make sure that the '
              'bde-oss-tools version of waf can be found in '
              'PATH.', file=sys.stderr)
        sys.exit(1)

    if not path:
        err()
    path = os.path.join(path, 'lib')
    if not os.path.isdir(path):
        err()

    return path


tools_path = _get_lib_path()
sys.path = [tools_path] + sys.path

from bdebld.meta import sysutil
import bdebld.meta.options
from bdebld.meta import optionsutil
from bdebld.meta import optionsevaluator


def _get_cpu_type():
    platform_str = sysutil.unversioned_platform()

    if platform_str == 'linux':
        cpu_type = os.uname()[4]
    elif platform_str == 'aix':
        cpu_type = sysutil.shell_command(['/bin/uname', '-p']).rstrip()
    elif platform_str == 'sunos':
        cpu_type = sysutil.shell_command(['/bin/uname', '-p']).rstrip()
    elif platform_str == 'darwin':
        cpu_type = os.uname()[4]
    else:
        raise ValueError('Unsupported platform %s' % platform_str)

    return cpu_type


def _make_uplid(comp_type, comp_ver):

    os_type, os_name, os_ver = sysutil.get_os_info()
    cpu_type = _get_cpu_type()

    return bdebld.meta.options.Uplid(os_type, os_name, cpu_type, os_ver,
                                     comp_type, comp_ver)


def _determine_installation_location(prefix, uplid):
    """ Return the installation location for BDE was previously encoded.

    Return the installation location encoded in the specified 'prefix' for the
    specified 'uplid', or None if a location cannot be determined.  If 'prefix'
    matches the pattern of a PREFIX environment variable emitted by
    'bde_setwafenv.py' -- i.e., it contains this cpu-architectures portions of
    'uplid' as part of the last element of a directory location -- return the
    installation directory previously used by 'bde_setwafenv.py'.

    Args:
        prefix (str): prefix
    """
    if (prefix is None):
        return None

    partialUplid = uplid.os_type + '-' + uplid.os_name + '-' + \
        uplid.cpu_type + '-' + uplid.os_ver

    pattern = "(.*/){0}(?:\-[\w\.]*)*".format(partialUplid)
    match = re.match(pattern, prefix)
    if (match):
        return match.group(1)
    return None


def _print_setenvs(uplid, ufid, option_rules, options):
    debug_opt_keys = options.debug_opt_keys
    if debug_opt_keys:
        debug_opt_keys = debug_opt_keys.split(',')
    else:
        debug_opt_keys = []

    oe = optionsevaluator.OptionsEvaluator(uplid, ufid)
    oe.store_option_rules(option_rules, debug_opt_keys)
    oe.evaluate(debug_opt_keys)

    cxx_line = oe.results['CXX'].split()
    cxx_index = 0
    if cxx_line[0].strip().startswith('LIBPATH'):
        cxx_index = 1

    CXX = cxx_line[cxx_index]

    print('export CXX="%s"' % CXX)
    print('export BDE_WAF_UFID="%s"' % ufid)
    print('export BDE_WAF_UPLID="%s"' % uplid)
    id_str = str(uplid) + '-' + str(ufid)
    print('export BDE_WAF_BUILD_DIR="%s"' % id_str)
    print('export WAFLOCK=".lock-waf-%s"' % id_str)

    if options.install_dir:
        install_dir = options.install_dir
    else:
        install_dir = _determine_installation_location(
            os.environ.get("PREFIX"), uplid)

    if install_dir:
        print("using install directory: %s" % install_dir, file=sys.stderr)
        PREFIX = os.path.join(install_dir, id_str)
        print('export PREFIX="%s"' % PREFIX)
        print('export PKG_CONFIG_PATH="%s/lib/pkgconfig"' % PREFIX)


if __name__ == "__main__":
    usage = \
""" eval `bde_setwafenv.py [list|unset] -i <root_install_dir> [-c <compiler> -t <ufid>]`

The bde_setwafenv.py script configures the BDE waf build tool in a way similar
to bde_build.pl. It works by printing Bourne shell commands that sets
environment variables understood by waf to stdout. Therefore, the output must
be executed by the current Bourne shell (using 'eval') for them to be visible
by waf.

This script provides two options that work the same as bde_build: '-c'
specifies the compiler and its version, and '-t' specifies the ufid.  This
script uses the same meta-data files read by bde_build, 'default.opts' and
'default_internal.opts', to ensure that the two options exhibit the same
behavior. If '-c' is not specified, then the default compiler is used (you can
find out what the default compiler is by using the 'list' command).  If '-t' is
not specified, then the default ufid is used.

In addition, this script provides the '-i' option to specify the "root
installation directory".  This directory is not the same as the '--prefix'
option passed to the 'waf configure' command. Instead, it serves as the
directory under which a sub-directory, named according to the uplid (determined
by the specified compiler and the current platform) and ufid, is located.  This
sub-directory is the actual prefix location. This design decision is made so
that multiple builds using different configurations may be installed to the
same "root installation directory".  If no installation directory is supplied,
but the PREFIX environment variable value matches the pattern produced by this
script, then the installation directory previously configured by this script
is used.

This script also provides two optional commands, 'list' and 'unset'.

The 'list' command lists the available compilers based on the BDE
meta-data. This list is useful when you don't know the available compilers on
the current system. Note that this script does not verify that all compilers
shown are available on the current system.  The list of compilers and their
locations are maintained in the BDE meta-data, which is only applicable on
certain development machines at Bloomberg.

The 'unset' command unsets all the environment variables that may be set by
this script.

If none of the optional commands are used, this script print the following
Bourne shell statements to set environment variables (with sample values):

export CXX="/opt/swt/install/gcc-4.7.2/bin/g++"
export BDE_WAF_UFID="dbg_mt_exc"
export BDE_WAF_UPLID="unix-linux-x86_64-2.6.18-gcc-4.7.2"
export BDE_WAF_BUILD_DIR="unix-linux-x86_64-2.6.18-gcc-4.7.2-dbg_mt_exc"
export WAFLOCK=".lock-waf-unix-linux-x86_64-2.6.18-gcc-4.7.2-dbg_mt_exc"
export PREFIX="${HOME}/bde-install/unix-linux-x86_64-2.6.18-gcc-4.7.2-dbg_mt_exc"
export PKG_CONFIG_PATH="${HOME}/bde-install/unix-linux-x86_64-2.6.18-gcc-4.7.2-dbg_mt_exc/lib/pkgconfig"

/Explaination of Environment Variables
/-------------------------------------

CXX               - the path to the C++ compiler

BDE_WAF_UFID      - the ufid to use

BDE_WAF_UPLID     - the uplid determined by bde_setewafenv. Note that waf will
                    still generate a uplid based on the current platform and
                    the compiler being used. If the generated uplid does not
                    match BDE_WAF_UPLID, then waf will print a warning message
                    and proceed to use 'BDE_WAF_UPLID' as the uplid.

BDE_WAF_BUILD_DIR - the subdirectory under the source root in which build
                    artifacts will be generated

WAFLOCK           - the lock file used by waf, this file will be unique for
                    each uplid-ufid combination

PREFIX            - the installation prefix

PKG_CONFIG_PATH   - the path containing the .pc files for the installed
                    libraries

/Usage Examples
/--------------

1) eval `bde_setwafenv.py -c gcc-4.7.2 -t dbg_mt_exc -i ~/mbig/bde-install`

Set up the environment variables so that the BDE waf build tool uses the
gcc-4.7.2 compiler, builds with the ufid options 'dbg_mt_exc' to the output
directory '<uplid>-<ufid>', and install the libraries to a installation prefix
of '~/mbig/bde-install/<uplid>-<ufid>'.

On a particular unix system, the uplid will be
'unix-linux-x86_64-2.6.18-gcc-4.7.2', and
'unix-linux-x86_64-2.6.18-gcc-4.7.2-dbg_mt_exc' will be the name of the build
output directory.

2) eval `bde_setwafenv.py`

Set up the environment variables so that the BDE waf build tool uses the
default compiler on the current system configured using the default ufid. Use
the default installation prefix, which typically will be /usr/local -- this is
not recommended, because the default prefix is typically not writable by a
regular user.
"""
    parser = optparse.OptionParser(usage=usage)

    parser.add_option("-c", "--compiler", help="compiler")
    parser.add_option("-i", "--install-dir", help="install directory")
    parser.add_option("-t", "--ufid", help="universal flag id")
    parser.add_option("-d", "--debug-opt-keys")
    parser.add_option("--force_uplid", help="force uplid to specified value")

    (options, args) = parser.parse_args()

    if 'unset' in sys.argv:
        print('unset CXX')
        print('unset BDE_WAF_UFID')
        print('unset BDE_WAF_UPLID')
        print('unset BDE_WAF_BUILD_DIR')
        print('unset WAFLOCK')
        print('unset PREFIX')
        print('unset PKG_CONFIG_PATH')
        sys.exit(0)

    CXX = None
    PREFIX = None

    default_rules = optionsutil.get_default_option_rules()

    ufid_str = options.ufid
    if not ufid_str:
        ufid_str = 'dbg_mt_exc'
    else:
        if not bdebld.meta.options.Ufid.is_valid(ufid_str.split('_')):
            print('"%s" is an invalid ufid. Valid flags are: %s.' %
                  (ufid_str, ','.join(
                      bdebld.meta.options.Ufid.VALID_FLAGS.keys())),
                  file=sys.stderr)
            sys.exit(1)

    ufid = bdebld.meta.options.Ufid.from_str(ufid_str)

    if options.force_uplid:
        uplid = bdebld.meta.options.Uplid.from_str(options.force_uplid)
        _print_setenvs(uplid, ufid, default_rules, options)
        sys.exit(0)

    comps = set()

    DEFAULT_COMPILER = None
    DEFAULT_COMPILER_VERSION = None
    uplid = _make_uplid("*", "*")
    for rule in default_rules:
        match_uplid = rule.uplid
        if optionsutil.match_uplid(uplid, match_uplid):
            comp_type = match_uplid.comp_type
            comp_ver = match_uplid.comp_ver

            if rule.key == 'BDE_COMPILER_FLAG':
                DEFAULT_COMPILER = rule.value
            elif rule.key == 'BDE_COMPILERVERSION_FLAG':
                if comp_type == '*' or comp_type == DEFAULT_COMPILER:
                    DEFAULT_COMPILER_VERSION = rule.value

            if comp_type and comp_type != '*' and comp_type != 'def' and \
                    comp_ver and comp_ver != '*' and comp_ver != 'def':
                comps.add(comp_type + '-' + comp_ver)

    def_compiler = DEFAULT_COMPILER + '-' + DEFAULT_COMPILER_VERSION

    if 'list' in args:
        print('default: %s' % def_compiler)
        for c in sorted(comps):
            print(c)
        sys.exit(1)

    compiler = options.compiler
    if not compiler:
        compiler = def_compiler

    if compiler not in comps:
        print('%s is not valid, choose from the following: ' %
              options.compiler)
        for c in sorted(comps):
            print(c)
        sys.exit(1)

    print("using compiler: %s" % compiler, file=sys.stderr)
    print("using ufid: %s" % ufid, file=sys.stderr)

    if compiler:
        compiler = compiler.split('-')

        comp_type = compiler[0]
        if len(compiler) > 1:
            comp_ver = compiler[1]
        else:
            comp_ver = '*'

        uplid = _make_uplid(comp_type, comp_ver)
        _print_setenvs(uplid, ufid, default_rules, options)
