#include <stdio.h>
#include "greet.h"

/* The point of this example is WHICH compiler ran, so it asserts that rather
   than that one did. clang defines __GNUC__ too, so only its absence tells the
   two apart, and the major version proves the release the registry pinned is
   the release that executed. Without these the example would pass just as well
   with the compiler key ignored. */
#if defined(__clang__)
#error "compiler = gcc did not select gcc"
#endif

#if !defined(__GNUC__) || __GNUC__ != 15
#error "the pinned gcc release is not the one that ran"
#endif

int main(void)
{
  printf("%s\n", greeting());
  return 0;
}
