/*------------------------------------------------------------------------------

	"garlic_mem.c" : fase 2 / programador M

	Funciones de carga de un fichero ejecutable en formato ELF, para GARLIC 2.0

------------------------------------------------------------------------------*/
#include <nds.h>
#include <filesystem.h>
#include <dirent.h>			// para struct dirent, etc.
#include <stdio.h>			// para fopen(), fread(), etc.
#include <stdlib.h>			// para malloc(), etc.
#include <string.h>			// para strcat(), memcpy(), etc.

#include <garlic_system.h>	// definici�n de funciones y variables de sistema

#define INI_MEM_PROC	0x01002000		// direcci�n de inicio de memoria de los
										// procesos de usuario

typedef unsigned short int Elf32_Half;
typedef unsigned int Elf32_Word;
typedef int Elf32_Sword;
typedef unsigned int Elf32_Off;
typedef unsigned int Elf32_Addr;

#define EI_NIDENT 16

typedef struct {
	unsigned char e_ident[EI_NIDENT];
	Elf32_Half e_type;
	Elf32_Half e_machine;
	Elf32_Word e_version;
	Elf32_Addr e_entry;
	Elf32_Off e_phoff;
	Elf32_Off e_shoff;
	Elf32_Word e_flags;
	Elf32_Half e_ehsize;
	Elf32_Half e_phentsize;
	Elf32_Half e_phnum;
	Elf32_Half e_shentsize;
	Elf32_Half e_shnum;
	Elf32_Half e_shstrndx;
} Elf32_Ehdr;

typedef struct {
	Elf32_Word p_type;
	Elf32_Off p_offset;
	Elf32_Addr p_vaddr;
	Elf32_Addr p_paddr;
	Elf32_Word p_filesz;
	Elf32_Word p_memsz;
	Elf32_Word p_flags;
	Elf32_Word p_align;
} Elf32_Phdr;

typedef struct {
	Elf32_Word sh_name;
	Elf32_Word sh_type;
	Elf32_Word sh_flags;
	Elf32_Addr sh_addr;
	Elf32_Off sh_offset;
	Elf32_Word sh_size;
	Elf32_Word sh_link;
	Elf32_Word sh_info;
	Elf32_Word sh_addralign;
	Elf32_Word sh_entsize;
} Elf32_Shdr;

/* _gm_initFS: inicializa el sistema de ficheros, devolviendo un valor booleano
					para indiciar si dicha inicializaci�n ha tenido �xito; */
int _gm_initFS()
{
	return nitroFSInit(NULL);	// inicializar sistema de ficheros NITRO
}


/* _gm_listaProgs: devuelve una lista con los nombres en clave de todos
			los programas que se encuentran en el directorio "Programas".
			 Se considera que un fichero es un programa si su nombre tiene
			8 caracteres y termina con ".elf"; se devuelven s�lo los
			4 primeros caracteres de los programas (nombre en clave).
			 El resultado es un vector de strings (paso por referencia) y
			el n�mero de programas detectados */
int _gm_listaProgs(char* progs[])
{
	DIR* pdir = opendir("/Programas/");			// Obrir directori dels programes
	int i = 0;						
	int j = 0;
	struct dirent* pent;
	
	if (pdir != NULL) // Si existeix la carpeta
	{ 
		while((pent = readdir(pdir)) != NULL) //mentres hi hagi alguna cosa al directori
		{ 
			if(strcmp(".", pent->d_name) != 0 && strcmp("..", pent->d_name) != 0 && (strlen(pent->d_name) == 8)) //ignorem "." i ".." i a mes mirem que la longitud del nom sigui 8 (4-nom + 4-".elf")
			{
				if(pent->d_type != DT_DIR) // Si no és un directori
				{
					progs[i] = malloc(4);  //reservar espai a memoria
					
					for(j = 0; j < 4; j++) 
					{					
						progs[i][j] = pent->d_name[j];
					}
					progs[i][4] = '\0';						// Marquem el final de l'string
					i++;
				}
			}
		}
		closedir(pdir);
	}
	return i;
}


/* _gm_cargarPrograma: busca un fichero de nombre "(keyName).elf" dentro del
				directorio "/Programas/" del sistema de ficheros, y carga los
				segmentos de programa a partir de una posici�n de memoria libre,
				efectuando la reubicaci�n de las referencias a los s�mbolos del
				programa, seg�n el desplazamiento del c�digo y los datos en la
				memoria destino;
	Par�metros:
		zocalo	->	�ndice del z�calo que indexar� el proceso del programa
		keyName ->	vector de 4 caracteres con el nombre en clave del programa
	Resultado:
	,   != 0	->	direcci�n de inicio del programa (intFunc)
		== 0	->	no se ha podido cargar el programa
*/
intFunc _gm_cargarPrograma(int zocalo, char *keyName)
{
	
	char nomFitxer[20] = "/Programas/"; // Carpeta on es situaran els programes

	int i, j=0, len, phNum;
	unsigned int resultat = 0;
	char *entireFile;
	intFunc iniciMemCode = 0, iniciMemData = 0;
	FILE* fitxer;

	Elf32_Ehdr *elfHdr;
	Elf32_Phdr *elfPhdr;
	Elf32_Addr addressCodeSegment = 0;	// Direccio de memoria inicial del segment de codi
	Elf32_Off offsetCodeSegment = 0;	// Offset del segment de codi
	Elf32_Word fileSizeCodeSegment = 0;	// Mida del segment de codi al fitxer
	Elf32_Word memSizeCodeSegment = 0;	// Mida del segment de codi a memoria
	Elf32_Addr addressDataSegment = 0;	// Direccio de memoria inicial del segment de dades
	Elf32_Off offsetDataSegment = 0;	// Offset del segment de dades
	Elf32_Word fileSizeDataSegment = 0;	// Mida del segment de dades al fitxer
	Elf32_Word memSizeDataSegment = 0;	// Mida del segment de dades a memoria
	Elf32_Word flagsSegment = 0;		// Flags del segment
	

	// Afegim el nom del programa
	for (i=11; i<15; i++) 
	{
		nomFitxer[i] = keyName[j];
		j++;
	}

	// Afegim l'extensiu del programa (.elf)
	nomFitxer[15] = '.';
	nomFitxer[16] = 'e';
	nomFitxer[17] = 'l';
	nomFitxer[18] = 'f';
	nomFitxer[19] = '\0';


	fitxer = fopen(nomFitxer,"rb"); // Intentem obrir el programa
	
	if (fitxer) //si s'ha obert algun fitxer
	{		

		// Obtenir la mida del programa
		fseek(fitxer,0,SEEK_END);	// Ens desplacem fins al final del programa
		len = ftell(fitxer);		// Obtenim la longitud del programa
		fseek(fitxer,0,SEEK_SET);	// Ens desplacem fins a l'inici del programa

		// Carguem el programa dins d'un buffer de memoria dinamica
		entireFile = (char*)malloc(len+1); 	// Reservem la memoria dinamica

		// Llegim les dades (punter al bloc de memoria, mida de cada element, numero d'elements, punter al fitxer)
		if(fread(entireFile,1,len,fitxer) == len) // Si la quantitat de dades llegides coincideixen, ha anat tot be
		{ 	

			// Accedim a la capealera ELF
			elfHdr = (Elf32_Ehdr *)entireFile;
			phNum = elfHdr->e_phnum;			// Obtenim el numero d'entrades de la taula de segments


			// Ens desplacem fins la taula de segments
			elfPhdr = (Elf32_Phdr *)(entireFile + elfHdr->e_phoff);

			while(phNum > 0) // Mirem tots els segments
			{					
				flagsSegment = elfPhdr->p_flags;	// Obtenim els flags del segment

				if (elfPhdr->p_type == 1) // Comprovem si el es del tipus PT_LOAD
				{		
					flagsSegment = elfPhdr->p_flags;	// Obtenim els flags del segment

					// Segment de codi
					if (flagsSegment == 5) 
					{
						addressCodeSegment = elfPhdr->p_paddr;		// Obtenim la direccio de memoria inicial del segment
						offsetCodeSegment = elfPhdr->p_offset;		// Obtenim l'offset del segment
						fileSizeCodeSegment = elfPhdr->p_filesz;	// Obtenim la mida del segment al fitxer
						memSizeCodeSegment = elfPhdr->p_memsz;		// Obtenim la mida del segment a memoria
						
						// Carreguem el contingut del segment a partir d'una direccio de memoria desti apropiada
						iniciMemCode = (intFunc)_gm_reservarMem(zocalo, memSizeCodeSegment, 0);
						
						if (iniciMemCode == 0) return 0;
						
						_gs_copiaMem(entireFile + offsetCodeSegment, (void *)iniciMemCode, (unsigned int) fileSizeCodeSegment); // (posicio de memoria inicial, posicio de memoria desti, numero de bytes)
					}
					
					// Segment de dades
					else if (flagsSegment == 6) 
					{
						addressDataSegment = elfPhdr->p_paddr;		// Obtenim la direccio de memoria inicial del segment
						offsetDataSegment = elfPhdr->p_offset;		// Obtenim l'offset del segment
						fileSizeDataSegment = elfPhdr->p_filesz;	// Obtenim la mida del segment al fitxer
						memSizeDataSegment = elfPhdr->p_memsz;		// Obtenim la mida del segment a memoria
						
						// Carreguem el contingut del segment a partir d'una direccio de memoria desti apropiada
						iniciMemData = (intFunc)_gm_reservarMem(zocalo, memSizeDataSegment, 1);
						
						// Cas en que hi ha espai per al segment de codi pero no per al de dades
						if(iniciMemCode != 0 && iniciMemData == 0) {
							_gm_liberarMem(zocalo);
						}
						
						if (iniciMemData == 0) return 0;
						
						_gs_copiaMem(entireFile + offsetDataSegment, (void *)iniciMemData, (unsigned int) fileSizeDataSegment); // (posicio de memoria inicial, posicio de memoria desti, numero de bytes)
					}
				}
				elfPhdr = (Elf32_Phdr *) (elfPhdr + 1);
				phNum--;
			}
			// Efectuar la reubicacio de totes les posicions sensibles
			_gm_reubicar(entireFile,(unsigned int) addressCodeSegment,(unsigned int *) iniciMemCode, (unsigned int) addressDataSegment,(unsigned int *) iniciMemData);		// (direcci� inicial del buffer, direcci� inici segment, direcci� dest� en la mem�ria (x2))

			// Retornar direcci� d'inici del programa
			resultat = elfHdr->e_entry;	// Obtenim l'adre�a de l'entrada e_entry
			resultat -= addressCodeSegment;
			resultat += (int)iniciMemCode;
		}

		free(entireFile);	// Alliberem la memoria reservada abans
		fclose(fitxer);		// Tanquem el fitxer


	}

	return (intFunc)resultat;
}

