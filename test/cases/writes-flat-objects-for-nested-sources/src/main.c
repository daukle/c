#include <stdio.h>

int top(void);
int nested(void);

int main(void) {
  printf("%d\n", top() + nested());
  return 0;
}
