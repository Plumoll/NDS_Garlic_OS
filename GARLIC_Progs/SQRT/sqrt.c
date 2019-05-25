/*------------------------------------------------------------------------------

	"SQRT.c" : programa de prueba para el sistema operativo GARLIC 1.0
			   busqueda de la raíz cuadrada de manera dicotómica;
	
  by Guillem Frisach Pedrola (guillem.frisach@estudiants.urv.cat/guillemfri@gmail.com)
  by Magí Tell (magi.tell@estudiants.urv.cat/mtellb@gmail.com)
  on 2018, Universitat Rovira i Virgili, Tarragona, Catalunya.

------------------------------------------------------------------------------*/

#include <GARLIC_API.h>			/* definici�n de las funciones API de GARLIC */

int _start(int arg)				/* funci�n de inicio : no se usa 'main' */
{
	unsigned int i, j,random_dividit, m, val_aleat, z, max,min,trobat,x;

	random_dividit = 0;
	m = 0;
	j = 0;
	trobat = 0;
	z = 0;
	min = 1;
	max = 0;

	if (arg < 0) arg = 0;			// limitar valor m�ximo y
	else if (arg > 3) arg = 3;		// valor m�nimo del argumento

									// esccribir mensaje inicial
	GARLIC_printf("-- SQRT() PER TANTEIG  -  PID (%d) --\n", GARLIC_pid());
	random_dividit=0;
	val_aleat=0;

	GARLIC_divmod(GARLIC_random()*(arg+1),10000,&random_dividit,&val_aleat);
	max = val_aleat;
	x = max;
	
	 while (trobat==0)
	 {
                z=(min+max)/2;
				GARLIC_printf("(%d)\tS'ha provat amb %d\n", GARLIC_pid(), z);
				
				
                if (z*z==x){trobat=1;}

                else if(z*z>x){
                    if((z-1)*(z-1)<x) trobat=1;
                    max=z;
                    z=(min+max)/2;}

               else if (z*z<x){
                    if((z+1)*(z+1)>x) {z++;trobat=1;}
                    min=z;
                    z=(min+max)/2;}
				GARLIC_delay(arg);
     }
	

	GARLIC_divmod(z, 10, &j, &i);
	GARLIC_divmod(val_aleat, 100, &random_dividit, &m);

	GARLIC_printf("\tL'arrel de %d,%d es aprox.", random_dividit,m);
	GARLIC_printf(" %d,%d\n", j, i);

	return 0;
}
