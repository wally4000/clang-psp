#include <pspmoduleinfo.h>
#include <pspkernel.h>
#include <pspthreadman.h>

/* Default thread parameters for the main program thread. */
#define DEFAULT_THREAD_PRIORITY 32
#define DEFAULT_THREAD_ATTRIBUTE PSP_THREAD_ATTR_USER
#define DEFAULT_THREAD_STACK_KB_SIZE 256
#define DEFAULT_MAIN_THREAD_NAME "user_main"

/* If these variables are defined by the program, then they override the
   defaults given above. */
extern int sce_newlib_nocreate_thread_in_start __attribute__((weak));
extern unsigned int sce_newlib_priority __attribute__((weak));
extern unsigned int sce_newlib_attribute __attribute__((weak));
extern unsigned int sce_newlib_stack_kb_size __attribute__((weak));
extern const char*  sce_newlib_main_thread_name __attribute__((weak));

extern int main(int argc, char* argv[]);

int _module_main_thread(SceSize argc, void* argv){

    int retval = main(argc, argv);
	return retval;
}

/*
int module_start(int argc, char* argv[]){
	return main(argc, argv);
}*/


int module_start(int argc, char* argv[]){
	int (*myFunc)(SceSize argc, void* argv) = &_module_main_thread; 

	int priority = DEFAULT_THREAD_PRIORITY;
	unsigned int attribute = DEFAULT_THREAD_ATTRIBUTE;
	unsigned int stackSize = DEFAULT_THREAD_STACK_KB_SIZE * 1024;
	const char *threadName = DEFAULT_MAIN_THREAD_NAME;

	if (&sce_newlib_priority != NULL) {
		priority = sce_newlib_priority;
	}
	if (&sce_newlib_attribute != NULL) {
		attribute = sce_newlib_attribute;
	}
	if (&sce_newlib_stack_kb_size != NULL) {
		stackSize = sce_newlib_stack_kb_size * 1024;
	}
	if (&sce_newlib_main_thread_name != NULL) {
		threadName = sce_newlib_main_thread_name;
	}

	// Does the _main() thread belong to the User, VSH, or USB/WLAN APIs?
	if (attribute & (PSP_THREAD_ATTR_USER | PSP_THREAD_ATTR_USBWLAN | PSP_THREAD_ATTR_VSH)) {
		// Remove the kernel mode addressing from the pointer to _main().
		myFunc = (void *) ((u32) myFunc & 0x7fffffff);
	}

	SceUID thid = 0;
	thid = sceKernelCreateThread(threadName, &_module_main_thread, priority, stackSize, attribute, 0);
	sceKernelStartThread(thid, 0, 0);

    return 0;
}