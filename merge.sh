#!/bin/bash
set -euo pipefail

# ====================== 配置区 ======================
# 需要合并的分支名，执行脚本前修改这里
TARGET_BRANCH="xxx"
# 目标主干分支
MAIN_BRANCH="main"
# 合并提交默认备注，可自行修改
MERGE_COMMIT_MSG="feat: 合并 ${TARGET_BRANCH} 分支全部功能(压缩提交历史)"
# ====================================================

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

print_info() { echo -e "${GREEN}[INFO] $1${NC}"; }
print_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
print_err()  { echo -e "${RED}[ERROR] $1${NC}"; }

# 1. 检查是否在git仓库
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_err "当前目录不是Git仓库，请切换到项目根目录执行脚本！"
    exit 1
fi

# 2. 检查目标分支是否存在
if ! git rev-parse --verify "origin/${TARGET_BRANCH}" >/dev/null 2>&1 && ! git rev-parse --verify "${TARGET_BRANCH}" >/dev/null 2>&1; then
    print_err "分支 ${TARGET_BRANCH} 本地/远程均不存在，请核对分支名称！"
    exit 1
fi

# 3. 检查工作区是否有未提交修改
if [[ -n $(git status --porcelain) ]]; then
    print_warn "检测到工作区存在未提交修改："
    git status --porcelain
    read -p "是否自动stash暂存变更？(y/N) " stash_confirm
    if [[ "${stash_confirm,,}" == "y" ]]; then
        git stash push -m "auto-stash before squash merge ${TARGET_BRANCH}"
        print_info "已暂存本地修改，合并完成后执行 git stash pop 恢复"
    else
        print_err "存在未提交代码，终止合并！请先提交/储藏代码后重试"
        exit 1
    fi
fi

# 4. 切换到main分支并拉取最新代码
print_info "切换至 ${MAIN_BRANCH} 分支并同步远程最新代码..."
git checkout "${MAIN_BRANCH}"
git pull origin "${MAIN_BRANCH}"

# 5. 拉取目标分支最新代码
print_info "同步远程 ${TARGET_BRANCH} 分支代码..."
git fetch origin "${TARGET_BRANCH}:${TARGET_BRANCH}"

# 6. squash合并（核心：压缩所有提交为单次变更，不保留原分支提交记录）
print_info "开始 squash 合并 ${TARGET_BRANCH}，将压缩所有提交记录..."
if git merge --squash "${TARGET_BRANCH}"; then
    # 无冲突，直接提交
    git commit -m "${MERGE_COMMIT_MSG}"
    print_info "合并完成！仅生成一条合并提交记录，无原分支历史"
    echo "本次合并提交信息："
    git log -1 --oneline
else
    # 存在代码冲突
    print_err "合并出现代码冲突，请手动解决冲突文件后执行："
    echo "  1. 解决所有冲突文件后 git add ."
    echo "  2. git commit -m \"${MERGE_COMMIT_MSG}\""
    echo "  3. 如需放弃本次合并：git merge --abort"
    exit 2
fi

print_info "操作全部结束！如需推送至远程main执行：git push origin ${MAIN_BRANCH}"