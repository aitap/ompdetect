How do I detect OpenMP support in an R package?
===============================================

It depends on the target operating system
-----------------------------------------

### Most operating systems, including Linux and Windows

In your `Makevars`, set the `PKG_CFLAGS` and `PKG_LIBS` using the Make
macros described in [Writing R Extensions][WRE-OpenMP]. If the OpenMP
support was detected and enabled during R configuration, your package
will use a compatible OpenMP runtime. If not (e.g. disabled by system
administrator), OpenMP support will be disabled, so make sure to use
`#ifdef _OPENMP` (or other tests appropriate for your language).

### macOS

OpenMP isn't really supported by the Apple toolchain, but [with clever
hacks][mac-openmp] you can get it to work. R does not detect OpenMP
support by default, so the Make macros described above will be empty.

Nevertheless, starting with version 4.3, R for macOS provides an OpenMP
runtime and a way for packages to [opt into][SIG-Mac-Apr25] using it on
the CRAN package builder:

> the main part is to detect OpenMP even if R doesn't enable it
> (possibly as an option?) and on macOS also try `-Xclang` in front of
> the regular `-fopenmp` to see if it works

(In addition to testing for `-Xclang -fopenmp`, the package also needs
to link to the OpenMP runtime using the `-lomp` linker flag.)

This package demonstrates how to achieve that. It is important to test
multiple configurations on macOS to make sure that installing from
source in weird cases (e.g. custom toolchain that understands
`-fopenmp`) will still work.

As of 2025, newer Xcode versions conflict with the OpenMP runtime
shipped with R. Use `schedule(dynamic)` to [check for it][datatable7318]
and avoid accidentally building a package shared library that will later
fail to load. Installing a [different version of the OpenMP
runtime][mac-openmp] breaks compatibility with CRAN binaries, so it's up
to the administrator to set `SHLIB_OPENMP_CFLAGS = -Xclang -fopenmp
-Wl,/usr/local/lib/libomp.dylib` (untested) and compile all packages
from source.

Contents
--------

### `src/Makevars.win`

Adds `$(SHLIB_OPENMP_CFLAGS)` to the compiler and linker flags on
Windows. R will warn about the package having a `configure` script for
Unix-alikes but not for Windows, but we already have `src/Makevars.win`
pre-configured.

See [WRE 1.1.5 Package subdirectories][WRE-package-subdirectories] for
more information.

### `configure`

On Unix-alikes, [`configure`][WRE-configure] is required to be a POSIX
shell script. In theory, it could [immediately delegate to an R
script][Kevin-Ushey-configure], but we will only use it for
compile-testing; the rest of the script is more laconic when written in
POSIX `sh`.

A good `configure` leaves a `config.log` with detailed information for
debugging. POSIX `echo` is not guaranteed to understand `-n` or escape
characters, so we'll use `printf` instead.

On macOS (whose `uname` calls it "Darwin"), we call the compile-test
function with different arguments, until one succeeds, or until we reach
the last case, which leaves the OpenMP variables empty. On other
operating systems, we rely on R-provided flags unconditionally.

The compile-test function runs R in order to `dyn.load()` the resulting
shared library and run code from it. It tests the OpenMP support as
completely as it can:

1. Call `R CMD SHLIB` to compile and link a shared library from the test
   C file.
2. Load the resulting shared library and run an OpenMP loop from it.

This aims to trigger all of compilation-time, linking-time,
loading-time, and runtime problems before they prevent the real package
from being installed.

The last step is the [autotools]-style text replacement that takes the
`src/Makevars.in` file and creates the `src/Makevars` from it for
`R CMD SHLIB` to consume.

### `src/Makevars.in`

This prototype for `src/Makevars` contains templates for compiler and
linker flags that the `configure` script will substitute.

### `cleanup`

[For best results][WRE-configure], `configure` should be paired with a
`cleanup` script, which removes all files that `configure` may have
created, although it's prudent to also list them in `.Rbuildignore`. In
our case, these files are `src/Makevars` and `config.log`.

Bonus points: passing through `PKG_CFLAGS`, `PKG_LIBS`
------------------------------------------------------

The [OpenMP on macOS][mac-openmp] page recommends:

> How you do the latter depends on the package, but if the package does not set
> these environment variables itself, you can try
>
>     PKG_CPPFLAGS='-Xclang -fopenmp' PKG_LIBS=-lomp R CMD INSTALL myPackage

Since our `Makevars` file sets `PKG_CPPFLAGS` and `PKG_LIBS`, Make won't
read them from the environment. Solution: read them in the `configure`
script and write them into `Makevars`, in addition to other variables
being set, using the same string substitution as the OpenMP flags. For
maximum compatibility, test a configuration with no added compiler or
linker flags, making it possible for the user to override OpenMP
configuration.

Results
-------

### macOS 13.3.1, R-4.5.1 ([macOS builder][mac-builder], R-release)

```
* installing *source* package ‘ompdetect’ ...
** this is package ‘ompdetect’ version ‘0.0-1’
** using staged installation
Guessing OpenMP configuration for macOS
* checking if OpenMP works with CFLAGS=$(SHLIB_OPENMP_CFLAGS) LIBS=$(SHLIB_OPENMP_CFLAGS)... no
* checking if OpenMP works with CFLAGS=-Xclang -fopenmp LIBS=-lomp... yes
Using CFLAGS=-Xclang -fopenmp, LIBS=-lomp for OpenMP
** libs
using C compiler: ‘Apple clang version 14.0.3 (clang-1403.0.22.14.1)’
using SDK: ‘MacOSX11.3.1.sdk’
clang -arch arm64 -std=gnu2x -I"/Library/Frameworks/R.framework/Resources/include" -DNDEBUG   -I/opt/R/arm64/include   -Xclang -fopenmp -fPIC  -falign-functions=64 -Wall -g -O2  -c test_omp.c -o test_omp.o
clang -arch arm64 -std=gnu2x -dynamiclib -Wl,-headerpad_max_install_names -undefined dynamic_lookup -L/Library/Frameworks/R.framework/Resources/lib -L/opt/R/arm64/lib -o ompdetect.so test_omp.o -lomp -F/Library/Frameworks/R.framework/.. -framework R
installing to /Volumes/PkgBuild/work/1753992069-04991d62b5bd56d6/packages/big-sur-arm64/results/4.5/ompdetect.Rcheck/00LOCK-ompdetect/00new/ompdetect/libs
```

```
> ### ** Examples
>
>   ompdetect()
OpenMP detected and working.
>   omplimits()
thread_limit  max_threads    num_procs
  2147483647            8            8
```

### Windows, R-4.5.1 ([Win-Builder], R-release)

```
* installing *source* package 'ompdetect' ...
** this is package 'ompdetect' version '0.0-1'
** using staged installation

   **********************************************
   WARNING: this package has a configure script
         It probably needs manual configuration
   **********************************************


** libs
using C compiler: 'gcc.exe (GCC) 14.2.0'
gcc  -I"D:/RCompile/recent/R-4.5.1/include" -DNDEBUG     -I"d:/rtools45/x86_64-w64-mingw32.static.posix/include"   -fopenmp   -pedantic -Wstrict-prototypes -O2 -Wall -std=gnu2x  -mfpmath=sse -msse2 -mstackrealign   -c test_omp.c -o test_omp.o
gcc -shared -s -static-libgcc -o ompdetect.dll tmp.def test_omp.o -fopenmp -Ld:/rtools45/x86_64-w64-mingw32.static.posix/lib/x64 -Ld:/rtools45/x86_64-w64-mingw32.static.posix/lib -LD:/RCompile/recent/R-4.5.1/bin/x64 -lR
installing to d:/RCompile/CRANguest/R-release/lib/00LOCK-ompdetect/00new/ompdetect/libs/x64
```

```
> ### ** Examples
>
>   ompdetect()
OpenMP detected and working.
>   omplimits()
thread_limit  max_threads    num_procs
           2           48           48
```

### GNU/Linux, R-4.2.2 (Debian Bookworm)

```
* installing *source* package ‘ompdetect’ ...
** using staged installation
Using CFLAGS=$(SHLIB_OPENMP_CFLAGS), LIBS=$(SHLIB_OPENMP_CFLAGS) for OpenMP
** libs
make[1]: Entering directory 'REDACTED/ompdetect.Rcheck/00_pkg_src/ompdetect/src'
gcc -I"/usr/share/R/include" -DNDEBUG     -fopenmp -fpic  -g -O2 -ffile-prefix-map=/build/r-base-wZDgjM/r-base-4.2.2.20221110=. -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2  -c test_omp.c -o test_omp.o
gcc -shared -L/usr/lib/R/lib -Wl,-z,relro -o ompdetect.so test_omp.o -fopenmp -L/usr/lib/R/lib -lR
make[1]: Leaving directory 'REDACTED/ompdetect.Rcheck/00_pkg_src/ompdetect/src'
make[1]: Entering directory 'REDACTED/ompdetect.Rcheck/00_pkg_src/ompdetect/src'
make[1]: Leaving directory 'REDACTED/ompdetect.Rcheck/00_pkg_src/ompdetect/src'
installing to REDACTED/ompdetect.Rcheck/00LOCK-ompdetect/00new/ompdetect/libs
```

```
> ### ** Examples
>
>   ompdetect()
OpenMP detected and working.
>   omplimits()
thread_limit  max_threads    num_procs
  2147483647            8            8
```

### GNU/Linux, R-devel, (OpenMP disabled)

This can be achieved by configuring R with `--disable-openmp`.

```
* installing *source* package ‘ompdetect’ ...
** this is package ‘ompdetect’ version ‘0.0-1’
** using staged installation
Using CFLAGS=$(SHLIB_OPENMP_CFLAGS), LIBS=$(SHLIB_OPENMP_CFLAGS) for OpenMP
** libs
using C compiler: ‘gcc (Debian 12.2.0-14+deb12u1) 12.2.0’
make[1]: Entering directory 'REDACTED/ompdetect.Rcheck/00_pkg_src/ompdetect/src'
gcc -I"REDACTED/R-devel/include" -DNDEBUG   -I/usr/local/include    -fpic  -g -O2  -c test_omp.c -o test_omp.o
gcc -shared -L/usr/local/lib -o ompdetect.so test_omp.o
make[1]: Leaving directory 'REDACTED/ompdetect.Rcheck/00_pkg_src/ompdetect/src'
make[1]: Entering directory 'REDACTED/ompdetect.Rcheck/00_pkg_src/ompdetect/src'
make[1]: Leaving directory 'REDACTED/ompdetect.Rcheck/00_pkg_src/ompdetect/src'
installing to REDACTED/ompdetect.Rcheck/00LOCK-ompdetect/00new/ompdetect/libs
```

```
> ### ** Examples
>
>   ompdetect()
OpenMP not detected.
>   omplimits()
thread_limit  max_threads    num_procs
          -1           -1           -1
```

### OpenBSD 7.7, R-4.4.2

OpenMP [is not supported on OpenBSD](https://j-bm.github.io/on/onp.html).

```
* installing *source* package 'ompdetect' ...
** using staged installation
Using CFLAGS=$(SHLIB_OPENMP_CFLAGS), LIBS=$(SHLIB_OPENMP_CFLAGS) for OpenMP
** libs
using C compiler: 'OpenBSD clang version 16.0.6'
cc -I"/usr/local/lib/R/include" -DNDEBUG   -I/usr/local/include    -fpic  -O2 -pipe  -c test_omp.c -o test_omp.o
cc -shared -fPIC -L/usr/local/lib/R/lib -L/usr/local/lib -Wl,-R/usr/local/lib/R/lib -o ompdetect.so test_omp.o -L/usr/local/lib/R/lib -lR
installing to REDACTED/ompdetect.Rcheck/00LOCK-ompdetect/00new/ompdetect/libs
```

```
> ### ** Examples
>
>   ompdetect()
OpenMP not detected.
>   omplimits()
thread_limit  max_threads    num_procs
          -1           -1           -1
```

### FreeBSD 13.4, R-4.5.1

As of this writing, `data.table`'s `configure` script fails to detect
both OpenMP and `zlib` on FreeBSD.

```
* installing *source* package ‘ompdetect’ ...
** this is package ‘ompdetect’ version ‘0.0-1’
** using staged installation
Using CFLAGS=$(SHLIB_OPENMP_CFLAGS), LIBS=$(SHLIB_OPENMP_CFLAGS) for OpenMP
** libs
using C compiler: ‘FreeBSD clang version 19.1.7 (https://github.com/llvm/llvm-project.git llvmorg-19.1.7-0-gcd708029e0b2)’
cc -std=gnu23 -I"/usr/local/lib/R/include" -DNDEBUG   -DLIBICONV_PLUG -I/usr/local/include -isystem /usr/local/include   -fopenmp -fpic  -O2 -pipe  -DLIBICONV_PLUG -fstack-protector-strong -isystem /usr/local/include -fno-strict-aliasing   -c test_omp.c -o test_omp.o
cc -std=gnu23 -shared -L/usr/local/lib/R/lib -Wl,-rpath=/usr/local/lib/gcc13 -L/usr/local/lib/gcc13 -L/usr/local/lib -fstack-protector-strong -o ompdetect.so test_omp.o -fopenmp -L/usr/local/lib/R/lib -lR
installing to REDACTED/ompdetect.Rcheck/00LOCK-ompdetect/00new/ompdetect/libs
```

```
> ### ** Examples
>
>   ompdetect()
OpenMP detected and working.
>   omplimits()
thread_limit  max_threads    num_procs
  2147483647            1            1
```

### GNU/Linux, R-3.0.0

```
* installing *source* package ‘ompdetect’ ...
Using CFLAGS=$(SHLIB_OPENMP_CFLAGS), LIBS=$(SHLIB_OPENMP_CFLAGS) for OpenMP
** libs
gcc -IREDACTED/R-3.0.0/include -DNDEBUG  -I/usr/local/include   -fopenmp -fpic  -fcommon  -c test_omp.c -o test_omp.o
gcc -shared -L/usr/local/lib -o ompdetect.so test_omp.o -fopenmp
installing to REDACTED/ompdetect.Rcheck/ompdetect/libs
```

```
> ### ** Examples
>
>   ompdetect()
OpenMP detected and working.
>   omplimits()
thread_limit  max_threads    num_procs
  2147483647           16           16
```

### Windows, R-3.4.4

```
* installing *source* package 'ompdetect' ...

   **********************************************
   WARNING: this package has a configure script
         It probably needs manual configuration
   **********************************************


** libs

*** arch - i386
c:/Rtools/mingw_32/bin/gcc  -I"C:/PROGRA~1/R/R-34~1.4/include" -DNDEBUG       -fopenmp   -O3 -Wall  -std=gnu99 -mtune=generic -c test_omp.c -o test_omp.o
c:/Rtools/mingw_32/bin/g++ -shared -s -static-libgcc -o ompdetect.dll tmp.def test_omp.o -fopenmp -LC:/PROGRA~1/R/R-34~1.4/bin/i386 -lR
installing to C:/Users/User/ompdetect.Rcheck/ompdetect/libs/i386

*** arch - x64
c:/Rtools/mingw_64/bin/gcc  -I"C:/PROGRA~1/R/R-34~1.4/include" -DNDEBUG       -fopenmp   -O2 -Wall  -std=gnu99 -mtune=generic -c test_omp.c -o test_omp.o
c:/Rtools/mingw_64/bin/g++ -shared -s -static-libgcc -o ompdetect.dll tmp.def test_omp.o -fopenmp -LC:/PROGRA~1/R/R-34~1.4/bin/x64 -lR
installing to C:/Users/User/ompdetect.Rcheck/ompdetect/libs/x64
```

(examples are same for `i386` and `x64` cases)

```
> ### ** Examples
>
>   ompdetect()
OpenMP detected and working.
>   omplimits()
thread_limit  max_threads    num_procs
  2147483647            4            4
```

[WRE-OpenMP]: https://cran.r-project.org/doc/manuals/R-exts.html#OpenMP-support
[mac-openmp]: https://mac.r-project.org/openmp/
[SIG-Mac-Apr25]: https://stat.ethz.ch/pipermail/r-sig-mac/2025-April/015189.html
[datatable7318]: https://github.com/Rdatatable/data.table/pull/7318#issuecomment-3311861544
[WRE-package-subdirectories]: https://cran.r-project.org/doc/manuals/R-exts.html#Package-subdirectories
[WRE-configure]: https://cran.r-project.org/doc/manuals/R-exts.html#Configure-and-cleanup
[Kevin-Ushey-configure]: https://github.com/kevinushey/configure
[autotools]: https://autotools.info/
[mac-builder]: https://mac.r-project.org/macbuilder/submit.html
[Win-Builder]: https://win-builder.r-project.org/
