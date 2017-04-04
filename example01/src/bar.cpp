
#include <iostream>

#include "bar.hpp"
#include "bar_impl.hpp"

void foo() {
  using ::detail::g_bar_count;

  std::cout << "foo\n";

  return;
}


