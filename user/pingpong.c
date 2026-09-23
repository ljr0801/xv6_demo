#include "kernel/types.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  int p2c[2];  // 父进程 → 子进程
  int c2p[2];  // 子进程 → 父进程
  char byte = 'a';

  // TODO：使用 pipe() 创建两根管道，检查返回值
  pipe(p2c);
  pipe(c2p);

  int pid = fork();

  if (pid < 0) {
    fprintf(2, "fork failed\n");
    exit(1);
  }

  if (pid == 0) {
    // 子进程

    // TODO：关闭不用的端口 p2c[1]、c2p[0]
    close(p2c[1]);
    close(c2p[0]);

    // TODO：从 p2c[0] 读取一个字节到 byte
    // 提示：read(fd, &byte, 1)，成功应返回 1
    read(p2c[0], &byte, 1);

    // TODO：打印 "%d: received ping\n"，PID 使用 getpid()
    printf("%d: received ping\n",getpid());
    // TODO：通过 c2p[1] 将 byte 写回父进程
    // 提示：write(fd, &byte, 1)，成功应返回 1
    write(c2p[1], &byte, 1);
    // TODO：关闭剩余端口

    close(c2p[1]);
    close(p2c[0]);
    exit(0);
  } else {
    // 父进程

    // TODO：关闭不用的端口 p2c[0]、c2p[1]
    close(p2c[0]);
    close(c2p[1]);
    // TODO：通过 p2c[1] 发送一个字节
    write(p2c[1], &byte, 1);
    // TODO：从 c2p[0] 读取子进程返回的字节
    read(c2p[0], &byte, 1);
    // TODO：打印 "%d: received pong\n"，PID 使用 getpid()
    printf("%d: received pong\n", getpid());
    // TODO：关闭剩余端口
    close(p2c[1]);
    close(c2p[0]);
    wait(0);  // 等待并回收子进程
    exit(0);
  }
}
