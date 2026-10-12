#include <stdio.h>
#include "greet.h"

/* The selection is what this case proves, so the assertion is about WHICH
   compiler ran rather than that one did. clang defines __GNUC__ too, so only
   its absence tells the two apart, and the major version proves the release
   the registry pinned is the release that executed. */
#if defined(__clang__)
#error "compiler did not select gcc"
#endif

#if !defined(__GNUC__) || __GNUC__ != 15
#error "the pinned gcc release is not the one that ran"
#endif

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
