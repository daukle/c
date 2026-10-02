#include <stdio.h>
#include "greet.h"

/* Every modelled key is load bearing here: std, defines and includeDirs each
   redden the compile if the plugin stops passing them, rather than quietly
   producing a different string. */
#if __STDC_VERSION__ != 201710L
#error "std did not reach the compiler"
#endif

#ifndef BUILT_BY_DAUKLE
#error "defines did not reach the compiler"
#endif

int main(void) {
  printf("%s\n", greeting());
  return 0;
}
