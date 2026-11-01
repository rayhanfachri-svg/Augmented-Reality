#!python
import os

opts = Variables([], ARGUMENTS)

# Gets the standard flags CC, CCX, etc.
env = DefaultEnvironment()

# Define our options
opts.Add(EnumVariable('target', "Compilation target", 'debug', ['d', 'debug', 'r', 'release']))
opts.Add(EnumVariable('platform', "Compilation platform", '', ['', 'windows', 'x11', 'linux', 'osx', 'android']))
opts.Add(EnumVariable('p', "Compilation target, alias for 'platform'", '', ['', 'windows', 'x11', 'linux', 'osx', 'android']))
opts.Add(BoolVariable('use_llvm', "Use the LLVM / Clang compiler", 'no'))
opts.Add(PathVariable('target_path', 'The path where the lib is installed.', 'demo/bin/'))
# opts.Add(PathVariable('target_name', 'The library name.', 'libgdexample', PathVariable.PathAccept))
opts.Add(PathVariable('target_name', 'The library name.', 'libgdopencvexample', PathVariable.PathAccept))
# Android-only options (diisi builder; default aman bila tidak build untuk android).
opts.Add(PathVariable('android_abi', "Android ABI (arm64-v8a / armeabi-v7a)", 'arm64-v8a', PathVariable.PathAccept))
opts.Add(EnumVariable('android_api', "Android API level (>= 21)", '21', ['16','21','22','23','24','25','26','27','28','29','30','31','33']))
opts.Add(PathVariable('opencv_sdk', "OpenCV Android SDK (folder containing sdk/native)", '', PathVariable.PathAccept))

# Local dependency paths, adapt them to your setup
godot_headers_path = "godot-cpp/godot-headers/"
cpp_bindings_path = "godot-cpp/"
cpp_library = "libgodot-cpp"
cpp_lib_overridden = False  # set True hanya di cabang Android bila GODOT_CPP_ANDROID_LIB dipakai

# opencv include and libs dari pkg-config — DIISI setelah opts.Update (desktop only).
# Untuk Android, pakai OpenCV Android SDK (prebuilt .a) — lihat cabang android di bawah.
opencv_include = []
opencv_libs = []

# only support 64 at this time.. (arm64-v8a default; android cabang menimpa bits)
bits = 64

# Updates the environment with the option variables.
opts.Update(env)

# Process some arguments
if env['use_llvm']:
    env['CC'] = 'clang'
    env['CXX'] = 'clang++'

if env['p'] != '':
    env['platform'] = env['p']

if env['platform'] == '':
    print("No valid target platform selected.")
    quit();

# opencv include and libs from pkg-config — DESKTOP ONLY.
# (env['platform'] sudah terisi oleh opts.Update di atas.) Android memakai
# OpenCV Android SDK static libs (lihat cabang `android`).
if env['platform'] not in ('android', ''):
    opencv_include = os.popen("echo `pkg-config --cflags opencv4`").read().split()
    opencv_libs = os.popen("echo `pkg-config --libs opencv4`").read().split()
# print([p[2:] for p in opencv_include]); exit()
# print([opencv_libs[0][2:]]); exit()
# print([p[2:] for p in opencv_libs[1:]]); exit()

# For the reference:
# - CCFLAGS are compilation flags shared between C and C++
# - CFLAGS are for C-specific compilation flags
# - CXXFLAGS are for C++-specific compilation flags
# - CPPFLAGS are for pre-processor flags
# - CPPDEFINES are for pre-processor defines
# - LINKFLAGS are for linking flags

# Check our platform specifics
if env['platform'] == "osx":
    env['target_path'] += 'osx/'
    cpp_library += '.osx'
    env.Append(CCFLAGS=['-arch', 'x86_64'])
    env.Append(CXXFLAGS=['-std=c++17'])
    env.Append(LINKFLAGS=['-arch', 'x86_64'])
    if env['target'] in ('debug', 'd'):
        env.Append(CCFLAGS=['-g', '-O2'])
    else:
        env.Append(CCFLAGS=['-g', '-O3'])

elif env['platform'] in ('x11', 'linux'):
    env['target_path'] += 'x11/'
    cpp_library += '.linux'
    env.Append(CCFLAGS=['-fPIC'])
    env.Append(CXXFLAGS=['-std=c++17'])
    if env['target'] in ('debug', 'd'):
        env.Append(CCFLAGS=['-g3', '-Og'])
    else:
        env.Append(CCFLAGS=['-g', '-O3'])

elif env['platform'] == "windows":
    env['target_path'] += 'win64/'
    cpp_library += '.windows'
    # This makes sure to keep the session environment variables on windows,
    # that way you can run scons in a vs 2017 prompt and it will find all the required tools
    env.Append(ENV=os.environ)

    env.Append(CPPDEFINES=['WIN32', '_WIN32', '_WINDOWS', '_CRT_SECURE_NO_WARNINGS'])
    env.Append(CCFLAGS=['-W3', '-GR'])
    env.Append(CXXFLAGS='/std:c++17')
    if env['target'] in ('debug', 'd'):
        env.Append(CPPDEFINES=['_DEBUG'])
        env.Append(CCFLAGS=['-EHsc', '-MDd', '-ZI'])
        env.Append(LINKFLAGS=['-DEBUG'])
    else:
        env.Append(CPPDEFINES=['NDEBUG'])
        env.Append(CCFLAGS=['-O2', '-EHsc', '-MD'])

elif env['platform'] == "android":
    # ---- Cross-compile GDNative + OpenCV untuk Android via NDK clang ----
    # OpenCV DI-LINK STATIS ke .so hasil sehingga tidak perlu libopencv_*.so
    # terpisah di dalam APK (lihat [dependencies] di gd_opencv.gdnlib).
    env['target_path'] += 'android/' + env['android_abi'] + '/'
    cpp_library += '.android'

    # 1) NDK (wajib; dibaca dari env builder).
    ndk_root = os.environ.get('ANDROID_NDK_HOME') or os.environ.get('ANDROID_NDK_ROOT') or ''
    if not ndk_root:
        print("ERROR [android]: ANDROID_NDK_HOME / ANDROID_NDK_ROOT belum diset.")
        print("  export ANDROID_NDK_HOME=$HOME/Android/Sdk/ndk/<ver>")
        quit()
    prebuilt = 'linux-x86_64'
    toolchain = ndk_root + '/toolchains/llvm/prebuilt/' + prebuilt + '/bin/'
    if not os.path.isdir(toolchain):
        print("ERROR [android]: NDK prebuilt tidak ditemukan di: " + toolchain)
        quit()

    # Map ABI -> NDK triple + bits.
    if env['android_abi'] == 'arm64-v8a':
        triple = 'aarch64-linux-android'; bits = 64
    elif env['android_abi'] == 'armeabi-v7a':
        triple = 'armv7a-linux-androideabi'; bits = 32
    else:
        print("ERROR [android]: android_abi harus 'arm64-v8a' atau 'armeabi-v7a'.")
        quit()
    api = str(env['android_api'])
    env['CC']   = toolchain + triple + api + '-clang'
    env['CXX']  = toolchain + triple + api + '-clang++'
    env['AR']   = toolchain + 'llvm-ar'
    env['LINK'] = env['CXX']
    env.Append(ENV={'PATH': toolchain + ':' + os.environ.get('PATH','')})
    env.Prepend(ENV={'ANDROID_NDK_HOME': ndk_root})
    env.Append(CCFLAGS=['-fPIC', '-fexceptions'])
    env.Append(CXXFLAGS=['-std=c++17'])
    env.Append(LINKFLAGS=['-Wl,--build-id', '-Wl,--gc-sections'])

    # 2) godot-cpp static lib Android (hasil build di godot-cpp/). Nama:
    #    libgodot-cpp.android.<release|debug>.64(.a)
    gcpp_lib_path = cpp_bindings_path + 'bin/'
    gcpp_override = os.environ.get('GODOT_CPP_ANDROID_LIB', '')
    cpp_lib_overridden = False
    if gcpp_override:
        cpp_library = gcpp_override
        cpp_lib_overridden = True
    else:
        gcpp_file = gcpp_lib_path + 'libgodot-cpp.android.' + ('release' if env['target'] not in ('debug','d') else 'debug') + '.' + str(bits) + '.a'
        if not os.path.isfile(gcpp_file):
            print("ERROR [android]: libgodot-cpp Android tidak ditemukan: " + gcpp_file)
            print("  Build dulu:")
            print("    cd godot-cpp")
            print("    scons platform=android android_arch=" + ('arm64v8' if bits==64 else 'armv7') + " target=" + ('release' if env['target'] not in ('debug','d') else 'debug') + " -j$(nproc)")
            print("  atau override via: export GODOT_CPP_ANDROID_LIB=libgodot-cpp.android.release.64")
            quit()
    env.Append(LIBPATH=[gcpp_lib_path])
    # Note: LIBS append is deferred to line ~215 (after debug/release + bits
    # suffix is added to cpp_library).  Do NOT append cpp_library here —
    # doing so adds an incomplete library name (e.g. 'libgodot-cpp.android')
    # that the linker cannot resolve.

    # 3) OpenCV Android SDK — link STATIS (staticlibs) agar .so mandiri.
    ocv = os.environ.get('OPENCV_ANDROID_SDK', '') or env['opencv_sdk']
    if not ocv:
        print("ERROR [android]: OpenCV Android SDK belum ditentukan.")
        print("  Pakai: scons platform=android opencv_sdk=/path/to/OpenCV-android-sdk ...")
        print("  atau: export OPENCV_ANDROID_SDK=/path/to/OpenCV-android-sdk")
        quit()
    ocv_native = ocv if ocv.rstrip('/').endswith('sdk/native') else ocv.rstrip('/') + '/sdk/native'
    if not os.path.isdir(ocv_native):
        print("ERROR [android]: sdk/native OpenCV tidak ditemukan di: " + ocv_native)
        quit()
    staticlib_dir = ocv_native + '/staticlibs/' + env['android_abi']
    # OpenCV Android SDK menempatkan 3rdparty library di .../3rdparty/libs/<abi>/
    # (bukan .../3rdparty/<abi>/) — lihat struktur resmi SDK.
    thirdparty_dir = ocv_native + '/3rdparty/libs/' + env['android_abi']
    if not os.path.isdir(staticlib_dir):
        print("ERROR [android]: staticlibs tidak ditemukan di: " + staticlib_dir)
        print("  (SDK Anda mungkin tidak ship staticlibs; gunakan dynamic linking")
        print("   dan isi [dependencies] Android di gd_opencv.gdnlib — lihat .md)")
        quit()
    import glob as _g
    ocv_static = [os.path.basename(f)[:-2] for f in sorted(_g.glob(staticlib_dir + '/libopencv_*.a'))]
    ocv_third = [os.path.basename(f)[:-2] for f in sorted(_g.glob(thirdparty_dir + '/lib*.a'))]
    # Semua archive opencv + 3rdparty DIPAKSA masuk (whole-archive) dari path .a
    # penuh, sehingga semua simbol resolve (bukan -lname yang bisa skip member).
    ocv_paths = [staticlib_dir + '/' + n + '.a' for n in ocv_static] \
              + [thirdparty_dir + '/' + n + '.a' for n in ocv_third]
    env.Append(LIBS=['mediandk', 'log', 'android'])
    env.Append(LINKFLAGS=['-Wl,--whole-archive'] + ocv_paths + ['-Wl,--no-whole-archive'])
    sysroot = toolchain + '../sysroot'
    ocv_include = ocv_native + '/jni/include'
    env.Append(CPPPATH=[sysroot + '/usr/include', ocv_include])
    if env['target'] in ('debug', 'd'):
        env.Append(CCFLAGS=['-g', '-O0', '-DDEBUG'])
    else:
        env.Append(CCFLAGS=['-O2', '-DNDEBUG'])

else:
    # Desktop: prefix debug/release + bits di bawah.
    pass

# Suffix debug/release + bits (berlaku semua platform termasuk android).
# Skip jika nama library sudah lengkap via GODOT_CPP_ANDROID_LIB override.
if not cpp_lib_overridden:
    if env['target'] in ('debug', 'd'):
        cpp_library += '.debug'
    else:
        cpp_library += '.release'

    cpp_library += '.' + str(bits)

# make sure our binding library is properly includes
env.Append(CPPPATH=['.', godot_headers_path, cpp_bindings_path + 'include/', cpp_bindings_path + 'include/core/', cpp_bindings_path + 'include/gen/'])
env.Append(LIBPATH=[cpp_bindings_path + 'bin/'])
env.Append(LIBS=[cpp_library])

# append opencv_include and opencv_libs appropriately (DESKTOP ONLY).
# Untuk android, CPPPATH/LIBPATH/LIBS sudah di-set di cabang android di atas;
# guard ini mencegah IndexError bila opencv_libs kosong (android).
if opencv_libs:
    env.Append(CPPPATH=[p[2:] for p in opencv_include])
    env.Append(LIBPATH=[opencv_libs[0][2:]])
    env.Append(LIBS=[p[2:] for p in opencv_libs[1:]])
# print(env['CPPPATH'])
# print(env['LIBPATH'])
# print(env['LIBS'])
# exit()

# tweak this if you want to use different folders, or more folders, to store your source code in.
env.Append(CPPPATH=['src/'])
sources = Glob('src/*.cpp')

library = env.SharedLibrary(target=env['target_path'] + env['target_name'] , source=sources)

Default(library)

# Generates help for the -h scons option.
Help(opts.GenerateHelpText(env))
