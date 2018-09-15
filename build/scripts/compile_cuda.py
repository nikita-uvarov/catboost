import sys
import subprocess
import os
import collections
import re


def is_clang(command):
    for word in command:
        if '--compiler-bindir' in word and 'clang' in word:
            return True

    return False


def main():
    spl = sys.argv.index('--cflags')
    command = sys.argv[1: spl]
    cflags = sys.argv[spl + 1:]

    dump_args = False
    if '--y_dump_args' in command:
        command.remove('--y_dump_args')
        dump_args = True

    executable = command[0]
    if not os.path.exists(executable):
        print >> sys.stderr, '{} not found'.format(executable)
        sys.exit(1)

    if is_clang(command):
        cflags.append('-Wno-unused-parameter')

    if not is_clang(command) and '-fopenmp=libomp' in cflags:
        cflags.append('-fopenmp')
        cflags.remove('-fopenmp=libomp')
        
    # -std=c++14 is not supported by nvcc 8.0
    if '-std=c++14' in command:
        print 'Replacing -std=c++14 with -std=c++11'
        command[command.index('-std=c++14')] = '-std=c++11'
    
    # compute_70 is not supported by nvcc 8.0
    i = 0
    while i < len(command):
        if 'compute_70' in command[i]:
            del command[i - 1]
            del command[i]
            i -= 1
        else:
            i += 1
        
    print 'Final command:', command

    skip_list = [
        '-nostdinc++',  # CUDA uses system STL library
        '-gline-tables-only',
        # clang coverage
        '-fprofile-instr-generate',
        '-fcoverage-mapping',
        '/Zc:inline',  # disable unreferenced functions (kernel registrators) remove
        '-Wno-c++17-extensions',
    ]

    for flag in skip_list:
        if flag in cflags:
            cflags.remove(flag)

    skip_prefix_list = [
        '-fsanitize=',
        '-fsanitize-coverage=',
        '-fsanitize-blacklist=',
        '--system-header-prefix',
    ]
    for prefix in skip_prefix_list:
        cflags = [i for i in cflags if not i.startswith(prefix)]

    cpp_args = []
    compiler_args = []

    # NVCC requires particular MSVC versions which may differ from the version
    # used to compile regular C++ code. We have a separate MSVC in Arcadia for
    # the CUDA builds and pass it's root in $Y_VC_Root.
    # The separate MSVC for CUDA may absent in Yandex Open Source builds.
    vc_root = os.environ.get('Y_VC_Root')

    cflags_queue = collections.deque(cflags)
    while cflags_queue:

        arg = cflags_queue.popleft()
        if arg[:2].upper() in ('-I', '/I', '-B'):
            value = arg[2:]
            if not value:
                value = cflags_queue.popleft()
            if arg[1] == 'I':
                cpp_args.append('-I{}'.format(value))
            elif arg[1] == 'B':  # todo: delete "B" flag check when cuda stop to use gcc
                pass
            continue

        match = re.match(r'[-/]D(.*)', arg)
        if match:
            define = match.group(1)
            # We have C++ flags configured for the regular C++ build.
            # There is Y_MSVC_INCLUDE define with a path to the VC header files.
            # We need to change the path accordingly when using a separate MSVC for CUDA.
            if vc_root and define.startswith('Y_MSVC_INCLUDE'):
                define = os.path.expandvars('Y_MSVC_INCLUDE={}/include'.format(vc_root))
            cpp_args.append('-D' + define.replace('\\', '/'))
            continue

        compiler_args.append(arg)

    command += cpp_args
    command += ['--compiler-options', ','.join(compiler_args)]

    if dump_args:
        sys.stdout.write('\n'.join(command))
    else:
        sys.exit(subprocess.Popen(command, stdout=sys.stderr, stderr=sys.stderr).wait())


if __name__ == '__main__':
    main()
