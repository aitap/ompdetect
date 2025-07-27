How do I detect OpenMP support in an R package?
===============================================

Most operating systems, including Linux and Windows
---------------------------------------------------

In your `Makevars`, set the `PKG_CFLAGS` and `PKG_LIBS` using the Make
macros described in [Writing R Extensions][WRE-OpenMP]. If the OpenMP
support was detected and enabled during R configuration, your package
will use a compatible OpenMP runtime. If not (e.g. disabled by system
administrator), it will not, so make sure to use `#ifdef _OPENMP` (or
other tests appropriate for your language).

macOS
-----

OpenMP isn't really supported by the Apple toolchain, but [with clever
hacks][mac-openmp] you can get it to work. R does not detect OpenMP
support by default, so the Make macros described above will be empty;
instead, the package must manually test for the unsupported compiler
flag `-Xclang -fopenmp` and add `-lomp` to the linker flags.

Nevertheless, starting with version 4.3, R for macOS provides an OpenMP
runtime and a way for packages to [opt into][SIG-Mac-Apr25] using it on
the CRAN package builder:

> the main part is to detect OpenMP even if R doesn't enable it
> (possibly as an option?) and on macOS also try `-Xclang` in front of
> the regular `-fopemp` to see if it works

This package demonstrates how to achieve that. It is important to test
multiple configurations on macOS to make sure that installing from
source in weird cases (e.g. custom toolchain that understands
`-fopenmp`) will still work.

Results
-------

### macOS ([macOS builder][mac-builder], R-release)

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
installing to /Volumes/PkgBuild/work/1753626598-edb8ae8f5c059434/packages/big-sur-arm64/results/4.5/ompdetect.Rcheck/00LOCK-ompdetect/00new/ompdetect/libs
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

### Windows ([Win-Builder], R-release)

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

### GNU/Linux (Debian Bookworm)

```
* installing *source* package ‘ompdetect’ ...
** using staged installation
Using CFLAGS=$(SHLIB_OPENMP_CFLAGS), LIBS=$(SHLIB_OPENMP_CFLAGS) for OpenMP
** libs
gcc -I"/usr/share/R/include" -DNDEBUG     -fopenmp -fpic  -g -O2 -ffile-prefix-map=/build/r-base-wZDgjM/r-base-4.2.2.20221110=. -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2  -c test_omp.c -o test_omp.o
gcc -shared -L/usr/lib/R/lib -Wl,-z,relro -o ompdetect.so test_omp.o -fopenmp -L/usr/lib/R/lib -lR
installing to REDACTED/ompdetect/ompdetect.Rcheck/00LOCK-ompdetect/00new/ompdetect/libs
```

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
[mac-builder]: https://mac.r-project.org/macbuilder/submit.html
[Win-Builder]: https://win-builder.r-project.org/
