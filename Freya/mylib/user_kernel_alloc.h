//
//  user_kernel_alloc.h
//  exploit-1
//
//  Created by Quote on 2020/12/30.
//  Copyright © 2020 Quote. All rights reserved.
//

#ifndef user_kernel_alloc_h
#define user_kernel_alloc_h

bool IOSurface_init(void);

int *create_pipesPF(size_t *pipe_count);
void close_pipesPF(int *pipefds, size_t pipe_count);
void pipe_closePF(int pipefds[2]);
size_t pipe_sprayPF(const int *pipefds, size_t pipe_count,
                  void *pipe_buffer, size_t pipe_buffer_size,
                  void (^update)(uint32_t pipe_index, void *data, size_t size));

#endif /* user_kernel_alloc_h */
