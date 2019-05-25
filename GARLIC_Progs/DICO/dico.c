/*------------------------------------------------------------------------------

	"DICO.c" : programa de test;
				(versi�n 1.0)
  by Guillem Frisach Pedrola (guillem.frisach@estudiants.urv.cat/guillemfri@gmail.com)
  by Magí Tell (magi.tell@estudiants.urv.cat/mtellb@gmail.com)
  on 2018, Universitat Rovira i Virgili, Tarragona, Catalunya.

------------------------------------------------------------------------------*/

#include <GARLIC_API.h>			/* definici�n de las funciones API de GARLIC */


int array[400];

int _start(int arg)				/* funci�n de inicio : no se usa 'main' */
{
    GARLIC_printf(" Inici programa!\n");
	if (arg < 0) arg = 0;			// limitar valor m�ximo y
	else if (arg > 3) arg = 3;		// valor m�nimo del argumento
	unsigned int length = (arg+1)*100, rang, iter, y, x, i, z, min, max ,c, trobat;
	y=(arg+1)*4;
	rang=1;

	for (i=0; i<y;i++){
		rang*=2;
	}

	GARLIC_divmod(GARLIC_random(), rang, &i, &iter);
	iter++;							// asegurar que hay al menos una iteraci�n
	array[0] = iter;


	for (x=1;x<length;x++){
		GARLIC_divmod(GARLIC_random(), rang, &i, &iter);
		iter++;							// asegurar que hay al menos una iteraci�n
		array[x] = array[x-1]+iter;
	}
    

    for (i=0;i<20;i++){
        GARLIC_divmod(GARLIC_random(), array[length-1], &c, &x);

        if(i>16){
        GARLIC_divmod(GARLIC_random(), length, &c, &x);
        x=array[x];
        }
        min = 0;
        trobat=0;
        max=length;
    //comprovar si el valor de x esta dins del rang de la array
        if(array[0]>x || array[length-1]<x){
        }
        else{

            while (trobat==0){
                z=(min+max)/2;

                if (array[z]==x){trobat=1;}

                else if(array[z]>x){
                    if(array[z]>x && array[z-1]<x) trobat=-1;
                    max=z;
                    z=(min+max)/2;}

               else if (array[z]<x){
                    if(array[z]<x && array[z+1]>x) {z++;trobat=-1;}
                    min=z;
                    z=(min+max)/2;}

            }
        }
        if (trobat==1){
            GARLIC_printf("Trobat: %d a la pos %d\n", x, z+1);
        }
        else{
            GARLIC_printf("No trobat:%d->",x);
            GARLIC_printf("%d-%d\n", array[z-1], array[z]);
        }
    }
    GARLIC_printf("Dim array: 0 -> %d\n",array[length-1]);
    return 0;
}
