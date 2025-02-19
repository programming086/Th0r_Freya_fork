//
//  utils.h
//  electra
//
//  Created by Jamie on 27/01/2018.
//  Copyright © 2018 Electra Team. All rights reserved.
//

#ifndef utils_h
#define utils_h
#import <sys/types.h>
#import <sys/stat.h>
#include <stdio.h>
#include <stdbool.h>

#include <stddef.h>
#include <stdint.h>

#define showMSG(msg, wait, destructive) showAlert(@"freya", msg, wait, destructive)
#define showPopup(msg, wait, destructive) showThePopup(@"", msg, wait, destructive)
#define __FILENAME__ (__builtin_strrchr(__FILE__, '/') ? __builtin_strrchr(__FILE__, '/') + 1 : __FILE__)
#define _assert(test, message, fatal) do \
if (!(test)) { \
int saved_errno = errno; \
LOG("__assert(%d:%s)@%s:%u[%s]", saved_errno, #test, __FILENAME__, __LINE__, __FUNCTION__); \
} \
while (false)

const char *userGenerator(void);
const char *genToSet(void);
#define K_GENERATOR "generator"
#define K_freya_GENERATOR "0x1111111111111111"

void xFinishFailed(void);

void util_hexprint(void *data, size_t len, const char *desc);
void util_hexprint_width(void *data, size_t len, int width, const char *desc);
void util_nanosleep(uint64_t nanosecs);
void util_msleep(unsigned int ms);
_Noreturn void fail_info(const char *info);
void fail_if(bool cond, const char *fmt, ...)  __printflike(2, 3);
//void move_in_jbResources();
// don't like macro
void util_debug(const char *fmt, ...) __printflike(1, 2);
void util_info(const char *fmt, ...) __printflike(1, 2);
void util_warning(const char *fmt, ...) __printflike(1, 2);
void util_error(const char *fmt, ...) __printflike(1, 2);
void util_printf(const char *fmt, ...) __printflike(1, 2);

//int util_runCommand(const char *cmd, ...);
typedef struct {
    uint64_t key;
    uint64_t value;
} dict_entry_t;

uint64_t lookup_key_in_dicts(dict_entry_t *dict, uint32_t count, uint64_t key);

#ifdef MAINAPP
void iterate_keys_in_dict(dict_entry_t *os_dict_entries, uint32_t count, void (^callback)(uint64_t key, uint64_t value));
#endif

bool isArm64e(void);
uint64_t rk64ptr(uint64_t where);
uint64_t signPtr(uint64_t data, uint64_t key);
uint64_t getFp(arm_thread_state64_t state);
uint64_t getLr(arm_thread_state64_t state);
uint64_t getSp(arm_thread_state64_t state);
uint64_t getPc(arm_thread_state64_t state);
uint64_t findSymbol(const char *symbol);
void setLr(arm_thread_state64_t *state, uint64_t lr);
void setPc(arm_thread_state64_t *state, uint64_t pc);
void amfid_test(mach_port_t amfid_port);


void preMountFS(const char *thedisk, int root_fs, const char **snapshots, const char *origfs);

bool is_mountpoint(const char *filename);
//int run(const char *cmd);
char* itoa(long n);
void do_restart(void);
void post_exploit(void);

void runMachswap(void);
void getOffsets(void);
void rootMe(uint64_t proc);
void unsandbox(uint64_t proc);
void remountFS(bool shouldRestore);
void restoreRootFS(void);
int trust_file(NSString *path);
void installSubstitute(void);
void saveOffs(void);
void createWorkingDir(void);
void installSSH(void);
void xpcFucker(void);
void finish(void);//bool shouldLoadTweaks);
void Cleanthee(bool shouldLoadTweaks);

void runVoucherSwap(void);
void runExploit(int expType);
void initInstall(int packagerType);
bool canRead(const char *file);
struct tfp0;

//SETTINGS
BOOL shouldLoadTweaks(void);
BOOL shoulduicache(void);
uint32_t find_pid_of_procCV(const char *proc_name);
int getExploitType(void);
int getPackagerType(void);
void initSettingsIfNotExist(void);
void saveCustomSetting(NSString *setting, int settingResult);
BOOL shouldRestoreFS(void);
BOOL shouldfixFS(void);
extern bool checkfsfixswitch;
extern bool checkforceuicacheswitch;
BOOL isRootless(void);


//ROOTLESS JB
void createWorkingDir_rootless(void);
void saveOffs_rootless(void);
void uninstallRJB(void);
//EXPLOIT
int autoSelectExploit(void);

//Nonce
void setNonce(const char *nonce, bool shouldSet);
NSString* getBootNonce(void);
bool shouldSetNonce(void);

#endif /* utils_h */
