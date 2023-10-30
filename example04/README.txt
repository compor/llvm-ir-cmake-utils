# Instrumenting an static library

```sh
mkdir build && cd build
cmake ..
make testlib_instrumented
make main
./executable/main
```