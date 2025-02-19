//
//  remount.c
//  Created by hoahuynh on 2021/05/29.
// modified by Marcel C 01/14/23
#include <string.h>
#include <sys/attr.h>
#include <sys/snapshot.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/fcntl.h>
#include <sys/unistd.h>
#include <malloc/_malloc.h>
#include <errno.h>
#include <spawn.h>

#include "remount.h"

#include "../../exploits/wasteoftfime/offsets_TW.h"
#include "../amfi/amfi_utils.h"
#include "../kernel_call/OffsetHolder.h"
#include "../kernel_call/offsets.h"
#include "../amfi/amfi.h"
#include "../../utils/shenanigans.h"
#include "../../lib/remap_tfp_set_hsp/remap_tfp_set_hsp.h"
#include "../../utils/KernelUtils.h"
#include "../../exploits/wasteoftfime/IOKitLibTW.h"
#import <UIKit/UIDevice.h>
#import "offsets.h"
//#import "log.h"
#include "ViewController.h"
#include "KernelRwWrapper.h"


#define SYSTEM_VERSION_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)
#define SYSTEM_VERSION_BETWEEN_OR_EQUAL_TO(a, b) (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(a) && SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(b))
 
static char* mntpathSW;
static char* otamntpath;
static char* otamntpathpriv;
static char* otamntpathLib;
static char* otamntpathREMOVE;
static char* mntpath;

bool remount(uint64_t launchd_proc) {
    mntpathSW = "/var/rootfsmnt";
    mntpath = strdup("/var/rootfsmnt");
    otamntpath = "/var/MobileSoftwareUpdate/mnt1";
    otamntpathpriv = "/private/var/MobileSoftwareUpdate/mnt1";
    otamntpathLib = "/private/var/Library/MobileSoftwareUpdate/mnt1";
    otamntpathREMOVE = "/var/MobileSoftwareUpdate";
    uint64_t rootvnode = findRootVnode(launchd_proc);
    util_info("rootvnode: 0x%llx", rootvnode);

    if(isRenameRequired()) {
        if(access(mntpathSW, F_OK) == 0) {
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:mntpathSW] error:nil]; }
        mkdir(mntpath, 0755);
        chown(mntpath, 0, 0);
        if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0
        } else {
            if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"12.5.6")) {
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:otamntpath] error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:otamntpathpriv] error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:otamntpathREMOVE] error:nil];
            unlink(otamntpath);
            remove(otamntpath);
            unlink(otamntpathpriv);
            remove(otamntpathpriv);
            unlink(otamntpathREMOVE);
            remove(otamntpathREMOVE); }
            if(isOTAMounted()) {
                waitOTAOK("deleting OTA...");
                util_info("OTA update already mounted, removing now please wait.........");
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:otamntpath] error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:otamntpathpriv] error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:otamntpathREMOVE] error:nil];
                unlink(otamntpath);
                remove(otamntpath);
                unlink(otamntpathpriv);
                remove(otamntpathpriv);
                unlink(otamntpathREMOVE);
                remove(otamntpathREMOVE);
                if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"12.5.6")) {
                    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:otamntpath] error:nil];
                    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:otamntpathREMOVE] error:nil];
                    unlink(otamntpathREMOVE);
                    remove(otamntpathREMOVE); }
                
                need_initialSSRenamed = 0;//
                return false; }
        }
        if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0
            uint64_t kernCreds = rk64(get_proc_struct_for_pid(0) + koffset(KSTRUCT_OFFSET_PROC_UCRED));
            uint64_t selfCreds = rk64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED));
            wk64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), kernCreds);
            grabEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
            
            char* bootSnapshot = find_boot_snapshot();
            if(!bootSnapshot
               || mountRealRootfs(rootvnode)) {
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                wk64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            int fd = open("/var/rootfsmnt", O_RDONLY, 0);
            if(fd <= 0
               || fs_snapshot_revert(fd, bootSnapshot, 0) != 0) {
                util_error("fs_snapshot_revert failed");
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                wk64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            close(fd);
            unmount(mntpath, MNT_FORCE);
            if(mountRealRootfs(rootvnode)) {
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                wk64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            uint64_t newmnt = findNewMount(rootvnode);
            if(!newmnt) {
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                wk64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            if(!unsetSnapshotFlag(newmnt)) {
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                wk64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            int fd2 = open("/var/rootfsmnt", O_RDONLY, 0);
            if(fd <= 0
               || fs_snapshot_rename(fd2, bootSnapshot, "orig-fs", 0) != 0) {
                util_error("fs_snapshot_rename failed");
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                wk64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            close(fd2);
            unmount(mntpath, 0);
            resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
            wk64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
            util_info("Successfully remounted RootFS! Reboot.");
            need_initialSSRenamed = 3;
            return true;

        } else {
            uint64_t kernCreds = ReadKernel64(get_proc_struct_for_pid(0) + koffset(KSTRUCT_OFFSET_PROC_UCRED));
            uint64_t selfCreds = ReadKernel64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED));
            WriteKernel64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), kernCreds);
            grabEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
            
            char* bootSnapshot = find_boot_snapshot();
            if(!bootSnapshot
               || mountRealRootfs(rootvnode)) {
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                WriteKernel64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            int fd = open("/var/rootfsmnt", O_RDONLY, 0);
            if(fd <= 0
               || fs_snapshot_revert(fd, bootSnapshot, 0) != 0) {
                util_error("fs_snapshot_revert failed");
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                WriteKernel64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            close(fd);
            unmount(mntpath, MNT_FORCE);
            if(mountRealRootfs(rootvnode)) {
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                WriteKernel64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            uint64_t newmnt = findNewMount(rootvnode);
            if(!newmnt) {
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                WriteKernel64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            if(!unsetSnapshotFlag(newmnt)) {
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                WriteKernel64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            int fd2 = open("/var/rootfsmnt", O_RDONLY, 0);
            if(fd <= 0
               || fs_snapshot_rename(fd2, bootSnapshot, "orig-fs", 0) != 0) {
                util_error("fs_snapshot_rename failed");
                resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
                WriteKernel64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
                return false; }
            close(fd2);
            unmount(mntpath, 0);
            resetEntitlementsForRootFS(get_proc_struct_for_pid(getpid()));
            WriteKernel64(get_proc_struct_for_pid(getpid()) + koffset(KSTRUCT_OFFSET_PROC_UCRED), selfCreds);
            util_info("Successfully remounted RootFS! Reboot.");
            need_initialSSRenamed = 3;
            return true;
        }
    } else {
        if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0
            uint64_t vmount = rk64(rootvnode + koffset(KSTRUCT_OFFSET_VNODE_V_MOUNT));
            uint32_t v_flag = rk32(vmount + koffset(KSTRUCT_OFFSET_MOUNT_MNT_FLAG));
            v_flag = v_flag & ~MNT_NOSUID;//343986177 = 000000008
            v_flag = v_flag & ~MNT_RDONLY;//343986184 = 000000001
            v_flag = v_flag & ~MNT_RDONLY & ~MNT_NOSUID;
            wk32(vmount + koffset(KSTRUCT_OFFSET_MOUNT_MNT_FLAG), v_flag & ~MNT_ROOTFS);
            char* dev_path = strdup("/dev/disk0s1s1");
            int retval = mount("apfs", "/", MNT_UPDATE, (void *)&dev_path);
            //int retval = mount("apfs", "/", MNT_UPDATE, (void *)&dev_path);
            free(dev_path);
            wk32(vmount + koffset(KSTRUCT_OFFSET_MOUNT_MNT_FLAG), v_flag);
            if(retval == 0) {
                util_info("Already remounted RootFS!");
                need_initialSSRenamed = 2;
                return true; }
            need_initialSSRenamed = 0;//
            return false; }
        else {
            uint64_t vmount = ReadKernel64(rootvnode + koffset(KSTRUCT_OFFSET_VNODE_V_MOUNT));
            uint32_t v_flag = ReadKernel32(vmount + koffset(KSTRUCT_OFFSET_MOUNT_MNT_FLAG));
            v_flag = v_flag & ~MNT_NOSUID;//343986177 = 000000008
            v_flag = v_flag & ~MNT_RDONLY;//343986184 = 000000001
            v_flag = v_flag & ~MNT_RDONLY & ~MNT_NOSUID;
            WriteKernel32(vmount + koffset(KSTRUCT_OFFSET_MOUNT_MNT_FLAG), v_flag & ~MNT_ROOTFS);
            char* dev_path = strdup("/dev/disk0s1s1");
            int retval = mount("apfs", "/", MNT_UPDATE, (void *)&dev_path);
            //int retval = mount("apfs", "/", MNT_UPDATE, (void *)&dev_path);
            free(dev_path);
            WriteKernel32(vmount + koffset(KSTRUCT_OFFSET_MOUNT_MNT_FLAG), v_flag);
            if(retval == 0) {
                util_info("Already remounted RootFS!");
                need_initialSSRenamed = 2;
                return true; }
            need_initialSSRenamed = 0;//
            return false;}
    }
    return true;
}

uint64_t findRootVnode(uint64_t launchd_proc) {
    if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0
        uint64_t textvp = rk64(launchd_proc + koffset(KSTRUCT_OFFSET_P_TEXTVP));// off_p_textvp);
        uint64_t nameptr = rk64(textvp + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));// off_v_name);
        char name[20];
        kread(nameptr, &name, 20);  //  <- launchd;
        
        uint64_t sbin = rk64(textvp + koffset(KSTRUCT_OFFSET_VNODE_V_PARENT));//off_v_parent);
        nameptr = rk64(sbin + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));// off_v_name);
        kread(nameptr, &name, 20);  //  <- sbin
        
        uint64_t rootvnode = rk64(sbin + koffset(KSTRUCT_OFFSET_VNODE_V_PARENT));//off_v_parent);
        nameptr = rk64(sbin + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));//off_v_name);
        kread(nameptr, &name, 20);  //  <- / (ROOT)
        
        uint32_t flags = rk32(rootvnode + koffset(KSTRUCT_OFFSET_VNODE_V_FLAG));//off_v_flags);
        util_info("rootvnode flags: 0x%x", flags);
        
        return rootvnode;

    } else {
        //  https://github.com/apple/darwin-xnu/blob/xnu-7195.60.75/bsd/sys/proc_internal.h#L193
        //  https://github.com/apple/darwin-xnu/blob/xnu-7195.60.75/bsd/sys/vnode_internal.h#L127
    
        uint64_t textvp = ReadKernel64(launchd_proc + koffset(KSTRUCT_OFFSET_P_TEXTVP));// off_p_textvp);
        uint64_t nameptr = ReadKernel64(textvp + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));// off_v_name);
        char name[20];
        kreadOwO(nameptr, &name, 20);  //  <- launchd;
        
        uint64_t sbin = ReadKernel64(textvp + koffset(KSTRUCT_OFFSET_VNODE_V_PARENT));//off_v_parent);
        nameptr = ReadKernel64(sbin + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));// off_v_name);
        kreadOwO(nameptr, &name, 20);  //  <- sbin
        
        uint64_t rootvnode = ReadKernel64(sbin + koffset(KSTRUCT_OFFSET_VNODE_V_PARENT));//off_v_parent);
        nameptr = ReadKernel64(sbin + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));//off_v_name);
        kreadOwO(nameptr, &name, 20);  //  <- / (ROOT)
        
        uint32_t flags = ReadKernel32(rootvnode + koffset(KSTRUCT_OFFSET_VNODE_V_FLAG));//off_v_flags);
        util_info("rootvnode flags: 0x%x", flags);
        
        return rootvnode;
    }
}

bool isRenameRequired() {
    struct statfs *st;
    
    int ret = getmntinfo(&st, MNT_NOWAIT);
    if(ret <= 0) {
        util_error("getmntinfo error");
    }
    
    for (int i = 0; i < ret; i++) {
        if(strstr(st[i].f_mntfromname, "com.apple.os.update-") != NULL) {
            return true;
        }
        if(strcmp(st[i].f_mntfromname, "/dev/disk0s1s1") == 0) {
            return false;
        }
    }
    return false;
}

bool isOTAMounted() {
    const char* path = strdup("/private/var/MobileSoftwareUpdate/mnt1");
    struct stat buffer;
    if (lstat(path, &buffer) != 0) {
        return false; }
    if((buffer.st_mode & S_IFMT) != S_IFDIR) {
        return false; }
    
    char* cwd = getcwd(nil, 0);
    chdir(path);
    struct stat p_buf;
    lstat("..", &p_buf);
    if(cwd) {
        chdir(cwd);
        free(cwd); }
    return buffer.st_dev != p_buf.st_dev || buffer.st_ino == p_buf.st_ino;
}

char* find_boot_snapshot() {
    io_registry_entry_t chosen = IORegistryEntryFromPath(0, "IODeviceTree:/chosen");
    CFDataRef data = IORegistryEntryCreateCFProperty(chosen, CFSTR("boot-manifest-hash"), kCFAllocatorDefault, 0);
    if(!data)
        return nil;
    IOObjectRelease(chosen);
    CFIndex length = CFDataGetLength(data) * 2 + 1;
    char *manifestHash = (char*)calloc(length, sizeof(char));
    int i = 0;
    for (i = 0; i<(int)CFDataGetLength(data); i++) {
        sprintf(manifestHash+i*2, "%02X", CFDataGetBytePtr(data)[i]);
    }
    manifestHash[i*2] = 0;
    CFRelease(data);
    char* systemSnapshot = malloc(sizeof(char) * 64);
    strcpy(systemSnapshot, "com.apple.os.update-");
    strcat(systemSnapshot, manifestHash);
    return systemSnapshot;
}

int mountRealRootfs(uint64_t rootvnode) {
    if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0
        uint64_t vmount = rk64(rootvnode + koffset(KSTRUCT_OFFSET_VNODE_V_MOUNT));
        uint64_t dev = rk64(vmount + koffset(KSTRUCT_OFFSET_MOUNT_MNT_DEVVP));//off_mnt_devvp);
        uint64_t nameptr = rk64(dev + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));//off_v_name);
        char name[20];
        kread(nameptr, &name, 20);   //  <- disk0s1s1
        util_info("Found dev vnode name: %s", name);
        uint64_t specinfo = rk64(dev + koffset(KSTRUCT_OFFSET_VNODE_VU_SPECINFO));
        uint32_t flags = rk32(specinfo + koffset(KSTRUCT_SPECFLAGS));//off_specflags);
        util_info("Found dev flags: 0x%x", flags);
        wk32(specinfo + koffset(KSTRUCT_SPECFLAGS), 0);
        char* fspec = strdup("/dev/disk0s1s1");
        struct hfs_mount_args mntargs;
        mntargs.fspec = fspec;
        mntargs.hfs_mask = 1;
        gettimeofday(nil, &mntargs.hfs_timezone);
        int retval = mount("apfs", mntpath, 0, &mntargs);
        free(fspec);
        util_info("Mount completed with status: %d", retval);
        if(retval == -1) {
            util_error("Mount failed with errno: %d", errno); }
        return retval;
    } else {
        //  https://github.com/apple/darwin-xnu/blob/main/bsd/sys/vnode_internal.h#L127
        //  https://github.com/apple/darwin-xnu/blob/main/bsd/sys/mount_internal.h#L107
        //  https://github.com/apple/darwin-xnu/blob/main/bsd/miscfs/specfs/specdev.h#L77
        uint64_t vmount = ReadKernel64(rootvnode + koffset(KSTRUCT_OFFSET_VNODE_V_MOUNT));
        uint64_t dev = ReadKernel64(vmount + koffset(KSTRUCT_OFFSET_MOUNT_MNT_DEVVP));//off_mnt_devvp);
        uint64_t nameptr = ReadKernel64(dev + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));//off_v_name);
        char name[20];
        kreadOwO(nameptr, &name, 20);   //  <- disk0s1s1
        util_info("Found dev vnode name: %s", name);
        uint64_t specinfo = ReadKernel64(dev + koffset(KSTRUCT_OFFSET_VNODE_VU_SPECINFO));
        uint32_t flags = ReadKernel32(specinfo + koffset(KSTRUCT_SPECFLAGS));//off_specflags);
        util_info("Found dev flags: 0x%x", flags);
        WriteKernel32(specinfo + koffset(KSTRUCT_SPECFLAGS), 0);
        char* fspec = strdup("/dev/disk0s1s1");
        struct hfs_mount_args mntargs;
        mntargs.fspec = fspec;
        mntargs.hfs_mask = 1;
        gettimeofday(nil, &mntargs.hfs_timezone);
        int retval = mount("apfs", mntpath, 0, &mntargs);
        free(fspec);
        util_info("Mount completed with status: %d", retval);
        if(retval == -1) {
            util_error("Mount failed with errno: %d", errno); }
        return retval; }
    
}

uint64_t findNewMount(uint64_t rootvnode) {
    if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0
        uint64_t vmount = rk64(rootvnode + koffset(KSTRUCT_OFFSET_VNODE_V_MOUNT));
        vmount = rk64(vmount + koffset(KSTRUCT_OFFSET_MOUNT_NEXT));//off_mnt_next);
        while (vmount != 0) {
            uint64_t dev = rk64(vmount + koffset(KSTRUCT_OFFSET_MOUNT_MNT_DEVVP));//off_mnt_devvp);
            if(dev != 0) {
                uint64_t nameptr = rk64(dev + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));//off_v_name);
                char name[20];
                kread(nameptr, &name, 20);
                char* devName = name;
                util_info("Found dev vnode name: %s", devName);
                if(strcmp(devName, "disk0s1s1") == 0) {
                    return vmount; } }
            vmount = rk64(vmount + koffset(KSTRUCT_OFFSET_MOUNT_NEXT)); }
        return 0;
        
    } else {
        uint64_t vmount = ReadKernel64(rootvnode + koffset(KSTRUCT_OFFSET_VNODE_V_MOUNT));
        vmount = ReadKernel64(vmount + koffset(KSTRUCT_OFFSET_MOUNT_NEXT));//off_mnt_next);
        while (vmount != 0) {
            uint64_t dev = ReadKernel64(vmount + koffset(KSTRUCT_OFFSET_MOUNT_MNT_DEVVP));//off_mnt_devvp);
            if(dev != 0) {
                uint64_t nameptr = ReadKernel64(dev + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));//off_v_name);
                char name[20];
                kreadOwO(nameptr, &name, 20);
                char* devName = name;
                util_info("Found dev vnode name: %s", devName);
                if(strcmp(devName, "disk0s1s1") == 0) {
                    return vmount; } }
            vmount = ReadKernel64(vmount + koffset(KSTRUCT_OFFSET_MOUNT_NEXT)); }
        return 0;
    }
}

bool unsetSnapshotFlag(uint64_t newmnt) {
    //  https://github.com/apple/darwin-xnu/blob/main/bsd/sys/mount_internal.h#L107
    if (kCFCoreFoundationVersionNumber >= 1751.108) {//1556.00 = 12.4) {//1751.108=14.0
        uint64_t dev = rk64(newmnt + koffset(KSTRUCT_OFFSET_MOUNT_MNT_DEVVP));//off_mnt_devvp);
        uint64_t nameptr = rk64(dev + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));//off_v_name);
        char name[20];
        kread(nameptr, &name, 20);
        util_info("Found dev vnode name: %s", name);
        
        uint64_t specinfo = rk64(dev + koffset(KSTRUCT_OFFSET_VNODE_VU_SPECINFO));//off_v_specinfo);
        uint64_t flags = rk32(specinfo + koffset(KSTRUCT_SPECFLAGS));//off_specflags);
        util_info("Found dev flags: 0x%llx", flags);
        
        uint64_t vnodelist = rk64(newmnt + koffset(KSTRUCK_OFFSET_MOUNT_VNODELIST));//off_mnt_vnodelist);
        while (vnodelist != 0) {
            util_info("vnodelist: 0x%llx", vnodelist);
            uint64_t nameptr = rk64(vnodelist + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));//off_v_name);
            unsigned long len = kstrlenKRW(nameptr);
            char name[len];
            kread(nameptr, &name, len);
            
            char* vnodeName = name;
            util_info("Found vnode name: %s", vnodeName);
            
            if(strstr(vnodeName, "com.apple.os.update-") != NULL) {
                uint64_t vdata = rk64(vnodelist + koffset(KSTRUCT_OFFSET_VNODE_V_DATA));
                uint32_t flag = rk32(vdata + koffset(KSTRUCT_APFS_DATA_FLAG));//off_apfs_data_flag);
                util_info("Found APFS flag: 0x%x", flag);
                
                if ((flag & 0x40) != 0) {
                    util_info("would unset the flag here to: 0x%x", flag & ~0x40);
                    wk32(vdata + koffset(KSTRUCT_APFS_DATA_FLAG), flag & ~0x40);
                    return true;
                }
            }
            vnodelist = rk64(vnodelist + 0x20);
        }
        return false;
    } else {
        uint64_t dev = ReadKernel64(newmnt + koffset(KSTRUCT_OFFSET_MOUNT_MNT_DEVVP));//off_mnt_devvp);
        uint64_t nameptr = ReadKernel64(dev + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));//off_v_name);
        char name[20];
        kreadOwO(nameptr, &name, 20);
        util_info("Found dev vnode name: %s", name);
        
        uint64_t specinfo = ReadKernel64(dev + koffset(KSTRUCT_OFFSET_VNODE_VU_SPECINFO));//off_v_specinfo);
        uint64_t flags = ReadKernel32(specinfo + koffset(KSTRUCT_SPECFLAGS));//off_specflags);
        util_info("Found dev flags: 0x%llx", flags);
        
        uint64_t vnodelist = ReadKernel64(newmnt + koffset(KSTRUCK_OFFSET_MOUNT_VNODELIST));//off_mnt_vnodelist);
        while (vnodelist != 0) {
            util_info("vnodelist: 0x%llx", vnodelist);
            uint64_t nameptr = ReadKernel64(vnodelist + koffset(KSTRUCT_OFFSET_VNODE_V_NAME));//off_v_name);
            unsigned long len = kstrlen(nameptr);
            char name[len];
            kreadOwO(nameptr, &name, len);
            
            char* vnodeName = name;
            util_info("Found vnode name: %s", vnodeName);
            
            if(strstr(vnodeName, "com.apple.os.update-") != NULL) {
                uint64_t vdata = ReadKernel64(vnodelist + koffset(KSTRUCT_OFFSET_VNODE_V_DATA));
                uint32_t flag = ReadKernel32(vdata + koffset(KSTRUCT_APFS_DATA_FLAG));//off_apfs_data_flag);
                util_info("Found APFS flag: 0x%x", flag);
                
                if ((flag & 0x40) != 0) {
                    util_info("would unset the flag here to: 0x%x", flag & ~0x40);
                    WriteKernel32(vdata + koffset(KSTRUCT_APFS_DATA_FLAG), flag & ~0x40);
                    return true;
                }
            }
            vnodelist = ReadKernel64(vnodelist + 0x20);
        }
        return false;
    }
}


unsigned long kstrlen(uint64_t string) {
    if (!string) return 0;
    
    unsigned long len = 0;
    char ch = 0;
    int i = 0;
    while (true) {
        kreadOwO(string + i, &ch, 1);
        if (!ch) break;
        len++;
        i++;
    }
    return len;
}
