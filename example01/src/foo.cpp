
#include <iostream>

#include "general.h"

#include "bar.hpp"

#ifndef TARGET_IF_FOO
#error "TARGET_IF_FOO is not defined."
#endif

#ifndef TARGET_PUB_FOO
#error "TARGET_PUB_FOO is not defined."
#endif

#ifndef TARGET_PRIV_FOO
#error "TARGET_PRIV_FOO is not defined."
#endif

int main(int argc, const char *argv[]) {
  std::cout << "Hello!\n";
  foo();

  return 0;
}

