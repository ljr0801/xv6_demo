# xv6 实验：本地编辑 → GitHub 保存 → Docker 运行

这是 xv6-labs-2021 的实验仓库。日常在 Windows 本地修改源码并提交到 GitHub，再把同一提交拉到 Docker 的独立目录中编译、运行。原容器中的 `/root/xv6-labs-2021` 保留，新的运行目录默认是 `/workspaces/xv6_own`。

2026-09-08 从容器 `ubuntu` 导入了原仓库的代码与 Git 历史，初始实验分支为 `util`，课程基线提交为 `f654383`；导入的基线尚未完成实验题目。课程远程仓库使用 `upstream`，你自己的 GitHub 仓库使用 `origin`。原项目介绍和许可见 [README](README) 与 [LICENSE](LICENSE)。

GitHub 仓库：[ljr0801/xv6_demo](https://github.com/ljr0801/xv6_demo)，当前默认分支为 `util`。本机已完成初始化、首次推送和容器拉取，并验证编译与 QEMU 启动。日常可直接使用下方命令；一次性初始化步骤用于其他电脑或重新克隆的仓库。

## 仓库结构

保留课程原有的目录和构建方式，实验代码直接在原位置编辑：

```text
xv6_own/
├── kernel/                 # 内核源码
├── user/                   # 用户态程序与实验代码
├── mkfs/                   # 文件系统镜像生成工具
├── conf/                   # 课程实验配置
├── Makefile                # 课程构建、运行、评分入口
├── grade-lab-util          # 当前 util 分支的评分脚本
├── gradelib.py             # 课程评分辅助代码
├── scripts/
│   ├── common.ps1          # 共用检查和配置读取
│   ├── setup.ps1           # 初始化本地 Git 身份、origin 和容器配置
│   ├── push.ps1            # 本地提交并推送当前分支
│   ├── pull.ps1            # 将 GitHub 上的当前分支同步至容器
│   ├── run.ps1             # 检查版本一致后在容器运行实验
│   ├── container-sync.sh   # 容器内的 Git 同步与检查
│   ├── container-run.sh    # 容器内校验版本并启动实验
│   └── tests/              # 本地 Git 与容器同步的冒烟测试
├── notes/                  # 实验笔记、问题记录和验证结果
├── workflow.example.json   # 可提交的容器配置示例
├── workflow.local.json     # 本机配置，由 setup 生成，Git 忽略
├── .gitignore              # 排除构建产物、镜像归档及本机配置
├── .gitattributes          # 保持源码和脚本使用 LF 换行
├── README.md               # 本工作流说明
├── README                  # 原 xv6 项目说明
└── LICENSE                 # 原项目许可
```

`fs.img`、对象文件、内核二进制和评分日志是实验产物，不作为源码提交。已有的 `ubuntu.tar` 是容器/镜像归档，体积很大，已排除在 Git 之外；不要通过 `git add -f` 上传它。

## 一次性初始化

本地需要 Git、PowerShell 和可用的 Docker CLI；Docker 中使用你已有的 `ubuntu` 容器及其 RISC-V 编译工具链、QEMU、make、Git 和 Python 环境。无需在 Windows 安装交叉编译器。

1. 在 GitHub 创建一个**空仓库**，例如 `xv6_own`。建议设为私有，不勾选初始化 README、`.gitignore` 或 License。这样可以直接推送现有课程历史。
2. 在本地仓库根目录打开 PowerShell。如果当前执行策略阻止脚本，可仅为这个 PowerShell 会话设置：

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

3. 将下面的仓库地址、姓名和邮箱替换成自己的值，然后初始化：

   ```powershell
   .\scripts\setup.ps1 `
     -RepoUrl 'https://github.com/ljr0801/xv6_demo.git' `
     -GitUserName 'Your Name' `
     -GitUserEmail 'your-email@example.com' `
     -ContainerName 'ubuntu' `
     -ContainerRepoPath '/workspaces/xv6_own'
   ```

   邮箱可使用 GitHub 提供的隐私邮箱。脚本设置的是本仓库的 Git 身份；`workflow.local.json` 只记录容器名和容器内路径，远程地址从 Git 的 `origin` 读取。容器目录限制为 `/workspaces/` 下的直接子目录，目录名只使用英文字母、数字、点、下划线或连字符。`setup.ps1` 不创建 GitHub 仓库，也不提交或推送代码。

4. 确保容器已启动：

   ```powershell
   docker ps -a
   docker start ubuntu
   ```

   同步和运行脚本遇到停止的容器会报错，需要你手动启动。

5. 检查本次要提交的文件，然后首次推送、拉取和编译：

   ```powershell
   git status --short
   git diff
   .\scripts\push.ps1 -Message 'chore: add local GitHub Docker workflow'
   .\scripts\pull.ps1
   .\scripts\run.ps1 -Target build
   .\scripts\run.ps1 -Target qemu
   ```

   首次同步会在独立的容器路径中建立仓库。看到 xv6 的 `$` 提示符后可以运行实验程序。退出 QEMU：先按 **Ctrl+A**，松开后再按 **X**。

### 私有仓库认证

本地推送与容器拉取分别执行 Git，需要分别具备认证能力。本地可使用 Git Credential Manager 或自己的 SSH 配置。容器只需读取仓库，建议配置该仓库的只读 SSH deploy key，或使用容器内的 Git 凭据管理方式。

脚本让容器使用本地 `origin` 的同一个地址：如果采用 SSH，`origin` 应为 `git@github.com:ljr0801/xv6_demo.git`，本地和容器都应能访问该地址。不要把密码或 Token 嵌入远程 URL，也不要写入 JSON、脚本、笔记或 Git 提交。为容器配置 SSH 时，应事先完成可信的 GitHub 主机密钥校验，避免自动脚本等待首次连接确认。

`pull.ps1` 非交互运行，禁用 Git 用户名/密码提示。请先在容器的交互终端中验证认证，确保后续读取仓库无需手动输入；本地能推送并不代表容器已具备读取权限。

## 日常工作流

在本地 `kernel/`、`user/` 等目录修改代码，按一次可说明的改动提交，再运行容器里的同一版本：

```powershell
git switch util
# 用编辑器修改本地源码，并记录实验思路。
git status --short
git diff
.\scripts\push.ps1 -Message 'feat(util): implement sleep'
.\scripts\pull.ps1
.\scripts\run.ps1 -Target qemu
.\scripts\run.ps1 -Target grade
```

| 命令 | 行为 |
| --- | --- |
| `push.ps1 -Message '说明'` | 将未忽略的改动全部暂存（`git add -A`），有改动时创建提交，然后普通推送当前分支至 `origin`。运行前检查 `git status`，避免顺带提交无关文件。 |
| `push.ps1` | 推送已经提交的当前分支；存在未提交改动时拒绝执行。 |
| `pull.ps1` | 将当前本地分支从 GitHub 同步到配置的容器目录；要求本地工作区干净，且远端分支的提交与本地 `HEAD` 相同。 |
| `run.ps1 -Target build` | 在容器中执行 `make kernel/kernel fs.img`。 |
| `run.ps1 -Target qemu` | 在容器中执行交互式 `make qemu`；这是省略 `-Target` 时的默认行为。 |
| `run.ps1 -Target grade` | 在容器中执行 `make grade`，使用当前实验分支的评分脚本。 |
| `run.ps1 -Target shell` | 进入容器中的实验工作目录，供手动检查与调试。用 `exit` 退出。 |

`run.ps1` 不自动拉取：运行前会检查本地工作区、容器工作区，以及两边的分支、提交和远程地址。一旦版本不一致，先完成提交、推送与拉取，再运行。这样评分结果才能对应到一个明确的 Git 提交。Git 忽略的构建产物不算待提交改动。

切换实验分支或修改编译选项后，使用 `run.ps1 -Target build -Clean`（也可用于 `qemu` 或 `grade`），先执行 `make clean` 再编译，避免复用旧实验的目标文件。`-Clean` 会删除并重建 `fs.img`，其中在 xv6 运行时创建的文件也会清空；普通运行保留增量构建与文件系统镜像。同步、编译和 QEMU 请依次执行，同一运行目录不要同时启动多份任务。

更喜欢手动选择提交内容时，可以先自行执行 `git add <文件>` 和 `git commit`，再执行不带 `-Message` 的 `push.ps1`。

## 开始其他实验

课程每个实验使用各自的起始分支。不要直接在 `util` 上连续堆叠其他实验的代码，否则可能把先前答案带进新的实验基线。

例如开始 `syscall`：先在 `util` 提交并推送工作流，再从课程分支创建实验分支，只带入工作流文件：

```powershell
git switch util
# 确保本地改动已提交；如有需要先执行 push.ps1。
# 本次导入已保留 upstream/syscall 等课程分支。
# 仅在需要更新且课程远程可访问时执行 git fetch upstream。
git switch -c lab/syscall upstream/syscall
git restore --source util -- README.md .gitignore .gitattributes scripts workflow.example.json notes
git add README.md .gitignore .gitattributes scripts workflow.example.json notes
git commit -m 'chore: add workflow to syscall lab'
.\scripts\push.ps1
.\scripts\pull.ps1
.\scripts\run.ps1 -Target build -Clean
```

其他实验同理，用对应的 `upstream/<实验名>` 建立 `lab/<实验名>`。脚本始终使用当前本地分支；不要求实验分支必须叫 `main` 或 `master`。回到 `util` 时，执行 `git switch util`，再推送、同步和运行。

`git restore` 只带入列出的工作流与笔记，不会带入 `kernel/` 或 `user/` 中的实验答案。若课程要求将上一实验的部分改动用于下一实验，应按实验说明有选择地移植代码。`lab/syscall` 等分支名也可能触发课程 `make handin` 自带的分支提示；提交课程作业时遵守对应实验要求。

## 目录隔离与数据保存

- Docker 镜像提供工具链和基础环境；容器里的文件修改发生在容器可写层。编译本身不会改写已有镜像。
- 新工作流使用 `/workspaces/xv6_own`，让运行副本与原来的 `/root/xv6-labs-2021` 分开。本地源码通过 GitHub 同步，不使用共享源码目录的 bind mount。
- 默认的新运行目录位于容器可写层，没有新增持久化卷。停止或重启容器会保留文件，删除并重建容器会丢失该目录中的文件和构建产物；已推送的提交可从 GitHub 恢复。
- GitHub 保存的是已经提交并推送的源码历史。本地未提交内容、被忽略的文件、容器内临时文件都不会自动获得备份。
- 平时在本地修改源码。若临时进入容器调试并修改了源码，先把需要的改动带回本地、提交并推送，再同步；脚本遇到容器源码改动会停止，不会替你覆盖实验成果。

## 从 GitHub 恢复到另一台电脑

准备好本地 Git、PowerShell、Docker，以及已装好课程工具链的容器后：

```powershell
git clone https://github.com/ljr0801/xv6_demo.git
cd xv6_demo
git switch util
.\scripts\setup.ps1 `
  -RepoUrl 'https://github.com/ljr0801/xv6_demo.git' `
  -GitUserName 'Your Name' `
  -GitUserEmail 'your-email@example.com' `
  -ContainerName 'ubuntu' `
  -ContainerRepoPath '/workspaces/xv6_own'
docker start ubuntu
.\scripts\pull.ps1
.\scripts\run.ps1 -Target build
```

如果使用其他实验分支，切换到已推送且包含工作流文件的对应分支。`workflow.local.json` 不在 GitHub 中，因此每台机器需要重新运行 `setup.ps1`。

Git 克隆不会复制原机器的远程配置。重新克隆后需要课程分支时，先用 `git remote -v` 检查；若不存在 `upstream`，添加导入时使用的课程地址，再获取课程分支：

```powershell
git remote add upstream git://g.csail.mit.edu/xv6-labs-2021
git fetch upstream
```

已有 `upstream` 时只执行 `git fetch upstream`。`origin` 始终保留为自己的仓库。

## 工作流验证

已在 PowerShell 7.6 和 Windows PowerShell 5.1 下验证初始化、提交和本地模拟推送；在现有 Ubuntu 容器的 Git 2.25.1 下验证首次 clone、快进、分支切换和错误保护。xv6 `util` 基线已在独立目录完整编译，并成功启动到 QEMU 中的 shell。详细范围与复现命令见 [验证记录](docs/verification.md)。真实 GitHub 推送、容器拉取、编译和 QEMU 启动也已通过；上述验证不表示实验答案通过评分。

## 常见问题

| 现象 | 处理方法 |
| --- | --- |
| 缺少 `origin` 或本机配置 | 创建空 GitHub 仓库后运行 `setup.ps1`。 |
| 本地未提交，脚本拒绝同步或运行 | 检查改动并提交、推送；暂时不需运行的改动可自行用 Git 暂存。 |
| 远端提交与本地不同 | 检查当前分支是否已推送。如果另一台机器更新了远端，先在本地正常获取并整合改动，再推送。不要直接强制覆盖远端。 |
| `Permission denied` / `Authentication failed` | 分别检查本地和容器的 Git 认证；本地能推送不代表容器已有读取权限。 |
| 容器不存在或已停止 | 用 `docker ps -a` 核对名称，在配置中使用正确容器名；停止时先 `docker start ubuntu`。 |
| 容器中存在源码改动或分支分歧 | 先检查并保留需要的改动，再决定如何整理。同步脚本不会执行强制重置来丢弃它们。 |
| `make grade` 报失败 | 阅读失败用例并修改实验代码；未完成的课程基线不应预期评分全部通过。 |
| 需要清理构建产物 | 进入 `run.ps1 -Target shell` 后运行 `make clean`；不要删除源码或 `.git` 来解决构建问题。 |
