#include <stdio.h>
#include <stdlib.h>

extern void _IAprintf (const char *format, ...);
extern void _IAprintf_flush ();

int main ()
{

	for (int i = 0; i < 100; ++i)
		_IAprintf(":), and I %s %x %d%%%c%b\n", "LOVE", 3802, 100, 33, 255);

	_IAprintf_flush();

	return 0;
}