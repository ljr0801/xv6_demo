# 工作流验证记录

日期：2026-09-08。

## 已验证

- PowerShell 7.6.5 和 Windows PowerShell 5.1：初始化可重复执行，拒绝覆盖不同的 origin，拒绝带凭据的 URL 和原始容器路径；有改动时提交后推送，无改动时推送已提交版本；拒绝未提交工作区和 detached HEAD。使用含中文和空格的本地路径。
- PowerShell 推送测试使用本地 bare 仓库替代网络传输，比较两次推送后的提交号；没有访问测试名所指的 GitHub 仓库。
- Ubuntu 容器：Git 2.25.1、Bash 5.0.17。验证首次克隆、重复同步、快进、切换到 `lab/syscall` 后返回 `util`。
- 保护检查：拒绝已修改源码、未跟踪文件、错误远程、远端 SHA 不符、容器内独有提交、非仓库非空目录、符号链接，以及原始 `/root/xv6-labs-2021` 目录。版本不符时运行脚本拒绝启动。
- 实际 PowerShell → Docker helper 调用链：从容器原始仓库克隆到独立验证目录，运行 `make clean` 和 `make kernel/kernel fs.img` 成功。
- QEMU：`util` 基线 `f654383cdec479c9d53a02bffa1ab5526f6c3ca4` 启动后输出 `init: starting sh` 和 `$`；8 秒超时主动结束验证进程。
- 原始容器仓库仍处于干净的 `util` 分支；未修改其源码或远程配置。

## 复现脚本测试

在仓库根目录打开 PowerShell：

```powershell
.\scripts\tests\powershell-smoke.ps1
docker cp scripts ubuntu:/tmp/xv6-workflow-tests
docker exec ubuntu bash /tmp/xv6-workflow-tests/tests/sync-smoke.sh /tmp/xv6-workflow-tests/container-sync.sh /tmp/xv6-workflow-tests/container-run.sh
```

PowerShell 测试将临时仓库保留在 Git 忽略的 `.workflow-tests/`，供检查。容器测试只清理自己生成的临时测试仓库；不会操作正式 `/workspaces/xv6_own` 或原始实验目录。

## 尚未验证

- 用户 GitHub 仓库的创建、首次推送、容器端认证与真实网络拉取。等待用户填写仓库地址并配置本地 Git 身份与两端认证。
- 实验题目正确性和 `make grade` 全部通过。当前导入的是未解题的课程基线。
